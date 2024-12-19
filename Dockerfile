# Build stage
FROM elixir:1.15-alpine AS builder

# Set environment variable
ENV MIX_ENV=prod

# Install build dependencies
RUN apk add --no-cache build-base git python3

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy configuration files first
COPY mix.exs mix.lock ./
COPY config/config.exs config/
COPY config/prod.exs config/

# Get dependencies
RUN mix deps.get --only prod

# Copy remaining application files
COPY assets assets
COPY priv priv
COPY lib lib

# Compile and build release
RUN mix assets.deploy && \
    mix compile && \
    mix phx.digest

# Runtime stage
FROM elixir:1.15-alpine

# Set environment variable
ENV MIX_ENV=prod

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs netcat-openbsd build-base git

# Install hex and rebar in runtime stage
RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

# Copy the build artifacts from builder stage
COPY --from=builder /app /app
COPY --from=builder /root/.mix /root/.mix
COPY --from=builder /root/.hex /root/.hex

# Copy entrypoint script
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 4000

ENTRYPOINT ["/app/docker-entrypoint.sh"]
