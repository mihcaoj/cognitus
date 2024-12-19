#!/bin/sh

# Generate secret key if not provided
if [ -z "$SECRET_KEY_BASE" ]; then
    export SECRET_KEY_BASE=$(mix phx.gen.secret)
fi

# Ensure deps are available and compiled
mix deps.get --only prod
mix deps.compile

# Wait for database
while ! nc -z db 5432; do
    echo "Waiting for database..."
    sleep 1
done

# Setup database if it does not exist
mix ecto.create
mix ecto.migrate

# Start Phoenix server
mix phx.server
