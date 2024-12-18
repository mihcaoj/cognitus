# CognitUs

CognitUs is a web-based, real-time collaborative text editor built with the Phoenix Framework.

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
- Docker (https://www.docker.com)
- Erlang (https://www.erlang.org/downloads)
- Elixir (needed to generate secret key)

If running on your local machine, you will need to install:
- Erlang (https://www.erlang.org/downloads)
- Elixir (https://elixir-lang.org/install.html)
- PostgreSQL (https://www.postgresql.org/download/)

## Running with Docker

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

Command Prompt:
```bash
copy .env.example .env
```
```bash
for /f "delims=" %A in ('mix phx.gen.secret') do set SECRET_KEY_BASE=%A && echo SECRET_KEY_BASE=%A>>.env
```

Powershell:
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

3.1 For Unix-Like systems (Linux / MacOS)
```bash
cp .env.example .env && echo SECRET_KEY_BASE=$(mix phx.gen.secret) >> .env
```

3.2 For Windows

Command Prompt:
```bash
copy .env.example .env
```
```bash
for /f "delims=" %A in ('mix phx.gen.secret') do set SECRET_KEY_BASE=%A && echo SECRET_KEY_BASE=%A>>.env
```

Powershell:
```powershell
Copy-Item .env.example .env
```
```powershell
$secret = mix phx.gen.secret
```
```powershell
Add-Content .env "SECRET_KEY_BASE=$secret"
```

4. Generate a secret key and update .env
```elixir
mix phx.gen.secret
```

5. Set PostgreSQL default password
   
5.1 For Unix-Like systems (Linux / MacOS)
```bash
sudo -u postgres psql
\password postgres
```

5.2 For Windows

Windows Powershell:
```powershell
psql -U postgres
\password postgres
```

6. Create and migrate the database
```elixir
mix ecto.create
mix ecto.migrate
```

7. Start the Phoenix server
```elixir
mix phx.server
```

8. Access the application at http://localhost:4000

## Troubleshooting
- If the database fails to start, ensure PostgreSQL is not running locally on port 5432
- If mix commands fail in Docker, ensure you've completed the environment setup
- For connection issues, verify you're using http://localhost:4000
