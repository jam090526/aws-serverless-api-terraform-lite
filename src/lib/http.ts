import type {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
  Context,
} from 'aws-lambda';
import { ZodError, ZodSchema, ZodTypeDef } from 'zod';
import { HttpError, badRequest, unauthorized } from './errors';
import { logger } from './logger';

export type Handler = (event: APIGatewayProxyEvent, context: Context) => Promise<APIGatewayProxyResult>;

const baseHeaders = (): Record<string, string> => ({
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': process.env.CORS_ORIGIN ?? '*',
});

export function json(statusCode: number, body: unknown): APIGatewayProxyResult {
  return { statusCode, headers: baseHeaders(), body: JSON.stringify(body) };
}

export function noContent(): APIGatewayProxyResult {
  return { statusCode: 204, headers: baseHeaders(), body: '' };
}

/**
 * Wraps a handler with:
 *  - request-scoped structured logging (request id, route, status, duration)
 *  - consistent error responses: { error: { code, message, details?, requestId } }
 *  - safe 500s that never leak stack traces to clients
 */
export function withHttp(fn: Handler): Handler {
  return async (event, context) => {
    const started = Date.now();
    logger.addContext(context);
    logger.appendKeys({ route: `${event.httpMethod} ${event.resource}` });
    try {
      const res = await fn(event, context);
      logger.info('request completed', { statusCode: res.statusCode, ms: Date.now() - started });
      return res;
    } catch (err) {
      const requestId = context.awsRequestId;
      if (err instanceof HttpError) {
        logger.warn('request rejected', { statusCode: err.statusCode, code: err.code, message: err.message });
        return json(err.statusCode, {
          error: { code: err.code, message: err.message, details: err.details, requestId },
        });
      }
      logger.error('unhandled error', err as Error);
      return json(500, {
        error: { code: 'INTERNAL_ERROR', message: 'Something went wrong', requestId },
      });
    } finally {
      logger.removeKeys(['route']);
    }
  };
}

/** Parses and validates the JSON body against a Zod schema. */
export function parseBody<T>(event: APIGatewayProxyEvent, schema: ZodSchema<T, ZodTypeDef, unknown>): T {
  if (!event.body) throw badRequest('Request body is required');
  let raw: unknown;
  try {
    const text = event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString('utf8') : event.body;
    raw = JSON.parse(text);
  } catch {
    throw badRequest('Request body must be valid JSON');
  }
  return validate(raw, schema);
}

export function validate<T>(value: unknown, schema: ZodSchema<T, ZodTypeDef, unknown>): T {
  try {
    return schema.parse(value);
  } catch (err) {
    if (err instanceof ZodError) {
      throw badRequest(
        'Validation failed',
        err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
      );
    }
    throw err;
  }
}

/** Returns the Cognito user id (sub claim) set by the API Gateway authorizer. */
export function getUserId(event: APIGatewayProxyEvent): string {
  const sub = event.requestContext?.authorizer?.claims?.sub;
  if (typeof sub !== 'string' || !sub) throw unauthorized();
  return sub;
}

export function pathParam(event: APIGatewayProxyEvent, name: string): string {
  const value = event.pathParameters?.[name];
  if (!value) throw badRequest(`Missing path parameter: ${name}`);
  return value;
}
