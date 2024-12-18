# Cognitus

Cognitus is a web-based collaborative text editor built with the Phoenix Framework.

## Architecture

- Phoenix LiveView for real-time communication
- Phoenix Presence for user tracking
- CRDTs for conflict-free collaborative editing
- PostgreSQL for document persistence
- Docker for containerization

## Features

- Real-time collaborative text editing with CRDT to ensure consistency
- Presence tracking and caret indicators to see the connected users and where they are on the document
- Persistent document storage using PostgreSQL
- Docker support for easy deployment

## Project Structure
- `/lib` - Main application code
- `/config` - Configuration files
- `/assets` - Frontend assets
- `/priv` - Database migrations and static files

## Prerequisites

If running with Docker, you will need:
- Docker
- Elixir (needed to generate secret key)

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

2.1 For Unix-Like systems (Linux / MacOS)
```bash
cp .env.example .env && echo SECRET_KEY_BASE=$(mix phx.gen.secret) >> .env
```

2.2 For Windows

Windows Command Prompt:
```bash
copy .env.example .env
for /f "delims=" %A in ('mix phx.gen.secret') do set SECRET_KEY_BASE=%A && echo SECRET_KEY_BASE=%A>>.env
```

Windows Powershell:
```powershell
Copy-Item .env.example .env
$secret = mix phx.gen.secret
Add-Content .env "SECRET_KEY_BASE=$secret"
```

3. Build & Start the Docker containers
```bash
docker-compose up --build
```

or if you wish to run Docker Compose in detached mode:
```bash
docker-compose up -d --build
```

4. Create and migrate the database (in another terminal)
```bash
docker-compose exec app mix ecto.create
docker-compose exec app mix ecto.migrate
```

5. Access the application at http://localhost:4000

6. Cleanup (remove all containers, networks and volumes):
```bash
docker-compose down -v
```

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

## Troubleshooting
- If the database fails to start, ensure PostgreSQL is not running locally on port 5432
- If mix commands fail in Docker, ensure you've completed the environment setup
- For connection issues, verify you're using http://localhost:4000
