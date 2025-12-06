# Telegram Wake-on-LAN Bot for OpenWRT

A lightweight shell script-based Telegram bot that runs on OpenWRT routers to send Wake-on-LAN packets to devices on your network.

## 🆕 What's New in v2.0

- 🔒 **Enterprise-grade security** with comprehensive input validation
- 🛡️ **Protection against command injection** attacks
- ⏱️ **Rate limiting** to prevent abuse (configurable, default 10 seconds)
- 📊 **Security logging** with complete audit trail
- ⚡ **Quick command**: `/wakepc` shortcut for faster PC wake-ups
- 🔐 **MAC/Interface validation** before sending WOL packets
- 🔄 **File locking** to prevent race conditions
- 📝 All security vulnerabilities fixed - see [SECURITY_FIXES.md](SECURITY_FIXES.md)

## Features

✅ **Lightweight** - Shell script with minimal dependencies (~300KB)
✅ **Secure** - Enterprise-grade security with input validation and rate limiting
✅ **Multiple Devices** - Manage unlimited devices
✅ **Auto-Start** - Runs as system service, survives reboots
✅ **Status Monitoring** - Check router and bot status
✅ **Security Logging** - Comprehensive audit trail of all actions
✅ **Rate Limiting** - Prevents abuse and network flooding
✅ **Quick Commands** - Shortcuts like `/wakepc` for faster access
✅ **Easy Setup** - Simple configuration file  

## Quick Start

### 1. Install Dependencies
```bash
opkg update
opkg install curl jq etherwake
```

### 2. Create Bot Directory
```bash
mkdir -p /root/wol-bot
cd /root/wol-bot
```

### 3. Copy Files
- `telegram-wol-bot.sh` - Main bot script
- `config.conf` - Configuration file
- `telegram-wol-bot-init` - Init script

### 4. Configure
```bash
vi config.conf
# Set BOT_TOKEN, AUTHORIZED_USERS, and device MAC addresses
```

### 5. Install Service
```bash
chmod +x telegram-wol-bot.sh
cp telegram-wol-bot-init /etc/init.d/telegram-wol-bot
chmod +x /etc/init.d/telegram-wol-bot
/etc/init.d/telegram-wol-bot enable
/etc/init.d/telegram-wol-bot start
```

## Telegram Commands

| Command | Description |
|---------|-------------|
| `/start` or `/help` | Show welcome and help message |
| `/wake <device>` | Wake up a device (e.g., `/wake pc`) |
| `/wakepc` | 🆕 Quick shortcut to wake PC device |
| `/list` | List all configured devices |
| `/status` | Show bot and router status |

## Example Usage

```
You: /list
Bot: 📋 Available Devices:
     🖥️ PC - Gaming PC
        MAC: AA:BB:CC:DD:EE:FF
     🖥️ NAS - NAS Server
        MAC: 11:22:33:44:55:66

You: /wake pc
Bot: ✅ Wake-on-LAN packet sent to Gaming PC
     Device: PC
     MAC: AA:BB:CC:DD:EE:FF
     Interface: br-lan

You: /wakepc
Bot: ✅ Wake-on-LAN packet sent to Gaming PC
     Device: PC
     MAC: AA:BB:CC:DD:EE:FF
     Interface: br-lan
```

**Rate Limiting Example:**
```
You: /wakepc
Bot: ✅ Wake-on-LAN packet sent to Gaming PC...

You: /wakepc (immediately after)
Bot: ⏱ Rate limit: Please wait 8 seconds before waking Gaming PC again.
```

## Configuration Example

```bash
# config.conf
BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
AUTHORIZED_USERS="123456789 987654321"
DEFAULT_INTERFACE="br-lan"

# Optional: Rate limiting (seconds between WOL commands, default: 10)
RATE_LIMIT_SECONDS=10

# Device configurations
DEVICE_PC_NAME="Gaming PC"
DEVICE_PC_MAC="AA:BB:CC:DD:EE:FF"

DEVICE_NAS_NAME="NAS Server"
DEVICE_NAS_MAC="11:22:33:44:55:66"
```

## System Requirements

- **Router**: OpenWRT (any recent version)
- **Storage**: ~500KB free space
- **RAM**: ~2-5MB while running
- **Network**: Internet access for Telegram API

## Files Structure

```
/root/wol-bot/
├── telegram-wol-bot.sh    # Main bot script
├── config.conf            # Configuration file
├── security.log           # Security audit log (auto-created)
└── state/                 # State directory (auto-created)
    ├── offset             # Telegram API offset
    ├── rate_limit         # Rate limiting timestamps
    └── offset.lock        # File lock for atomic updates

/etc/init.d/
└── telegram-wol-bot       # Service init script
```

## Service Management

```bash
/etc/init.d/telegram-wol-bot start    # Start bot
/etc/init.d/telegram-wol-bot stop     # Stop bot
/etc/init.d/telegram-wol-bot restart  # Restart bot
/etc/init.d/telegram-wol-bot status   # Check status
```

## Security Features

### 🔒 Enterprise-Grade Security

- ✅ **User ID Authentication** - Only authorized Telegram users can control the bot
- ✅ **Input Validation** - Strict regex validation prevents command injection attacks
- ✅ **MAC Address Validation** - All MAC addresses validated before sending WOL packets
- ✅ **Interface Validation** - Network interfaces verified to exist before use
- ✅ **Rate Limiting** - Configurable rate limits prevent abuse (default: 10 seconds)
- ✅ **Security Logging** - All actions logged to `/root/wol-bot/security.log`
- ✅ **File Locking** - Atomic state file updates prevent race conditions
- ✅ **Secure Permissions** - State files created with chmod 600, directories with 700
- ✅ **No Public API** - Bot communicates only with Telegram's servers
- ✅ **Local Network Only** - WOL packets sent only to local network
- ✅ **Command Whitelist** - Only predefined commands accepted

### 📊 Security Logging

View security events:
```bash
tail -f /root/wol-bot/security.log
```

Events logged:
- Bot start/stop
- Unauthorized access attempts
- Invalid input attempts
- All WOL commands (success and failure)
- Invalid MAC addresses or interfaces

### 🛡️ Security Hardening

The bot protects against:
- Command injection attacks
- Information disclosure
- Network flooding
- Unauthorized access
- Race conditions
- Input validation bypass

**For detailed security information, see [SECURITY_FIXES.md](SECURITY_FIXES.md)**

## Troubleshooting

### Bot not responding?
```bash
# Check if running
ps | grep telegram-wol-bot

# Check connectivity
ping api.telegram.org

# Restart service
/etc/init.d/telegram-wol-bot restart
```

### WOL not working?
- Enable WOL in target device BIOS
- Verify MAC address: `arp -a`
- Test manually: `etherwake -i br-lan AA:BB:CC:DD:EE:FF`
- Ensure device is connected via Ethernet (not WiFi)

### Unauthorized message?
- Get your user ID from @userinfobot
- Add it to `AUTHORIZED_USERS` in config.conf
- Restart bot: `/etc/init.d/telegram-wol-bot restart`

## Advanced Features

### Customize Rate Limiting
Edit `config.conf` to change the rate limit:
```bash
# Allow WOL commands every 15 seconds instead of default 10
RATE_LIMIT_SECONDS=15

# Disable rate limiting (not recommended)
RATE_LIMIT_SECONDS=0
```

### View Security Logs
Monitor all bot activity in real-time:
```bash
# Follow security log
tail -f /root/wol-bot/security.log

# View last 50 events
tail -n 50 /root/wol-bot/security.log

# Search for unauthorized attempts
grep "UNAUTHORIZED" /root/wol-bot/security.log

# Search for specific user activity
grep "User 123456789" /root/wol-bot/security.log
```

### Multiple Network Interfaces
```bash
DEVICE_PC_INTERFACE="br-lan"
DEVICE_SERVER_INTERFACE="eth1"
```

### Debug Logging
```bash
# Edit telegram-wol-bot.sh, add at top of main():
exec >> /tmp/telegram-wol-bot.log 2>&1
```

### Custom Polling Interval
```bash
# Edit telegram-wol-bot.sh, find:
response=$(get_updates "$offset" 30)
# Change 30 to desired seconds (higher = less CPU usage)
```

## Getting Your Telegram Bot Token

1. Open Telegram, search for **@BotFather**
2. Send `/newbot`
3. Choose a name and username
4. Copy the API token provided

## Getting Your Telegram User ID

1. Search for **@userinfobot** on Telegram
2. Send `/start`
3. Copy your user ID number

## Adding More Devices

Edit `config.conf` and add:
```bash
DEVICE_NEWPC_NAME="My New PC"
DEVICE_NEWPC_MAC="FF:EE:DD:CC:BB:AA"
DEVICE_NEWPC_INTERFACE="br-lan"
```

Then restart: `/etc/init.d/telegram-wol-bot restart`

## Why OpenWRT Router?

- ✅ Always-on device (no separate server needed)
- ✅ Already on your network (direct WOL access)
- ✅ Low power consumption
- ✅ Central management point
- ✅ No additional hardware required

## Documentation

- 📖 **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Detailed installation instructions
- 📖 **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick command reference
- 🔒 **[SECURITY_FIXES.md](SECURITY_FIXES.md)** - Complete security audit and fixes
- 📊 **[SECURITY_SUMMARY.md](SECURITY_SUMMARY.md)** - Security overview and setup

## License

Free to use and modify. No warranty provided.

## Credits

Created for home automation enthusiasts who want simple, reliable Wake-on-LAN control via Telegram.

---

**🔒 Production-ready with enterprise-grade security | v2.0**
