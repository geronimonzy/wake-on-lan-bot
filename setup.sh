#!/bin/bash
# Telegram WOL Bot - Quick Setup Script
# This script helps you set up the bot quickly and securely

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "=========================================="
echo "  Telegram Wake-on-LAN Bot Setup"
echo "  Version 2.0 - Docker Edition"
echo "=========================================="
echo -e "${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    echo "Please install Docker Compose first: https://docs.docker.com/compose/install/"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose are installed${NC}"
echo

# Create .env file if it doesn't exist
if [ -f ".env" ]; then
    echo -e "${YELLOW}Warning: .env file already exists${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing .env file"
    else
        cp .env.example .env
        echo -e "${GREEN}✓ Created new .env file${NC}"
    fi
else
    cp .env.example .env
    echo -e "${GREEN}✓ Created .env file${NC}"
fi

# Create devices.conf if it doesn't exist
if [ -f "devices.conf" ]; then
    echo -e "${YELLOW}Warning: devices.conf file already exists${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing devices.conf file"
    else
        cp devices.conf.example devices.conf
        echo -e "${GREEN}✓ Created new devices.conf file${NC}"
    fi
else
    cp devices.conf.example devices.conf
    echo -e "${GREEN}✓ Created devices.conf file${NC}"
fi

# Create state directory
mkdir -p state
echo -e "${GREEN}✓ Created state directory${NC}"

echo
echo -e "${BLUE}=========================================="
echo "  Configuration Required"
echo "=========================================="
echo -e "${NC}"

# Prompt for bot token
echo -e "${YELLOW}Step 1: Get your Telegram bot token${NC}"
echo "  1. Open Telegram and search for @BotFather"
echo "  2. Send /newbot and follow the prompts"
echo "  3. Copy the bot token (looks like: 123456789:ABCdef...)"
echo
read -p "Enter your bot token: " BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    echo -e "${RED}Error: Bot token cannot be empty${NC}"
    exit 1
fi

# Basic token validation
if [[ ! "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]{35}$ ]]; then
    echo -e "${YELLOW}Warning: Bot token format looks unusual${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Prompt for user ID
echo
echo -e "${YELLOW}Step 2: Get your Telegram user ID${NC}"
echo "  1. Open Telegram and search for @userinfobot"
echo "  2. Send /start to the bot"
echo "  3. Copy your user ID (a number like: 123456789)"
echo
read -p "Enter your user ID: " USER_ID

if [ -z "$USER_ID" ]; then
    echo -e "${RED}Error: User ID cannot be empty${NC}"
    exit 1
fi

# Basic user ID validation
if [[ ! "$USER_ID" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: User ID must be a number${NC}"
    exit 1
fi

# Update .env file
sed -i.bak "s/^BOT_TOKEN=.*/BOT_TOKEN=$BOT_TOKEN/" .env
sed -i.bak "s/^AUTHORIZED_USERS=.*/AUTHORIZED_USERS=$USER_ID/" .env
rm -f .env.bak

echo -e "${GREEN}✓ Updated .env file with your credentials${NC}"

# Set secure permissions
chmod 600 .env
chmod 600 devices.conf
echo -e "${GREEN}✓ Set secure file permissions${NC}"

echo
echo -e "${BLUE}=========================================="
echo "  Device Configuration"
echo "=========================================="
echo -e "${NC}"

echo "You need to configure your devices in the devices.conf file"
echo "Example:"
echo "  DEVICE_PC_NAME=\"Gaming PC\""
echo "  DEVICE_PC_MAC=\"AA:BB:CC:DD:EE:FF\""
echo "  DEVICE_PC_INTERFACE=\"br-lan\""
echo

read -p "Do you want to edit devices.conf now? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    ${EDITOR:-nano} devices.conf
fi

echo
echo -e "${BLUE}=========================================="
echo "  Starting the Bot"
echo "=========================================="
echo -e "${NC}"

read -p "Do you want to start the bot now? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Building and starting the bot..."
    docker-compose up -d --build

    echo
    echo -e "${GREEN}✓ Bot is starting!${NC}"
    echo
    echo "To view logs:"
    echo "  docker-compose logs -f"
    echo
    echo "To check status:"
    echo "  docker-compose ps"
    echo
    echo "To stop the bot:"
    echo "  docker-compose down"
    echo

    echo -e "${BLUE}=========================================="
    echo "  Testing the Bot"
    echo "=========================================="
    echo -e "${NC}"

    echo "1. Open Telegram and find your bot"
    echo "2. Send /start - you should get a welcome message"
    echo "3. Send /list - you should see your configured devices"
    echo "4. Send /wake <device> - to send a WOL packet"
    echo

    echo -e "${GREEN}Setup complete!${NC}"
    echo
    echo "For more information, see:"
    echo "  - README_DOCKER.md - Complete documentation"
    echo "  - SECURITY.md - Security best practices"
else
    echo
    echo -e "${YELLOW}Setup complete!${NC}"
    echo
    echo "To start the bot later:"
    echo "  docker-compose up -d"
    echo
    echo "For more information, see:"
    echo "  - README_DOCKER.md - Complete documentation"
    echo "  - SECURITY.md - Security best practices"
fi

echo
echo -e "${BLUE}=========================================="
echo -e "${NC}"