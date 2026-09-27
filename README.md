# AWS Serverless API Lite: Terraform + Lambda (TypeScript) Starter

A free, minimal **Terraform starter for serverless REST APIs on AWS**: API Gateway + AWS Lambda (Node.js 24, TypeScript, ARM64), deployed with one command.

It's small on purpose, but it follows the same production patterns as the full kit: request validation, consistent JSON errors, structured logging, tracing and tests.

> **Need auth, a database, alarms and CI/CD?** The [full AWS Serverless API Starter Kit – Terraform Edition](https://jamboree648.gumroad.com/l/wrpmcy) adds Cognito, DynamoDB, 14 CloudWatch alarms, a dashboard, dev/prod stages with remote state, GitHub Actions OIDC deploys and a 14-page setup guide. [See the comparison ↓](#lite-vs-full-starter-kit)

```
Client ──► API Gateway (REST) ──► Lambda (Node.js 24, TypeScript)
               │                        │
     throttling, access logs     structured JSON logs, X-Ray
```

Prefer AWS CDK? There's a [CDK version of this starter](https://github.com/jam090526/aws-serverless-api-cdk-lite) too.

## Features

- **Terraform with the AWS provider 6.** All infrastructure is in one readable file (`infra/main.tf`).
- **Lambda on Node.js 24 (ARM64).** esbuild bundling keeps functions small.
- **`withHttp()` handler wrapper.** It handles logging, error mapping and safe 500s that never leak stack traces.
- **Zod request validation** with field-level error messages.
- **Consistent JSON errors** that include a `requestId` you can find in the logs.
- **Structured logging** with AWS Lambda Powertools, plus X-Ray tracing.
- **API Gateway throttling** and JSON access logs.
- **Tests** for the handlers (Jest) and the infrastructure (`terraform test` with mocked AWS, no credentials needed).
- **GitHub Actions CI** for type-checking, tests, `terraform fmt` and `terraform validate`.

## Quick start

Prerequisites: Node.js 22+ (24 recommended), Terraform 1.7+ and the AWS CLI, configured.

```bash
git clone https://github.com/jam090526/aws-serverless-api-terraform-lite.git
cd aws-serverless-api-lite-terraform
npm install
npm test
npm run deploy         # prints api_url
```

The region comes from `AWS_REGION` or your AWS CLI profile. To pin one, set `aws_region` in `infra/terraform.tfvars`.

Try it:

```bash
curl <api_url>/health
# {"status":"ok","stage":"dev","time":"..."}

curl -X POST <api_url>/hello -H "Content-Type: application/json" -d '{"name":"Ada"}'
# {"message":"Hello, Ada!"}

curl -X POST <api_url>/hello -H "Content-Type: application/json" -d '{"name":""}'
# {"error":{"code":"BAD_REQUEST","message":"Validation failed","details":[...],"requestId":"..."}}
```

Remove everything with `npm run destroy`.

> The lite version keeps Terraform state in a local file (`infra/terraform.tfstate`, git-ignored). Don't delete it while the API is deployed. The full kit stores state in an encrypted S3 bucket with locking.

## Project layout

```
infra/main.tf              API Gateway + Lambda infrastructure (routes, functions, API, logs)
infra/tests/               Terraform tests (mocked AWS)
src/handlers/health.ts     GET /health
src/handlers/hello.ts      POST /hello (validation example)
src/lib/http.ts            withHttp(), parseBody(), json()
src/lib/errors.ts          HttpError helpers
scripts/bundle.mjs         esbuild: one bundle per handler in dist/
test/                      Jest unit tests
```

## Add an endpoint

1. Create `src/handlers/my-route.ts` and wrap your logic in `withHttp()`.
2. In `infra/main.tf`, add a line to `local.routes`:
   `"my-route" = { method = "GET", path = "/my-route", handler = "my-route" }`
   Terraform creates the function, its role, log group and API route.
3. Run `npm test`, then `npm run deploy`.

## Lite vs Full Starter Kit

| | **Lite (this repo, free)** | **[Full Starter Kit – Terraform](https://jamboree648.gumroad.com/l/wrpmcy)** |
|---|:---:|:---:|
| API Gateway + Lambda (Node.js 24, TypeScript) | ✅ | ✅ |
| Validation, `withHttp()` wrapper, consistent errors | ✅ | ✅ |
| Structured logs, X-Ray, throttling, access logs | ✅ | ✅ |
| Unit + infrastructure tests | ✅ | ✅ |
| Cognito auth + API Gateway authorizer | — | ✅ |
| DynamoDB single-table CRUD with per-user isolation and pagination | — | ✅ |
| Least-privilege IAM per function | — | ✅ |
| 14 CloudWatch alarms, email alerts and a dashboard | — | ✅ |
| dev / prod stages with safe data defaults | — | ✅ |
| Remote state in S3 with locking, one-command bootstrap | — | ✅ |
| GitHub Actions deploys through OIDC, with a smoke test | — | ✅ |
| 14-page PDF setup and production guide | — | ✅ |
| Personal and Team licenses | MIT | Commercial |

👉 **[Get the full AWS Serverless API Starter Kit – Terraform Edition](https://jamboree648.gumroad.com/l/wrpmcy)**

## FAQ

**Is this production-ready?**
The patterns are, but a production API usually also needs authentication, a data store, alarms, remote state and a deployment pipeline. Add them yourself, or use the full kit, which has all of them wired up and tested.

**Why a REST API (v1) instead of an HTTP API?**
It has a built-in Cognito authorizer, per-stage throttling, request tracing and mature gateway responses, which makes it a solid default for most backends.

**The deploy failed with an error about the API Gateway account or CloudWatch role.**
API Gateway needs one account-wide role to write access logs, and this repo creates it. If your account already has one set up, add `manage_api_gateway_account = false` to `infra/terraform.tfvars`.

**Can I use this commercially?**
Yes. This repo is MIT licensed.

## License

[MIT](LICENSE) © 2026 JAM090526
