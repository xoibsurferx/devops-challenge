#!/bin/sh
set -e
if [ "${SKIP_DB_MIGRATE}" = "true" ]; then
  echo "SKIP_DB_MIGRATE=true, skipping Prisma migrations"
else
  echo "Running Prisma migrate deploy"
  prisma migrate deploy
fi
echo "Starting Next.js server"
exec node server.js
