import { z } from 'zod';
import { json, parseBody, withHttp } from '../lib/http';

const HelloSchema = z
  .object({
    name: z.string().trim().min(1, 'name is required').max(80),
  })
  .strict();

/**
 * POST /hello  { "name": "Ada" }
 * A tiny example of the request flow: validate -> do work -> respond.
 * Replace it with your own logic.
 */
export const handler = withHttp(async (event) => {
  const { name } = parseBody(event, HelloSchema);
  return json(200, { message: `Hello, ${name}!` });
});
