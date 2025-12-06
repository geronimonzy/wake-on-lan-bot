# Telegram Wake-on-LAN Bot

A secure, containerized Telegram bot for sending Wake-on-LAN packets to devices on your network.

## Version 2.0 - Docker Edition (Recommended)

This project has been completely rewritten with security improvements and Docker deployment.

**📖 [Go to Docker Documentation](README_DOCKER.md)** for complete setup instructions.

## Quick Start

```bash
# 1. Run interactive setup
./setup.sh

# 2. Or manual setup
cp .env.example .env
cp devices.conf.example devices.conf
# Edit .env and devices.conf with your values
chmod 600 .env devices.conf

# 3. Start the bot
docker-compose up -d

# 4. View logs
docker-compose logs -f
```

## Features

✅ **Secure** - All vulnerabilities from v1.0 fixed
✅ **Docker** - Containerized deployment
✅ **No Command Injection** - Safe input validation
✅ **Environment Variables** - Proper secret management
✅ **Rate Limiting** - Prevent abuse
✅ **Non-root Container** - Minimal privileges
✅ **No Exposed Ports** - Outbound connections only

## Documentation

- **[README_DOCKER.md](README_DOCKER.md)** - Complete Docker setup guide
- **[SECURITY.md](SECURITY.md)** - Security fixes and best practices
- **[MIGRATION.md](MIGRATION.md)** - Migrate from OpenWRT version
- **[UNINSTALL_OPENWRT.md](UNINSTALL_OPENWRT.md)** - Remove old version
- **[old-openwrt/](old-openwrt/)** - Legacy OpenWRT version (deprecated)

## Requirements

- Docker and Docker Compose
- Network access for Wake-on-LAN
- Telegram bot token (get from @BotFather)

## Quick Commands

```bash
make help      # Show all commands
make setup     # Interactive setup
make start     # Start the bot
make logs      # View logs
make stop      # Stop the bot
make restart   # Restart (after config changes)
```

## Telegram Commands

| Command | Description |
|---------|-------------|
| `/start` or `/help` | Show help message |
| `/wake <device>` | Wake a device |
| `/wakepc` | Wake PC (shortcut) |
| `/list` | Show all devices |

## Security

Version 2.0 fixes **15 vulnerabilities** from the original OpenWRT version:
- 4 Critical (command injection, exposed secrets)
- 2 High (information disclosure)
- 5 Medium (validation, rate limiting)
- 4 Low (permissions, logging)

See [SECURITY.md](SECURITY.md) for details.

## Migration from OpenWRT

If you're using the old OpenWRT shell script version:

1. See [MIGRATION.md](MIGRATION.md) for migration guide
2. Set up Docker version and test
3. Use [UNINSTALL_OPENWRT.md](UNINSTALL_OPENWRT.md) to remove old version

## Support

For issues or questions:
- Check [README_DOCKER.md](README_DOCKER.md)
- Review logs: `docker-compose logs`
- See [SECURITY.md](SECURITY.md) for best practices

## License

Free to use and modify. No warranty provided.

---

**Version 2.0** - Secure Docker Edition
Previous OpenWRT version: [old-openwrt/](old-openwrt/)