# Uninstalling the Old OpenWRT Bot

Complete guide to remove the old Wake-on-LAN bot from your OpenWRT router.

## ⚠️ Before You Start

**Important:** Only proceed if you've:
1. Migrated to the Docker version and confirmed it works, OR
2. Decided to completely remove the bot

**Backup first:**
```bash
# SSH into your OpenWRT router
ssh root@YOUR_ROUTER_IP

# Backup your configuration
mkdir -p /root/backups
cp /root/wol-bot/config.conf /root/backups/config.conf.$(date +%Y%m%d)
tar -czf /root/backups/wol-bot-backup-$(date +%Y%m%d).tar.gz /root/wol-bot/
```

## Step-by-Step Uninstallation

### Step 1: Stop the Service

```bash
# SSH into your OpenWRT router
ssh root@YOUR_ROUTER_IP

# Stop the bot
/etc/init.d/telegram-wol-bot stop

# Verify it stopped
ps | grep telegram-wol-bot
# Should return nothing
```

### Step 2: Disable Auto-Start

```bash
# Disable service from starting on boot
/etc/init.d/telegram-wol-bot disable

# Verify it's disabled
ls -l /etc/rc.d/ | grep telegram
# Should return nothing
```

### Step 3: Remove Service Files

```bash
# Remove the init script
rm /etc/init.d/telegram-wol-bot

# Verify removal
ls -l /etc/init.d/telegram-wol-bot
# Should return "No such file or directory"
```

### Step 4: Remove Bot Files

```bash
# Remove the main bot directory
rm -rf /root/wol-bot

# Verify removal
ls -l /root/wol-bot
# Should return "No such file or directory"
```

### Step 5: Remove State Files

```bash
# Remove temporary state file
rm -f /tmp/telegram-bot-offset

# Remove any other temporary files
rm -f /tmp/telegram-wol-bot*
rm -f /tmp/rate_limit*
```

### Step 6: Optional - Remove Dependencies

**Only do this if you're not using these tools for anything else:**

```bash
# Check what packages are installed
opkg list-installed | grep -E 'curl|jq|etherwake'

# Remove packages (ONLY if you don't need them)
opkg remove curl
opkg remove jq
# Keep etherwake if you use WOL manually

# Check disk space recovered
df -h
```

## Verification

### Confirm Complete Removal

```bash
# 1. Check no service running
ps | grep telegram
# Should return only the grep command itself

# 2. Check no init script
ls -l /etc/init.d/ | grep telegram
# Should return nothing

# 3. Check no bot files
ls -l /root/wol-bot
# Should return "No such file or directory"

# 4. Check no startup links
ls -l /etc/rc.d/ | grep telegram
# Should return nothing

# 5. Check no cron jobs (if you set any)
crontab -l | grep telegram
# Should return nothing
```

## Quick Uninstall Script

If you want to remove everything at once:

```bash
#!/bin/sh
# Quick uninstall script for OpenWRT bot

echo "Stopping telegram-wol-bot service..."
/etc/init.d/telegram-wol-bot stop 2>/dev/null

echo "Disabling telegram-wol-bot service..."
/etc/init.d/telegram-wol-bot disable 2>/dev/null

echo "Removing service files..."
rm -f /etc/init.d/telegram-wol-bot

echo "Removing bot directory..."
rm -rf /root/wol-bot

echo "Removing state files..."
rm -f /tmp/telegram-bot-offset
rm -f /tmp/telegram-wol-bot*
rm -f /tmp/rate_limit*

echo "Uninstall complete!"

# Verify
echo ""
echo "Verification:"
if ps | grep -v grep | grep telegram-wol-bot > /dev/null; then
    echo "❌ Bot is still running"
else
    echo "✓ Bot is not running"
fi

if [ -d "/root/wol-bot" ]; then
    echo "❌ Bot directory still exists"
else
    echo "✓ Bot directory removed"
fi

if [ -f "/etc/init.d/telegram-wol-bot" ]; then
    echo "❌ Init script still exists"
else
    echo "✓ Init script removed"
fi

echo ""
echo "Uninstall complete!"
```

**To use the script:**
```bash
# On OpenWRT router
cat > /tmp/uninstall-wol-bot.sh << 'EOF'
[paste script above]
EOF

chmod +x /tmp/uninstall-wol-bot.sh
/tmp/uninstall-wol-bot.sh
```

## Troubleshooting

### Bot Won't Stop

```bash
# Force kill the process
killall -9 telegram-wol-bot.sh

# Or find and kill by PID
ps | grep telegram-wol-bot
kill -9 <PID>
```

### Files Won't Delete

```bash
# Check if files are in use
lsof | grep wol-bot

# Force remove
rm -rf /root/wol-bot
rm -f /etc/init.d/telegram-wol-bot
```

### Service Still Auto-Starts

```bash
# Remove any symbolic links
find /etc/rc.d/ -name '*telegram*' -delete

# Check startup scripts
grep -r "telegram-wol-bot" /etc/rc.* 2>/dev/null

# Remove from crontab if added
crontab -e
# Delete any lines containing telegram-wol-bot
```

## What Gets Removed

| Item | Location | Size (approx) |
|------|----------|---------------|
| Main script | `/root/wol-bot/telegram-wol-bot.sh` | ~10KB |
| Config file | `/root/wol-bot/config.conf` | ~1KB |
| Init script | `/etc/init.d/telegram-wol-bot` | ~1KB |
| State file | `/tmp/telegram-bot-offset` | <1KB |
| Startup links | `/etc/rc.d/S99telegram-wol-bot` | 0KB (symlink) |
| **Total** | | **~12KB** |

**Dependencies (optional removal):**
- curl: ~200KB
- jq: ~50KB
- etherwake: ~10KB

## After Uninstallation

### If You Migrated to Docker

You're all set! The Docker version is now handling everything.

**Verify Docker bot is working:**
```bash
# On your Docker host
docker-compose ps
docker-compose logs --tail=20
```

**Test in Telegram:**
- Send `/start` to your bot
- Should get welcome message
- Send `/list` to verify devices

### If You're Not Using the Bot Anymore

**Consider revoking the bot token:**
1. Open Telegram
2. Message @BotFather
3. Send `/mybots`
4. Select your bot
5. Go to "API Token"
6. Click "Revoke current token"

This prevents anyone who might have obtained your token from using it.

## Re-Installation

If you need to reinstall the OpenWRT version:

```bash
# 1. Create directory
mkdir -p /root/wol-bot
cd /root/wol-bot

# 2. Copy files back from backup
tar -xzf /root/backups/wol-bot-backup-*.tar.gz

# 3. Install service
cp telegram-wol-bot-init /etc/init.d/telegram-wol-bot
chmod +x /etc/init.d/telegram-wol-bot

# 4. Enable and start
/etc/init.d/telegram-wol-bot enable
/etc/init.d/telegram-wol-bot start
```

## Migration Checklist

If you're migrating to Docker:

- [ ] Backed up OpenWRT configuration
- [ ] Docker version is running and tested
- [ ] All devices work from Docker version
- [ ] Stopped OpenWRT bot service
- [ ] Disabled OpenWRT bot from auto-start
- [ ] Removed OpenWRT bot files
- [ ] Verified Docker bot works for 24 hours
- [ ] Completely removed OpenWRT installation

## Common Issues

### "Device Not Found" Error

If you see this after switching to Docker:
- OpenWRT is removed but Docker version not configured
- Solution: Complete the Docker setup with your devices

### Router Still Trying to Start Bot

```bash
# Check for lingering startup scripts
grep -r "telegram" /etc/init.d/ 2>/dev/null
grep -r "wol-bot" /etc/rc.* 2>/dev/null

# Remove any findings
```

### Need to Quickly Re-enable

If you need the OpenWRT bot back temporarily:

```bash
# If you didn't delete the files yet
/etc/init.d/telegram-wol-bot start

# If you deleted files but have backup
cd /root
tar -xzf backups/wol-bot-backup-*.tar.gz
/etc/init.d/telegram-wol-bot start
```

## Space Recovered

After complete removal:
- Bot files: ~12KB
- If removing dependencies: ~260KB
- Total: ~270KB

Not a lot, but it's good housekeeping!

## Need Help?

If something goes wrong:

1. **Check what's actually installed:**
   ```bash
   find /root -name "*wol*" -o -name "*telegram*"
   find /etc -name "*wol*" -o -name "*telegram*"
   find /tmp -name "*telegram*"
   ```

2. **Force clean everything:**
   ```bash
   killall telegram-wol-bot.sh 2>/dev/null
   rm -rf /root/wol-bot
   rm -f /etc/init.d/telegram-wol-bot
   rm -f /etc/rc.d/*telegram*
   rm -f /tmp/telegram*
   ```

3. **Reboot router (last resort):**
   ```bash
   reboot
   ```

---

**You're now ready to remove the old OpenWRT installation safely!**

Remember: Always backup before deleting, and verify the new system works before removing the old one.