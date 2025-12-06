# Telegram Wake-on-LAN Bot - Docker Edition

A secure, containerized Telegram bot for sending Wake-on-LAN packets to devices on your network.

## Version 2.0 - Security Hardened

This version has been completely rewritten with security as the top priority:

### Security Improvements

✅ **No Command Injection** - All eval() removed, safe variable handling
✅ **Input Validation** - MAC addresses, user IDs, device names validated
✅ **Environment Variables** - Secrets stored securely, not in code
✅ **Rate Limiting** - Prevents spam and abuse
✅ **Non-root Container** - Runs as unprivileged user
✅ **Minimal Attack Surface** - Alpine Linux, only essential packages
✅ **Read-only Filesystem** - Container filesystem is read-only
✅ **Capability Dropping** - Only NET_RAW capability for WOL
✅ **No Exposed Ports** - Only outbound connections
✅ **Resource Limits** - CPU and memory constraints
✅ **Proper Logging** - No secrets in logs

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Network access for Wake-on-LAN
- Telegram account

### 1. Create Telegram Bot

1. Message **@BotFather** on Telegram
2. Send `/newbot` and follow prompts
3. Save your bot token (looks like `123456789:ABCdef...`)

### 2. Get Your User ID

1. Message **@userinfobot** on Telegram
2. Send `/start`
3. Save your user ID (a number like `123456789`)

### 3. Clone and Configure

```bash
# Clone the repository
cd wake-on-lan-bot

# Create environment file
cp .env.example .env

# Edit .env with your bot token and user ID
nano .env
# Set:
#   BOT_TOKEN=your_token_here
#   AUTHORIZED_USERS=your_user_id
```

### 4. Configure Devices

```bash
# Create device configuration
cp devices.conf.example devices.conf

# Edit with your devices
nano devices.conf
# Add your devices with real MAC addresses
```

### 5. Set Secure Permissions

```bash
# Protect sensitive files
chmod 600 .env
chmod 600 devices.conf
```

### 6. Start the Bot

```bash
# Build and start
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps
```

### 7. Test in Telegram

1. Find your bot in Telegram
2. Send `/start` - should get welcome message
3. Send `/list` - should show your devices
4. Send `/wake pc` - should send WOL packet

## Configuration

### Environment Variables (.env)

**Required:**
```bash
BOT_TOKEN=your_telegram_bot_token
AUTHORIZED_USERS=space_separated_user_ids
```

**Optional:**
```bash
DEFAULT_INTERFACE=br-lan
RATE_LIMIT_SECONDS=10
TZ=UTC
```

### Device Configuration (devices.conf)

```bash
# Format
DEVICE_<KEY>_NAME="Friendly Name"
DEVICE_<KEY>_MAC="AA:BB:CC:DD:EE:FF"
DEVICE_<KEY>_INTERFACE="br-lan"  # Optional

# Example
DEVICE_PC_NAME="Gaming PC"
DEVICE_PC_MAC="A8:5E:45:59:C0:DA"
DEVICE_PC_INTERFACE="br-lan"
```

**Rules:**
- Device KEY must be UPPERCASE, alphanumeric + underscores
- MAC must be format `AA:BB:CC:DD:EE:FF`
- Names can contain letters, numbers, spaces, dots, dashes
- Interface is optional (uses DEFAULT_INTERFACE if not set)

## Docker Architecture

### Container Security Features

```yaml
# Non-root user
USER wolbot (UID 1000)

# Network mode
network_mode: host  # Required for WOL broadcasting

# Capabilities
cap_drop: ALL
cap_add: NET_RAW  # Only capability needed for WOL

# Filesystem
read_only: true   # Container filesystem is read-only
tmpfs: /tmp       # Temporary files only in memory

# Resources
CPU: 0.5 max, 0.1 reserved
Memory: 128M max, 32M reserved

# Security
no-new-privileges: true
```

### Port Exposure

**No ports are exposed.** The bot only makes outbound connections:
- To Telegram API (api.telegram.org) on port 443 (HTTPS)
- WOL packets are broadcast on local network (UDP port 9)

### File Structure

```
/app/
├── bot.sh                    # Main bot script (read-only)
├── devices.conf              # Device config (mounted, read-only)
├── devices.conf.example      # Example config
└── state/                    # State directory (read-write)
    └── offset                # Last processed Telegram update ID
```

## Commands Reference

| Command | Description | Example |
|---------|-------------|---------|
| `/start` or `/help` | Show welcome and help | `/start` |
| `/wake <device>` | Wake up a device | `/wake PC` |
| `/list` | Show all configured devices | `/list` |

## Management Commands

```bash
# Start bot
docker-compose up -d

# Stop bot
docker-compose down

# Restart bot (after config changes)
docker-compose restart

# View logs
docker-compose logs -f

# View logs (last 100 lines)
docker-compose logs --tail=100

# Check status
docker-compose ps

# Rebuild after code changes
docker-compose up -d --build

# Shell access (for debugging)
docker-compose exec telegram-wol-bot /bin/bash
```

## Updating Configuration

After changing `.env` or `devices.conf`:

```bash
# Restart the container
docker-compose restart

# Check logs to verify reload
docker-compose logs -f
```

## Troubleshooting

### Bot not responding

```bash
# Check if container is running
docker-compose ps

# Check logs for errors
docker-compose logs --tail=50

# Check environment variables
docker-compose exec telegram-wol-bot env | grep BOT_TOKEN
```

### WOL not working

1. **Check device BIOS** - Enable Wake-on-LAN
2. **Use wired connection** - WOL doesn't work over WiFi
3. **Verify MAC address**:
   ```bash
   # On host system
   arp -a
   ip neigh
   ```
4. **Test manually**:
   ```bash
   # From host
   etherwake -i br-lan AA:BB:CC:DD:EE:FF
   ```

### "Access denied" message

1. Get your user ID from @userinfobot
2. Add it to `AUTHORIZED_USERS` in `.env`
3. Restart: `docker-compose restart`

### Container won't start

```bash
# View detailed logs
docker-compose logs

# Check for common issues:
# - Missing .env file
# - Invalid BOT_TOKEN format
# - Missing devices.conf file

# Rebuild from scratch
docker-compose down
docker-compose up -d --build
```

### High memory usage

Current limits are conservative (128M max). If needed:

```yaml
# In docker-compose.yml
resources:
  limits:
    memory: 64M  # Reduce if needed
```

## Security Best Practices

### 1. Protect Secrets

```bash
# Set restrictive permissions
chmod 600 .env
chmod 600 devices.conf

# Never commit to git
git rm --cached .env devices.conf
```

### 2. Regular Updates

```bash
# Update base image
docker-compose pull
docker-compose up -d --build

# Update Alpine packages
docker-compose build --no-cache
```

### 3. Monitor Logs

```bash
# Watch for unauthorized attempts
docker-compose logs -f | grep "Unauthorized"

# Review activity
docker-compose logs --since 24h
```

### 4. Backup Configuration

```bash
# Backup secrets
cp .env .env.backup
cp devices.conf devices.conf.backup

# Store securely, not in git!
```

### 5. Rotate Bot Token

If your token is compromised:

1. Talk to @BotFather
2. Send `/mybots` → Select bot → API Token → Revoke
3. Generate new token
4. Update `.env` file
5. Restart: `docker-compose restart`

## Network Requirements

### Outbound (Required)

- **api.telegram.org** - Port 443 (HTTPS) - Telegram API
- **DNS** - Port 53 (UDP/TCP) - Name resolution

### Local Network (Required)

- **WOL Broadcast** - UDP port 9 - Magic packets to wake devices

### Inbound (None)

No inbound ports required or exposed.

## Advanced Configuration

### Custom Network Interface

```bash
# In .env
DEFAULT_INTERFACE=eth0

# Or per-device in devices.conf
DEVICE_PC_INTERFACE=eno1
```

### Rate Limiting

```bash
# In .env - minimum seconds between WOL commands
RATE_LIMIT_SECONDS=30
```

### Debug Logging

```bash
# View real-time logs with timestamps
docker-compose logs -f --timestamps

# Increase log retention
# In docker-compose.yml:
logging:
  options:
    max-size: "50m"
    max-file: "10"
```

## Migration from OpenWRT Version

If migrating from the old shell script version:

1. **Export your configuration:**
   ```bash
   # From old config.conf, note your:
   # - BOT_TOKEN
   # - AUTHORIZED_USERS
   # - Device configurations
   ```

2. **Set up Docker version:**
   ```bash
   # Create .env with your token and users
   # Create devices.conf with your devices
   ```

3. **Stop old version:**
   ```bash
   /etc/init.d/telegram-wol-bot stop
   /etc/init.d/telegram-wol-bot disable
   ```

4. **Start Docker version:**
   ```bash
   docker-compose up -d
   ```

## Uninstallation

```bash
# Stop and remove containers
docker-compose down

# Remove images
docker-compose down --rmi all

# Remove volumes
docker-compose down -v

# Remove all files
cd ..
rm -rf wake-on-lan-bot
```

## Support

For issues or questions:
- Check logs: `docker-compose logs`
- Review this documentation
- Check Docker and network configuration

## License

Free to use and modify. No warranty provided.

---

**Version 2.0** - Secure Docker Edition
Built with security, simplicity, and reliability in mind.