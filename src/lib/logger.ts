import { Logger } from '@aws-lambda-powertools/logger';

/** Structured JSON logger. Service name and level come from POWERTOOLS_* env vars. */
export const logger = new Logger();
