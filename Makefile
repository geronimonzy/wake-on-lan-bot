.PHONY: help setup build start stop restart logs status clean test shell

# Default target
help:
	@echo "Telegram Wake-on-LAN Bot - Docker Edition"
	@echo ""
	@echo "Available commands:"
	@echo "  make setup      - Run interactive setup script"
	@echo "  make build      - Build the Docker image"
	@echo "  make start      - Start the bot"
	@echo "  make stop       - Stop the bot"
	@echo "  make restart    - Restart the bot"
	@echo "  make logs       - View bot logs (follow mode)"
	@echo "  make status     - Check bot status"
	@echo "  make shell      - Open shell in container"
	@echo "  make clean      - Stop and remove containers"
	@echo "  make test       - Test configuration"
	@echo ""

# Run setup script
setup:
	@bash setup.sh

# Build the image
build:
	@echo "Building Docker image..."
	@docker-compose build

# Start the bot
start:
	@echo "Starting bot..."
	@docker-compose up -d
	@echo "Bot started! Use 'make logs' to view output"

# Stop the bot
stop:
	@echo "Stopping bot..."
	@docker-compose down
	@echo "Bot stopped"

# Restart the bot (useful after config changes)
restart:
	@echo "Restarting bot..."
	@docker-compose restart
	@echo "Bot restarted"

# View logs
logs:
	@docker-compose logs -f

# Check status
status:
	@echo "Bot status:"
	@docker-compose ps
	@echo ""
	@echo "Recent logs:"
	@docker-compose logs --tail=20

# Open shell in container
shell:
	@docker-compose exec telegram-wol-bot /bin/bash

# Clean up
clean:
	@echo "Stopping and removing containers..."
	@docker-compose down
	@echo "Clean complete"

# Test configuration
test:
	@echo "Testing configuration..."
	@echo ""
	@echo "Checking .env file..."
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found"; \
		exit 1; \
	else \
		echo "✓ .env file exists"; \
	fi
	@echo ""
	@echo "Checking devices.conf file..."
	@if [ ! -f devices.conf ]; then \
		echo "❌ devices.conf file not found"; \
		exit 1; \
	else \
		echo "✓ devices.conf file exists"; \
	fi
	@echo ""
	@echo "Checking file permissions..."
	@if [ "$$(stat -c %a .env 2>/dev/null || stat -f %Lp .env 2>/dev/null)" != "600" ]; then \
		echo "⚠️  Warning: .env permissions should be 600"; \
		echo "   Run: chmod 600 .env"; \
	else \
		echo "✓ .env has correct permissions"; \
	fi
	@echo ""
	@echo "Checking Docker..."
	@if ! command -v docker &> /dev/null; then \
		echo "❌ Docker not found"; \
		exit 1; \
	else \
		echo "✓ Docker is installed"; \
	fi
	@echo ""
	@echo "Checking Docker Compose..."
	@if ! command -v docker-compose &> /dev/null; then \
		echo "❌ Docker Compose not found"; \
		exit 1; \
	else \
		echo "✓ Docker Compose is installed"; \
	fi
	@echo ""
	@echo "Configuration looks good!"

# Rebuild (force rebuild without cache)
rebuild:
	@echo "Rebuilding from scratch..."
	@docker-compose build --no-cache
	@echo "Rebuild complete"

# Update and rebuild
update: stop
	@echo "Pulling latest images..."
	@docker-compose pull
	@make rebuild
	@make start
	@echo "Update complete"