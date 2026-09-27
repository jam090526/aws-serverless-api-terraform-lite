import type { APIGatewayProxyEvent, Context } from 'aws-lambda';

export const USER_ID = 'user-123';

export function makeEvent(overrides: Partial<APIGatewayProxyEvent> = {}, userId: string | null = USER_ID): APIGatewayProxyEvent {
  return {
    body: null,
    headers: {},
    multiValueHeaders: {},
    httpMethod: 'GET',
    isBase64Encoded: false,
    path: '/items',
    pathParameters: null,
    queryStringParameters: null,
    multiValueQueryStringParameters: null,
    stageVariables: null,
    resource: '/items',
    requestContext: {
      authorizer: userId ? { claims: { sub: userId } } : undefined,
    } as unknown as APIGatewayProxyEvent['requestContext'],
    ...overrides,
  };
}

export const context = {
  awsRequestId: 'req-1',
  functionName: 'test',
  functionVersion: '$LATEST',
  invokedFunctionArn: 'arn:aws:lambda:us-east-1:123456789012:function:test',
  memoryLimitInMB: '256',
  logGroupName: 'test',
  logStreamName: 'test',
  callbackWaitsForEmptyEventLoop: true,
  getRemainingTimeInMillis: () => 10000,
  done: () => undefined,
  fail: () => undefined,
  succeed: () => undefined,
} as Context;

export const parse = (body: string) => JSON.parse(body);
