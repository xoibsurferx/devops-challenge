import { createRequire } from "node:module";
import path from "node:path";
import { defineConfig, env } from "prisma/config";

// Local dev: load .env via dotenv from full node_modules. Production/standalone: dotenv is often
// not in the traced bundle — POSTGRES_PRISMA_URL is injected (Docker, Kubernetes secrets).
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
  }
});

