# Use Elixir 1.15 with Alpine Linux (lightweight base image)
FROM elixir:1.15-alpine

# Set environment
ENV MIX_ENV=prod

# Install essential build tools and dependencies
# build-base: Required for compiling dependencies
# npm: For JavaScript asset management
# git: For fetching dependencies
# python3: Required by some build processes
RUN apk add --no-cache build-base npm git python3

# Set the working directory in the container
WORKDIR /app

# Install Elixir's package manager (hex) and build tool (rebar)
RUN mix local.hex --force && \
   mix local.rebar --force

# Copy project dependency files first (for better caching)
COPY mix.exs mix.lock ./
COPY config config

# Copy frontend asset files
COPY assets assets

# Copy the rest of the application code
COPY priv priv
COPY lib lib

# Install Elixir dependencies for production only
RUN mix deps.get --only prod
RUN mix deps.compile

# Return to main directory and build the release
WORKDIR /app
RUN mix assets.deploy
RUN mix compile
RUN mix phx.digest

# Set port
ENV PORT=4000

# Define the port the container will listen on
EXPOSE 4000

# Command to start the Phoenix server
CMD ["mix", "phx.server"]