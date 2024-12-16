# Cognitus

Cognitus is a web-based collaborative text editor built with the Phoenix Framework.

## Architecture

- Phoenix LiveView for real-time communication
- Phoenix Presence for user tracking
- CRDTs for conflict-free collaborative editing
- PostgreSQL for document persistence
- Docker for containerization

## Features

- Real-time collaborative text editing
- CRDT to ensure consistency
- Presence tracking and caret indicators to see the connected users and where they are on the document
- Persistent document storage using Postgres
- Docker support for easy deployment

## Prerequisites

If running with Docker, you will need:
- Docker

If running on your local machine, you will need to install:
- Elixir 
- Postgres 

## Running with Docker (recommended)

1. Clone the repo
```bash
git clone https://github.com/mihcaoj/cognitus
cd cognitus
```

2. Set up environment variables
```bash
cp .env.example .env
```

3. Generate a secret key and update .env
```elixir
mix phx.gen.secret
```

4. Build & Start the Docker containers
```bash
docker-compose up --build
```

5. Access the application at http://localhost:4000

## Local development setup

1. Clone the repo
```bash
git clone https://github.com/mihcaoj/cognitus
cd cognitus
```

2. Install dependencies
```elixir
mix deps.get
```

3. Set up environment variables
```bash
cp .env.example .env
```

4. Generate a secret key and update .env
```elixir
mix phx.gen.secret
```

5. Create and migrate the database
```elixir
mix ecto.create
mix ecto.migrate
```

6. Start the Phoenix server
```elixir
mix phx.server
```

7. Access the application at http://localhost:4000
