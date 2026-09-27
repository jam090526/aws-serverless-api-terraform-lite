/**
 * Throw an HttpError anywhere in a handler and the wrapper turns it into
 * a clean JSON response with the right status code.
 */
export class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

export const badRequest = (message: string, details?: unknown) =>
  new HttpError(400, 'BAD_REQUEST', message, details);

export const unauthorized = (message = 'Unauthorized') =>
  new HttpError(401, 'UNAUTHORIZED', message);

export const notFound = (message = 'Not found') => new HttpError(404, 'NOT_FOUND', message);

export const conflict = (message: string) => new HttpError(409, 'CONFLICT', message);
