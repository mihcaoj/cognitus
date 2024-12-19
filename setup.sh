#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'

echo -e "${YELLOW}Starting CognitUs development setup...${NC}"

# Check if Elixir is installed
if ! command -v elixir >/dev/null 2>&1; then
    echo -e "${RED}Elixir is not installed! Please install Elixir first.${NC}"
    echo "Visit: https://elixir-lang.org/install.html"
    exit 1
fi

# Check if PostgreSQL is installed
if ! command -v psql >/dev/null 2>&1; then
    echo -e "${RED}PostgreSQL is not installed! Please install PostgreSQL first.${NC}"
    echo "Visit: https://www.postgresql.org/download/"
    exit 1
fi

echo -e "${GREEN}Installing Hex package manager...${NC}"
mix local.hex --force

echo -e "${GREEN}Installing Rebar...${NC}"
mix local.rebar --force

echo -e "${GREEN}Installing Phoenix...${NC}"
mix archive.install hex phx_new --force

echo -e "${GREEN}Installing dependencies...${NC}"
mix deps.get

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${GREEN}Creating .env file...${NC}"
    cp .env.example .env
    SECRET_KEY_BASE=$(mix phx.gen.secret)
    echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" >> .env
fi

# Setup the database
echo -e "${GREEN}Setting up the database...${NC}"
mix ecto.create
mix ecto.migrate

echo -e "\n${GREEN}Setup complete! Starting Phoenix server...${NC}"
echo -e "${YELLOW}You can access the application at: http://localhost:4000${NC}"
echo -e "${YELLOW}Press Ctrl+C twice to stop the server${NC}\n"

# Run the server
mix phx.server
