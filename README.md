# CalSync1on1 - macOS Calendar Sync Tool

A Swift command-line tool that automatically synchronizes 1:1 meetings from a work calendar to a personal/home calendar on macOS. The tool identifies meetings with exactly 2 participants (including the calendar owner) and creates corresponding "1:1 with [Person]" events in the destination calendar with intelligent metadata tracking and conflict resolution.

## Overview

This tool helps you share your 1:1 meeting schedule with family members without exposing sensitive work details. It provides intelligent event linking, dry-run capabilities, YAML configuration, and comprehensive debugging features.

## ✨ Features

### Core Functionality
- **Smart 1:1 Detection**: Identifies meetings with exactly 2 attendees (including calendar owner)
- **Configurable Sync Window**: Sync current week + configurable future weeks
- **Intelligent Event Linking**: Uses metadata for reliable event tracking and updates
- **Duplicate Prevention**: Avoids creating duplicate events with smart comparison
- **Orphan Cleanup**: Automatically removes synced events when source meetings are deleted or modified
- **Template-Based Titles**: Customizable event title formats (e.g., "1:1 with [Person]")

### Advanced Features
- **YAML Configuration**: Flexible configuration with single calendar pair setup
- **Dry-Run Mode**: Preview changes before applying them
- **Event Filtering**: Skip all-day events, exclude keywords, filter by privacy
- **Comprehensive Logging**: Detailed operation logging with configurable verbosity
- **Error Recovery**: Comprehensive error handling with helpful messages
- **Command-Line Interface**: Full CLI with help, version, and configuration options

### Smart Event Management
- **Metadata Tracking**: JSON metadata embedded in event notes for reliable linking
- **Update Detection**: Automatically updates existing events when source changes
- **Conflict Resolution**: Handles calendar conflicts gracefully
- **Recurring Event Support**: Complete handling of recurring 1:1 meeting series

## 🔧 Requirements

- **macOS 13.0+** (Ventura or later)
- **Swift 5.8+** and Xcode command-line tools
- **Calendar app** with configured work and personal calendars
- **Calendar permissions** (will prompt on first run)

## 🚀 Installation & Setup

### Quick Installation

1. **Clone and build:**
```bash
git clone <repository-url>
cd CalSync1on1
make build
```

2. **Install system-wide (optional):**
```bash
make install
```

3. **Set up configuration:**
```bash
make setup
# or directly:
./setup-config.sh
```

### Manual Setup

1. **Build the project:**
```bash
swift build -c release
```

2. **The executable will be at:**
```
.build/release/calsync1on1
```

3. **Create configuration directory:**
```bash
mkdir -p ~/.config/calsync1on1
```

## ⚙️ Configuration

### Automatic Configuration Setup

Run the interactive setup script:
```bash
make setup
# or
./setup-config.sh
```

This will guide you through creating a configuration file with your calendar names, sync preferences, and filtering rules.

### Manual Configuration

Create `~/.config/calsync1on1/config.yaml`:

```yaml
version: "1.0"

calendar_pair:
  name: "Work to Personal"
  source:
    account: "work@company.com"      # Optional: specify account
    calendar: "Work Calendar"        # Your work calendar name (exact match required)
  destination:
    account: "personal@gmail.com"    # Optional: specify account
    calendar: "Personal Calendar"    # Your personal calendar name (exact match required)
  title_template: "1:1 with {{otherPerson}}"
  # CRITICAL: Set your actual email address for accurate 1:1 detection
  owner_email: "john.doe@company.com"

sync_window:
  weeks: 2                      # Sync current + next week
  start_offset: 0               # Start from current week

filters:
  exclude_all_day: true         # Skip all-day events
  exclude_keywords:             # Skip events with these keywords
    - "standup"
    - "all-hands"
    - "team meeting"

logging:
  level: "info"                 # error, warn, info, debug
  colored_output: true
```

## 🎯 Usage

### Basic Commands

```bash
# Preview changes (recommended first run)
calsync1on1 --dry-run

# Run synchronization
calsync1on1

# Use custom configuration
calsync1on1 --config /path/to/config.yaml

# Enable verbose debugging (shows all event details)
calsync1on1 --verbose --dry-run

# Show help
calsync1on1 --help

# Show version
calsync1on1 --version
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `--config PATH` | Path to configuration file |
| `--dry-run` | Preview changes without applying |
| `--verbose` | Enable comprehensive debugging output |
| `--help`, `-h` | Show help message |
| `--version` | Show version information |

## 📊 Example Output

### Verbose Debug Mode
```
📅 CalSync1on1 - Syncing 1:1 meetings
🔍 DRY RUN MODE

	🔐 Checking calendar permissions...
✅ Calendar access granted

	🔍 Finding calendars...
📋 Available calendars:
   • Work Calendar (Exchange) - CalDAV, writable
   • Personal Calendar (iCloud) - CalDAV, writable
   • Holidays (iCloud) - Subscription, read-only
   • Birthdays (Local) - Birthday, read-only

✅ Source: Work Calendar
✅ Destination: Personal Calendar
📅 Sync window: Monday, December 18, 2023 to Monday, January 8, 2024

	📥 Fetching events...
Found 25 total events

🔍 Comprehensive Event Analysis:
   • Weekly Team Standup - 3 attendees
     └─ Attendees: john.doe@company.com, jane.smith@company.com, bob@company.com
     └─ Time: 12/18/23, 9:00 AM
     └─ Not 1:1: More than 2 attendees

   • 1:1 with Sarah - 2 attendees
     └─ Attendees: john.doe@company.com, sarah@company.com
     └─ Time: 12/19/23, 2:00 PM
     └─ ✅ Detected as 1:1 meeting

📊 8 events left after filtering
📊 Found 3 1:1 meetings

	🔄 Synchronizing...
➕ Would create: '1:1 with Sarah Johnson' at 12/19/23, 2:00 PM
📝 Would update: '1:1 with Mike Chen' at 12/21/23, 3:00 PM
🗑️  Would delete orphaned: '1:1 with Former Colleague'

==================================================
🔍 DRY RUN SUMMARY
==================================================
📋 Changes that would be made:
  ➕ Created: 2
  📝 Updated: 1
  🗑️  Deleted: 1
  ⏭️  Skipped: 0

📈 Total events processed: 3

💡 Run without --dry-run to apply changes
==================================================
```

### Normal Sync Output
```
📅 CalSync1on1 - Syncing 1:1 meetings

✅ Calendar access granted
✅ Source: Work Calendar
✅ Destination: Personal Calendar
📊 Found 3 1:1 meetings

	🔄 Synchronizing...
➕ Created: '1:1 with Sarah Johnson' at 12/19/23, 2:00 PM
📝 Updated: '1:1 with Mike Chen' at 12/21/23, 3:00 PM

==================================================
📊 SYNC SUMMARY
==================================================
📋 Changes made:
  ➕ Created: 1
  📝 Updated: 1
  🗑️  Deleted: 0
  ⏭️  Skipped: 1

📈 Total events processed: 3
==================================================

	🎉 Sync completed!
```

## 🔍 How It Works

1. **Permission Check**: Requests access to your calendars via EventKit
2. **Configuration Loading**: Loads settings from YAML config file
3. **Calendar Discovery**: Finds source and destination calendars by exact name match
4. **Date Range Calculation**: Determines sync window based on configuration
5. **Event Fetching**: Retrieves events from source calendar in date range
6. **Event Filtering**: Applies configured filters (all-day, keywords, privacy)
7. **1:1 Analysis**: Identifies meetings with exactly 2 attendees including owner
8. **Smart Synchronization**:
   - Creates new synced events with embedded metadata for tracking
   - Updates existing events when source changes (using metadata linking)
   - Deletes orphaned events when source no longer exists or changes
   - Skips unchanged events to avoid unnecessary calendar updates
9. **Summary Report**: Shows detailed results of sync operation

## 🎛️ Advanced Configuration

### Critical: Owner Email Configuration
```yaml
calendar_pair:
  # This is CRITICAL for accurate 1:1 detection
  owner_email: "your.actual.email@company.com"  # Must match your email in meeting attendees
```

**Why `owner_email` is important:**
- Calendar source titles don't always match your email address
- Some calendars show generic names instead of your actual email
- More accurate matching against meeting attendees
- Better detection of 1:1 meetings vs. group meetings
- **Run `--verbose` to see what email addresses appear in your events**

### Advanced Filtering
```yaml
filters:
  exclude_all_day: true
  exclude_keywords:
    - "standup"
    - "daily"
    - "scrum"
    - "retrospective"
    - "all-hands"
    - "team meeting"
    - "planning"
    - "review"
    - "sync"
    - "check-in"
```

### Wider Sync Window for Testing
```yaml
sync_window:
  weeks: 4                    # Look ahead 4 weeks
  start_offset: -1            # Start from last week (for testing)
```

## 🔧 Development

### Building & Testing
```bash
make help           # Show all available commands
make install-deps   # Install development dependencies (linters, formatters, test tools)
make build          # Release build
make debug          # Debug build
make test           # Run tests
make lint           # Run code linting
make format         # Run code formatting
make clean          # Clean build artifacts
make check          # Comprehensive validation
```

### Project Structure
```
CalSync1on1/
├── Sources/CalSync1on1/
│   ├── CalendarManager.swift            # EventKit calendar operations
│   ├── Configuration.swift              # YAML config management & validation
│   ├── DateHelper.swift                 # Date range utilities
│   ├── DebugHelper.swift                # Comprehensive debugging utilities
│   ├── EventFilter.swift                # Event filtering logic
│   ├── EventMetadata.swift              # Metadata tracking for event linking
│   ├── Logger.swift                     # Logging system with verbosity levels
│   ├── main.swift                       # CLI entry point and main logic
│   ├── MeetingAnalyzer.swift            # 1:1 meeting detection logic
│   └── SyncManager.swift                # Event synchronization engine
├── Tests/CalSync1on1Tests/              # Comprehensive unit tests
└── README.md
├── example-config.yaml                  # Example configuration file
├── Makefile                             # Build automation
├── Package.swift                        # Swift package manifest
└── setup-config.sh                      # Interactive configuration setup
```

## 🚨 Troubleshooting

### Common Issues

**"Calendar access denied"**
- Grant permission in System Settings > Privacy & Security > Calendars
- Restart the application after granting permission

**"Could not find calendar named 'X'"**
- Calendar names must match EXACTLY (case-sensitive)
- Run `calsync1on1 --verbose --dry-run` to see all available calendar names
- Run setup script again: `make setup`

**"No 1:1 meetings found" - Most Common Issue**
- **CRITICAL**: Set `owner_email` in your config to your actual email address
- Run `--verbose` to see all event details and attendee information
- Look for "events with 2 attendees NOT detected as 1:1" in verbose output
- Check that you're included as one of the attendees in the meetings
- Verify your work calendar actually has meetings with exactly 2 people

**Events being filtered out**
- Set `exclude_all_day: false` if your 1:1s are all-day events
- Remove or adjust `exclude_keywords` that might match your meetings
- Use `--verbose` to see exactly why events are filtered

### Debug Mode - Your Best Friend

```bash
# ALWAYS start with this for troubleshooting
calsync1on1 --verbose --dry-run
```

**Verbose mode reveals:**
- All available calendars with their exact names and types
- Complete event details including all attendees and organizers
- Calendar owner identifier being used for 1:1 detection
- Step-by-step analysis of why events are/aren't detected as 1:1
- Detailed filter application results
- Diagnostic recommendations for common issues

### Debugging No 1:1 Meetings Found

1. **Check owner email matching:**
```bash
# Look for lines like:
# "Using owner identifier: 'john.doe@company.com'"
# "Event has 2 attendees but owner not found in: [attendee1, attendee2]"
```

2. **Verify calendar names:**
```bash
# Look for the "Available calendars:" section
# Use exact names shown there in your config
```

3. **Check date range:**
```bash
# Widen the sync window temporarily for testing:
# weeks: 4, start_offset: -1
```

## 📚 Automation

### Run with Launchd (macOS)

Create `~/Library/LaunchAgents/com.calsync1on1.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.calsync1on1</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/calsync1on1</string>
    </array>
    <key>StartInterval</key>
    <integer>1800</integer>  <!-- Run every 30 minutes -->
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

Load the job:
```bash
launchctl load ~/Library/LaunchAgents/com.calsync1on1.plist
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Run tests: `make test`
4. Commit your changes: `git commit -m 'Add amazing feature'`
5. Push to the branch: `git push origin feature/amazing-feature`
6. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with Swift and EventKit framework
- YAML configuration powered by [Yams](https://github.com/jpsim/Yams)
- Inspired by the need to share work schedules with family while maintaining privacy

---

**Made with ❤️ for macOS users who want to share their 1:1 schedule with family**
