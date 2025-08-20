#!/bin/bash

# CalSync1on1 Configuration Setup Script
# This script helps you create an initial configuration file for CalSync1on1

set -e

CONFIG_DIR="$HOME/.config/calsync1on1"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

echo "📅 CalSync1on1 Configuration Setup"
echo "=================================="
echo ""

# Create config directory if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    echo "📁 Creating configuration directory: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
fi

# Check if config file already exists
if [ -f "$CONFIG_FILE" ]; then
    echo "⚠️  Configuration file already exists at: $CONFIG_FILE"
    echo ""
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "✅ Keeping existing configuration file"
        echo "   You can view it with: cat $CONFIG_FILE"
        echo "   Or edit it with: nano $CONFIG_FILE"
        exit 0
    fi
fi

# Interactive configuration setup
echo "🔧 Let's configure your calendar sync settings"
echo ""

# Source calendar
echo "📥 Source Calendar (Work Calendar)"
read -p "Enter the name of your work calendar [Calendar]: " SOURCE_CALENDAR
SOURCE_CALENDAR=${SOURCE_CALENDAR:-"Calendar"}

# Destination calendar
echo ""
echo "📤 Destination Calendar (Personal Calendar)"
read -p "Enter the name of your personal calendar [Personal]: " DEST_CALENDAR
DEST_CALENDAR=${DEST_CALENDAR:-"Personal"}

# Title template
echo ""
echo "📝 Event Title Template"
echo "   Use {{otherPerson}} as placeholder for the other person's name"
read -p "Enter title template [1:1 with {{otherPerson}}]: " TITLE_TEMPLATE
TITLE_TEMPLATE=${TITLE_TEMPLATE:-"1:1 with {{otherPerson}}"}

# Sync window
echo ""
echo "📅 Sync Window"
read -p "How many weeks to sync (including current week) [2]: " SYNC_WEEKS
SYNC_WEEKS=${SYNC_WEEKS:-2}

# Excluded keywords
echo ""
echo "🚫 Excluded Keywords (comma-separated)"
echo "   Events containing these words will be skipped"
read -p "Enter keywords to exclude [standup,all-hands,team meeting]: " EXCLUDE_KEYWORDS
EXCLUDE_KEYWORDS=${EXCLUDE_KEYWORDS:-"standup,all-hands,team meeting"}

# Convert comma-separated keywords to YAML array format
IFS=',' read -ra KEYWORDS_ARRAY <<< "$EXCLUDE_KEYWORDS"
YAML_KEYWORDS=""
for keyword in "${KEYWORDS_ARRAY[@]}"; do
    trimmed=$(echo "$keyword" | xargs)  # Trim whitespace
    if [ -n "$trimmed" ]; then
        YAML_KEYWORDS="$YAML_KEYWORDS    - \"$trimmed\"\n"
    fi
done

# Create configuration file
echo ""
echo "📝 Creating configuration file..."

cat > "$CONFIG_FILE" << EOF
# CalSync1on1 Configuration
# Generated on $(date)
version: "1.0"

# Calendar pair defines which calendars to sync between
calendar_pair:
  name: "Work to Personal"
  source:
    account: null              # Optional: specify account if multiple accounts
    calendar: "$SOURCE_CALENDAR"
  destination:
    account: null              # Optional: specify account if multiple accounts
    calendar: "$DEST_CALENDAR"
  title_template: "$TITLE_TEMPLATE"

# Sync window configuration
sync_window:
  weeks: $SYNC_WEEKS          # Number of weeks to sync (current + future weeks)
  start_offset: 0   # Week offset from current week (0 = current week, -1 = previous week)

# Event filtering rules
filters:
  exclude_all_day: true         # Skip all-day events
  exclude_private: true         # Skip private events
  exclude_keywords:             # Skip events containing these keywords (case-insensitive)
$(echo -e "$YAML_KEYWORDS")
# Recurring event handling
recurring_events:
  sync_series: true             # Sync entire recurring series
  handle_exceptions: true       # Handle single instance changes in recurring series

# Logging configuration
logging:
  level: "info"                 # Log levels: error, warn, info, debug
  colored_output: true          # Enable colored console output
EOF

echo "✅ Configuration file created successfully!"
echo ""
echo "📍 Configuration file location: $CONFIG_FILE"
echo ""
echo "🔍 Next steps:"
echo "   1. Make sure you have calendars named '$SOURCE_CALENDAR' and '$DEST_CALENDAR' in your Calendar app"
echo "   2. Test the configuration with: calsync1on1 --dry-run"
echo "   3. If everything looks good, run: calsync1on1"
echo ""
echo "📚 For more options, run: calsync1on1 --help"
echo ""
echo "🛠️  You can edit the configuration file at any time with:"
echo "   nano $CONFIG_FILE"
echo ""
echo "🎉 Setup complete!"
