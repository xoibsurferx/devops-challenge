import { createRequire } from "node:module";
import path from "node:path";
import { defineConfig, env } from "prisma/config";

// Prisma 7: do not put `url` in schema.prisma (P1012); use config + env here.
// Local: optional dotenv. Production image: add `prisma` to /app/node_modules in Dockerfile;
// try/catch for dotenv in minimal bundles.
const require = createRequire(import.meta.url);
try {
  require("dotenv/config");
} catch {
  // optional
}

export default defineConfig({
  schema: path.join("prisma", "schema.prisma"),
  datasource: {
    url: env("POSTGRES_PRISMA_URL"),
  },
  migrations: {
    path: path.join("prisma", "migrations"),
  },
});

