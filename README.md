# CognitUs

CognitUs is a real-time collaborative text editor built with the Phoenix Framework.

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
- Erlang (https://www.erlang.org/downloads) - Required for Elixir
- Elixir (needed to generate secret key)

If running on your local machine, you will need to install:
- Erlang (https://www.erlang.org/downloads) - Required for Elixir
- Elixir (https://elixir-lang.org/install.html)
- PostgreSQL (https://www.postgresql.org/download/)

## Running with Docker

1. Clone the repo
```bash
git clone https://github.com/mihcaoj/cognitus
```
```bash
cd cognitus
```

2. Set up environment variables

   2.1 For Unix-Like systems (Linux / MacOS)
   ```bash
   cp .env.example .env && echo SECRET_KEY_BASE=$(mix phx.gen.secret) >> .env
   ```

   2.2 For Windows

   2.2.1 Command Prompt:
   ```bash
   copy .env.example .env
   ```
   ```bash
   for /f "delims=" %A in ('mix phx.gen.secret') do set SECRET_KEY_BASE=%A && echo SECRET_KEY_BASE=%A>>.env
   ```

   2.2.2 Powershell:
   ```powershell
   Copy-Item .env.example .env
   ```
   ```powershell
   $secret = mix phx.gen.secret
   ```
   ```powershell
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
```
```bash
docker-compose exec app mix ecto.migrate
```

5. Access the application at http://localhost:4000

6. Cleanup (remove all containers, networks and volumes):
```bash
docker-compose down -v
```

7. To test out the functionalities, you can open up two or more browser windows side to side and try inputting text in one or the other

## Local development setup

1. Clone the repo
```bash
git clone https://github.com/mihcaoj/cognitus
```
```bash
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

   3.2.1 Command Prompt:
   ```bash
   copy .env.example .env
   ```
   ```bash
   for /f "delims=" %A in ('mix phx.gen.secret') do set SECRET_KEY_BASE=%A && echo SECRET_KEY_BASE=%A>>.env
   ```

   3.2.2 Powershell:
   ```powershell
   Copy-Item .env.example .env
   ```
   ```powershell
   $secret = mix phx.gen.secret
   ```
   ```powershell
   Add-Content .env "SECRET_KEY_BASE=$secret"
   ```

4. Set PostgreSQL default password
   
   4.1 For Unix-Like systems (Linux / MacOS)
   ```bash
   sudo -u postgres psql
   ```
   ```bash
   \password postgres
   ```

   4.2 For Windows Powershell:
   ```powershell
   psql -U postgres
   ```
   ```powershell
   \password postgres
   ```

5. Create and migrate the database
```elixir
mix ecto.create
```
```elixir
mix ecto.migrate
```

6. Start the Phoenix server
```elixir
mix phx.server
```

7. Access the application at http://localhost:4000

8. To test out the functionalities, you can open up two or more browser windows side to side and try inputting text in one or the other

## Troubleshooting
- If the database fails to start, ensure PostgreSQL is not running locally on port 5432
- If mix commands fail in Docker, ensure you've completed the environment setup
- For connection issues, verify you're using http://localhost:4000
- While testing on a linux machine, if you run into a problem with the mint dependency, try: mix deps.get mint hpax
