import { json, withHttp } from '../lib/http';

/** GET /health — public liveness check for uptime monitors and load tests. */
export const handler = withHttp(async () =>
  json(200, {
    status: 'ok',
    stage: process.env.STAGE ?? 'local',
    time: new Date().toISOString(),
  }),
);
