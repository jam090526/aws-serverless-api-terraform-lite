// Bundles every handler in src/handlers/ into its own Lambda package, the same
// way the CDK edition's NodejsFunction does (esbuild, minified, source maps,
// Node.js 24 target, AWS SDK v3 left external because the runtime ships it):
//
//   src/handlers/health.ts        ->  dist/health/index.js
//   src/handlers/items/create.ts  ->  dist/items/create/index.js
//
// Terraform zips each folder (see `routes` in infra/main.tf).
import { build } from 'esbuild';
import { readdirSync, rmSync } from 'node:fs';
import { join, relative } from 'node:path';

const handlersDir = 'src/handlers';
const outDir = 'dist';

function findHandlers(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return findHandlers(path);
    return entry.name.endsWith('.ts') && !entry.name.endsWith('.test.ts') ? [path] : [];
  });
}

const entries = findHandlers(handlersDir).map((file) => ({
  file,
  name: relative(handlersDir, file).replace(/\\/g, '/').replace(/\.ts$/, ''),
}));

rmSync(outDir, { recursive: true, force: true });

await Promise.all(
  entries.map(({ file, name }) =>
    build({
      entryPoints: [file],
      outfile: join(outDir, name, 'index.js'),
      bundle: true,
      platform: 'node',
      format: 'cjs',
      target: 'node24',
      minify: true,
      sourcemap: true,
      external: ['@aws-sdk/*'],
      logLevel: 'warning',
    }),
  ),
);

console.log(`Bundled ${entries.length} functions into ${outDir}/: ${entries.map((e) => e.name).join(', ')}`);
