import { handler as helloHandler } from '../../src/handlers/hello';
import { handler as healthHandler } from '../../src/handlers/health';
import { context, makeEvent, parse } from './helpers';

describe('GET /health', () => {
  it('returns ok', async () => {
    const res = await healthHandler(makeEvent({ resource: '/health' }, null), context);
    expect(res.statusCode).toBe(200);
    expect(parse(res.body).status).toBe('ok');
  });
});

describe('POST /hello', () => {
  it('greets by name', async () => {
    const res = await helloHandler(
      makeEvent({ httpMethod: 'POST', resource: '/hello', body: JSON.stringify({ name: ' Ada ' }) }, null),
      context,
    );
    expect(res.statusCode).toBe(200);
    expect(parse(res.body).message).toBe('Hello, Ada!');
  });

  it('rejects invalid JSON', async () => {
    const res = await helloHandler(makeEvent({ httpMethod: 'POST', body: '{oops' }, null), context);
    expect(res.statusCode).toBe(400);
    expect(parse(res.body).error.code).toBe('BAD_REQUEST');
  });

  it('returns field-level validation errors', async () => {
    const res = await helloHandler(
      makeEvent({ httpMethod: 'POST', body: JSON.stringify({ name: '', extra: 1 }) }, null),
      context,
    );
    expect(res.statusCode).toBe(400);
    expect(parse(res.body).error.details.length).toBeGreaterThan(0);
  });
});
