#!/bin/sh
set -e
if [ "${SKIP_DB_MIGRATE}" = "true" ]; then
  echo "SKIP_DB_MIGRATE=true, skipping Prisma migrations"
else
  echo "Running Prisma migrate deploy"
  cd /app
  # prisma.config.ts imports "prisma/config" — resolution starts from /app; standalone has no prisma package.
  export NODE_PATH="/opt/prisma-cli/node_modules${NODE_PATH:+:$NODE_PATH}"
  /opt/prisma-cli/node_modules/.bin/prisma migrate deploy
fi
echo "Starting Next.js server"
exec node server.js
