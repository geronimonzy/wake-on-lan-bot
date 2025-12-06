# Multi-stage build for security and minimal size
FROM alpine:3.19 AS builder

# Install build dependencies
RUN apk add --no-cache \
    curl \
    jq

# Final stage
FROM alpine:3.19

LABEL maintainer="Telegram WOL Bot" \
      description="Secure Telegram Wake-on-LAN Bot" \
      version="2.0.0"

# Install runtime dependencies
RUN apk update && \
    apk add --no-cache \
    curl \
    jq \
    bash \
    perl \
    && rm -rf /var/cache/apk/*

# Install wakeonlan (Perl script - widely available)
RUN curl -L https://raw.githubusercontent.com/jpoliv/wakeonlan/master/wakeonlan \
    -o /usr/local/bin/wakeonlan && \
    chmod +x /usr/local/bin/wakeonlan

# Create non-root user and group
RUN addgroup -g 1000 wolbot && \
    adduser -D -u 1000 -G wolbot wolbot

# Create app directory
WORKDIR /app

# Copy application files
COPY --chown=wolbot:wolbot bot.sh /app/bot.sh
COPY --chown=wolbot:wolbot devices.conf /app/devices.conf

# Make script executable
RUN chmod 500 /app/bot.sh && \
    chmod 400 /app/devices.conf

# Create state directory
RUN mkdir -p /app/state && \
    chown wolbot:wolbot /app/state && \
    chmod 700 /app/state

# Switch to non-root user
USER wolbot

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD pgrep -f bot.sh > /dev/null || exit 1

# No ports exposed - bot only makes outbound connections

# Run the bot
CMD ["/bin/bash", "/app/bot.sh"]
