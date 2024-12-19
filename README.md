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
- Docker (https://www.docker.com/get-started)
- Docker Compose (https://docs.docker.com/compose/install/) - Usually included with Docker Desktop

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

2. Start the application
```bash
docker-compose up --build
```

3. Access the application at http://localhost:4000

That's it! The application will automatically:
- Set up all necessary dependencies
- Configure the database
- Start the Phoenix server

When you are done testing, you can do the cleanup (remove all containers, networks and volumes):
```bash
docker-compose down -v
```

Note: To test out the functionalities, you can open up two or more browser windows side to side and try inputting text in one or the other.

## Local development setup

1. Clone the repo
```bash
git clone https://github.com/mihcaoj/cognitus
```
```bash
cd cognitus
```

2. Make the setup script executable
```bash
chmod +x setup.sh
```

3. Run the setup script:
```bash
./setup.sh
```

4. Access the application at http://localhost:4000

Note: To test out the functionalities, you can open up two or more browser windows side to side and try inputting text in one or the other.

## Manual Setup (if you prefer not to use the script)

If you prefer to set up manually or the script doesn't work for your environment:

1. Clone the repo
```bash
git clone https://github.com/mihcaoj/cognitus
```
```bash
cd cognitus
```

2. Install necessary packages and get the dependencies:
```elixir
mix local.hex --force
```
```elixir
mix local.rebar --force
```
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

Note: To test out the functionalities, you can open up two or more browser windows side to side and try inputting text in one or the other.

## Troubleshooting
- If the database fails to start, ensure PostgreSQL is not running locally on port 5432
- If mix commands fail in Docker, ensure you've completed the environment setup
- For connection issues, verify you're using http://localhost:4000
- While testing on a linux machine, if you run into a problem with the mint dependency, try: mix deps.get mint hpax
