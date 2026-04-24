import { createRequire } from "node:module";
import path from "node:path";
import { defineConfig } from "prisma/config";

// Datasource URL lives in schema.prisma (env("POSTGRES_PRISMA_URL")) so `prisma migrate` works
// in the Docker image without the `prisma` npm package (Next standalone omits it; see Dockerfile).
// Local dev: try loading .env. Production/CI: env is injected.
const require = createRequire(import.meta.url);
try {
  require("dotenv/config");
} catch {
  // optional (standalone has no dotenv in node_modules)
}

export default defineConfig({
  schema: path.join("prisma", "schema.prisma"),
  migrations: {
    path: path.join("prisma", "migrations"),
  },
});

