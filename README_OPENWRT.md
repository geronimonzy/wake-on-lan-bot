# Telegram Wake-on-LAN Bot for OpenWRT

A lightweight shell script-based Telegram bot that runs on OpenWRT routers to send Wake-on-LAN packets to devices on your network.

## Features

✅ **Lightweight** - Shell script with minimal dependencies (~300KB)  
✅ **Secure** - User authentication via Telegram user IDs  
✅ **Multiple Devices** - Manage unlimited devices  
✅ **Auto-Start** - Runs as system service, survives reboots  
✅ **Status Monitoring** - Check router and bot status  
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
| `/start` | Show welcome and help |
| `/wake <device>` | Wake up a device |
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
```

## Configuration Example

```bash
# config.conf
BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
AUTHORIZED_USERS="123456789 987654321"
DEFAULT_INTERFACE="br-lan"

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
└── config.conf            # Configuration file

/etc/init.d/
└── telegram-wol-bot       # Service init script

/tmp/
└── telegram-bot-offset    # State file (auto-created)
```

## Service Management

```bash
/etc/init.d/telegram-wol-bot start    # Start bot
/etc/init.d/telegram-wol-bot stop     # Stop bot
/etc/init.d/telegram-wol-bot restart  # Restart bot
/etc/init.d/telegram-wol-bot status   # Check status
```

## Security Features

- ✅ User ID authentication
- ✅ No public API exposure
- ✅ Local network WOL only
- ✅ Secure token storage
- ✅ Command whitelist

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

## License

Free to use and modify. No warranty provided.

## Credits

Created for home automation enthusiasts who want simple, reliable Wake-on-LAN control via Telegram.

---

**📖 For detailed installation instructions, see [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)**
