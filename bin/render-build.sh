#!/bin/bash
set -e

# Esperar o PostgreSQL estar pronto
echo "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
  if bundle exec rails db:migrate --no-comment 2>/dev/null; then
    echo "Database migrations completed successfully"
    break
  fi
  echo "Attempt $i/30: Waiting for database..."
  sleep 2
done

echo "Launching Rails server..."
exec bundle exec rails server -p $PORT
