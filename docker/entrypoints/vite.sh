#!/bin/sh
set -x

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

pnpm store prune
pnpm install --force

gem install bundler -v '2.5.16'

echo "Ready to run Vite development server."

exec "$@"
