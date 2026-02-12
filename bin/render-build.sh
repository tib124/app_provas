#!/bin/bash
set -e

echo "Running Rails database migrations..."
bundle exec rails db:migrate

echo "Launching Rails server..."
exec bundle exec rails server -p $PORT
