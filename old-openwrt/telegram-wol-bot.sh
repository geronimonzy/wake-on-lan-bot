#!/bin/sh
# Telegram Wake-on-LAN Bot for OpenWRT
# Author: Custom Script
# Description: Receives Telegram commands and sends WOL packets

# Configuration file path
CONFIG_FILE="/root/wol-bot/config.conf"
STATE_FILE="/tmp/telegram-bot-offset"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

# Source the config file
. "$CONFIG_FILE"

# Check for required commands
for cmd in curl jq etherwake; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: Required command '$cmd' not found. Please install it."
        exit 1
    fi
done

# Telegram API URLs
API_URL="https://api.telegram.org/bot${BOT_TOKEN}"

# Function to get device MAC address
get_device_mac() {
    local device_key="$1"
    eval echo "\$DEVICE_${device_key}_MAC"
}

# Function to get device name
get_device_name() {
    local device_key="$1"
    eval echo "\$DEVICE_${device_key}_NAME"
}

# Function to get device interface
get_device_interface() {
    local device_key="$1"
    local interface
    eval interface="\$DEVICE_${device_key}_INTERFACE"
    echo "${interface:-$DEFAULT_INTERFACE}"
}

# Function to check if user is authorized
is_authorized() {
    local user_id="$1"
    for authorized_id in $AUTHORIZED_USERS; do
        if [ "$authorized_id" = "$user_id" ]; then
            return 0
        fi
    done
    return 1
}

# Function to send Telegram message
send_message() {
    local chat_id="$1"
    local text="$2"
    local parse_mode="${3:-}"
    
    local json_payload
    if [ -n "$parse_mode" ]; then
        json_payload=$(jq -n \
            --arg chat_id "$chat_id" \
            --arg text "$text" \
            --arg parse_mode "$parse_mode" \
            '{chat_id: $chat_id, text: $text, parse_mode: $parse_mode}')
    else
        json_payload=$(jq -n \
            --arg chat_id "$chat_id" \
            --arg text "$text" \
            '{chat_id: $chat_id, text: $text}')
    fi
    
    curl -s -X POST "$API_URL/sendMessage" \
        -H "Content-Type: application/json" \
        -d "$json_payload" >/dev/null 2>&1
}

# Function to send Wake-on-LAN packet
send_wol() {
    local mac="$1"
    local interface="$2"
    
    if [ -n "$interface" ]; then
        etherwake -i "$interface" "$mac" >/dev/null 2>&1
    else
        etherwake "$mac" >/dev/null 2>&1
    fi
    
    return $?
}

# Function to list all devices
list_devices() {
    local output="📋 *Available Devices:*\n\n"
    local device_found=0
    
    # Iterate through all DEVICE_ variables
    for var in $(set | grep '^DEVICE_.*_NAME=' | cut -d= -f1); do
        device_found=1
        local key=$(echo "$var" | sed 's/DEVICE_//;s/_NAME//')
        local name=$(get_device_name "$key")
        local mac=$(get_device_mac "$key")
        output="${output}🖥️ *${key}* - ${name}\n   MAC: \`${mac}\`\n\n"
    done
    
    if [ $device_found -eq 0 ]; then
        output="❌ No devices configured."
    else
        output="${output}💡 *Usage:* /wake <device_key>"
    fi
    
    echo "$output"
}

# Function to handle /wake command
handle_wake_command() {
    local chat_id="$1"
    local user_id="$2"
    local device_key="$3"
    
    # Check authorization
    if ! is_authorized "$user_id"; then
        send_message "$chat_id" "❌ Unauthorized. Access denied."
        echo "Unauthorized access attempt from user ID: $user_id"
        return
    fi
    
    # Check if device key provided
    if [ -z "$device_key" ]; then
        send_message "$chat_id" "⚠️ Please specify a device.\nExample: /wake pc\n\nUse /list to see available devices."
        return
    fi
    
    # Convert to uppercase for consistency
    device_key=$(echo "$device_key" | tr '[:lower:]' '[:upper:]')
    
    # Get device information
    local mac=$(get_device_mac "$device_key")
    local name=$(get_device_name "$device_key")
    local interface=$(get_device_interface "$device_key")
    
    if [ -z "$mac" ]; then
        send_message "$chat_id" "❌ Device '$device_key' not found.\n\nUse /list to see available devices."
        return
    fi
    
    # Send WOL packet
    echo "Sending WOL to $name ($mac) on interface $interface"
    if send_wol "$mac" "$interface"; then
        send_message "$chat_id" "✅ Wake-on-LAN packet sent to *${name}*\n\nDevice: \`${device_key}\`\nMAC: \`${mac}\`\nInterface: \`${interface}\`" "Markdown"
        echo "WOL packet sent successfully to $name"
    else
        send_message "$chat_id" "❌ Failed to send WOL packet to ${name}."
        echo "Failed to send WOL packet to $name"
    fi
}

# Function to handle /list command
handle_list_command() {
    local chat_id="$1"
    local user_id="$2"
    
    # Check authorization
    if ! is_authorized "$user_id"; then
        send_message "$chat_id" "❌ Unauthorized. Access denied."
        return
    fi
    
    local device_list=$(list_devices)
    send_message "$chat_id" "$device_list" "Markdown"
}

# Function to handle /start command
handle_start_command() {
    local chat_id="$1"
    local user_id="$2"
    
    # Check authorization
    if ! is_authorized "$user_id"; then
        send_message "$chat_id" "❌ Unauthorized. Your user ID: $user_id"
        return
    fi
    
    local welcome_msg="🤖 *Wake-on-LAN Bot*\n\n"
    welcome_msg="${welcome_msg}Welcome! I can wake up devices on your network.\n\n"
    welcome_msg="${welcome_msg}*Commands:*\n"
    welcome_msg="${welcome_msg}/wake <device> - Wake up a device\n"
    welcome_msg="${welcome_msg}/list - Show all devices\n"
    welcome_msg="${welcome_msg}/status - Bot status\n"
    welcome_msg="${welcome_msg}/help - Show this message"
    
    send_message "$chat_id" "$welcome_msg" "Markdown"
}

# Function to handle /status command
handle_status_command() {
    local chat_id="$1"
    local user_id="$2"
    
    if ! is_authorized "$user_id"; then
        send_message "$chat_id" "❌ Unauthorized."
        return
    fi
    
    local uptime=$(uptime | awk '{print $3, $4}' | sed 's/,//')
    local load=$(uptime | awk -F'load average:' '{print $2}')
    local mem_info=$(free | grep Mem | awk '{printf "%.1f%%", ($3/$2) * 100}')
    
    local status_msg="📊 *Bot Status*\n\n"
    status_msg="${status_msg}✅ Bot is running\n"
    status_msg="${status_msg}⏱ Router uptime: ${uptime}\n"
    status_msg="${status_msg}📈 Load average:${load}\n"
    status_msg="${status_msg}💾 Memory usage: ${mem_info}"
    
    send_message "$chat_id" "$status_msg" "Markdown"
}

# Function to process incoming messages
process_message() {
    local update="$1"
    
    # Extract message details
    local message_id=$(echo "$update" | jq -r '.message.message_id // .edited_message.message_id // empty')
    local chat_id=$(echo "$update" | jq -r '.message.chat.id // .edited_message.chat.id // empty')
    local user_id=$(echo "$update" | jq -r '.message.from.id // .edited_message.from.id // empty')
    local text=$(echo "$update" | jq -r '.message.text // .edited_message.text // empty')
    local username=$(echo "$update" | jq -r '.message.from.username // .edited_message.from.username // "unknown"')
    
    # Skip if no valid message
    if [ -z "$chat_id" ] || [ -z "$text" ] || [ "$text" = "null" ]; then
        return
    fi
    
    echo "Received message from @$username (ID: $user_id): $text"
    
    # Parse command and arguments
    local command=$(echo "$text" | awk '{print $1}')
    local arg1=$(echo "$text" | awk '{print $2}')
    
    # Handle commands
    case "$command" in
        /start|/help)
            handle_start_command "$chat_id" "$user_id"
            ;;
        /wake)
            handle_wake_command "$chat_id" "$user_id" "$arg1"
            ;;
        /list)
            handle_list_command "$chat_id" "$user_id"
            ;;
        /status)
            handle_status_command "$chat_id" "$user_id"
            ;;
        *)
            if is_authorized "$user_id"; then
                send_message "$chat_id" "❓ Unknown command. Use /help for available commands."
            fi
            ;;
    esac
}

# Function to get updates from Telegram
get_updates() {
    local offset="${1:-0}"
    local timeout="${2:-30}"
    
    curl -s -X GET "$API_URL/getUpdates" \
        -d "offset=$offset" \
        -d "timeout=$timeout" \
        -d "allowed_updates=[\"message\",\"edited_message\"]"
}

# Main bot loop
main() {
    echo "Starting Telegram WOL Bot..."
    echo "Bot token configured: ${BOT_TOKEN:0:10}..."
    echo "Authorized users: $AUTHORIZED_USERS"
    
    # Load last offset
    local offset=0
    if [ -f "$STATE_FILE" ]; then
        offset=$(cat "$STATE_FILE")
    fi
    
    echo "Bot is running. Press Ctrl+C to stop."
    
    while true; do
        # Get updates from Telegram
        response=$(get_updates "$offset" 30)
        
        # Check if response is valid JSON
        if ! echo "$response" | jq empty 2>/dev/null; then
            echo "Invalid response from Telegram API. Retrying..."
            sleep 5
            continue
        fi
        
        # Check if there are any updates
        local result_count=$(echo "$response" | jq '.result | length')
        
        if [ "$result_count" -gt 0 ]; then
            # Process each update
            echo "$response" | jq -c '.result[]' | while read -r update; do
                # Get update_id for offset
                local update_id=$(echo "$update" | jq -r '.update_id')
                
                # Process the message
                process_message "$update"
                
                # Update offset
                offset=$((update_id + 1))
                echo "$offset" > "$STATE_FILE"
            done
            
            # Update offset after processing all messages
            offset=$(cat "$STATE_FILE")
        fi
        
        # Small delay to prevent tight loop on errors
        sleep 1
    done
}

# Handle script termination
trap 'echo "Bot stopped."; exit 0' INT TERM

# Start the bot
main
