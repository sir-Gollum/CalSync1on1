# CalSync1on1 - macOS Calendar Sync Tool

A Swift command-line tool that automatically synchronizes 1:1 meetings from a work calendar to a personal/home calendar on macOS. The tool identifies meetings with exactly 2 participants (including the calendar owner) and creates corresponding "1:1 with [Person]" events in the destination calendar with intelligent metadata tracking and conflict resolution.

## Overview

This tool helps you share your 1:1 meeting schedule with family members without exposing sensitive work details. It provides intelligent event linking, dry-run capabilities, YAML configuration, and comprehensive error handling.

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
- **Verbose Logging**: Detailed operation logging with colored output
- **Error Recovery**: Comprehensive error handling with helpful messages
- **Command-Line Interface**: Full CLI with help, version, and configuration options

### Smart Event Management
- **Metadata Tracking**: JSON metadata embedded in event notes for reliable linking
- **Update Detection**: Automatically updates existing events when source changes
- **Conflict Resolution**: Handles calendar conflicts gracefully
- **Recurring Event Support**: Complete handling of recurring 1:1 meeting series

## 🔧 Requirements

- **macOS 13.0+** (Sonoma or later recommended)
- **Xcode or Swift command-line tools**
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
    account: null              # Optional: specify account
    calendar: "Calendar"       # Your work calendar name
  destination:
    account: null              # Optional: specify account
    calendar: "Personal"       # Your personal calendar name
  title_template: "1:1 with {{otherPerson}}"
  owner_email: "john.doe@company.com"  # Optional: your email for better 1:1 detection

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

# Enable verbose logging
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
| `--verbose` | Enable detailed logging |
| `--help`, `-h` | Show help message |
| `--version` | Show version information |

## 📊 Example Output

### Dry-Run Mode
```
📅 CalSync1on1 - Syncing 1:1 meetings from work to personal calendar
🔍 DRY RUN MODE - No changes will be made

🔐 Checking calendar permissions...
✅ Calendar access granted

📋 All available calendars:
   • Work Calendar (Exchange) - CalDAV, writable
   • Personal Calendar (iCloud) - CalDAV, writable
   • Holidays (iCloud) - Subscription, read-only
   • Birthdays (Local) - Birthday, read-only

📋 Calendar Configuration:
   Source: Work Calendar
   Destination: Personal Calendar

🔍 Finding calendars...
✅ Found source calendar: Work Calendar (Exchange)
✅ Found destination calendar: Personal Calendar (iCloud)

📅 Sync window: 2 weeks
   From: Monday, December 18, 2023
   To: Monday, January 1, 2024

📥 Fetching events from source calendar...
📊 Found 25 total events in source calendar

🔍 Detailed event analysis:
   • Weekly Team Standup - 3 attendees
     Attendees: John Doe <john.doe@company.com>, Jane Smith <jane.smith@company.com>, Bob Wilson <bob@company.com>
     Time: 12/18/23, 9:00 AM

   • 1:1 with Sarah - 2 attendees
     Attendees: John Doe <john.doe@company.com>, Sarah Johnson <sarah@company.com>
     Time: 12/19/23, 2:00 PM

📊 15 events after applying filters

🔍 Analyzing events for 1:1 meetings...
   Using calendar owner identifier: 'john.doe@company.com'
📊 Found 8 1:1 meetings

   1:1 meetings found:
   • 1:1 with Sarah Johnson at 12/19/23, 2:00 PM
   • 1:1 with Mike Chen at 12/21/23, 3:00 PM (recurring)
   • 1:1 with Lisa Wang at 12/22/23, 10:00 AM

🔄 Starting synchronization...
➕ Would create: '1:1 with Sarah Johnson' at 12/19/23, 2:00 PM
➕ Would create recurring series: '1:1 with Mike Chen' starting 12/21/23, 3:00 PM
📝 Would update: '1:1 with Lisa Wang' at 12/22/23, 10:00 AM
🗑️  Would delete orphaned: '1:1 with Former Colleague'

==================================================
🔍 DRY RUN SUMMARY
==================================================
📋 Changes that would be made:
  ➕ Created: 3
  📝 Updated: 2
  🗑️  Deleted: 1
  ⏭️  Skipped: 2

📈 Total events processed: 8

💡 Run without --dry-run to apply these changes
==================================================
```

### Normal Sync Output
```
📅 CalSync1on1 - Syncing 1:1 meetings from work to personal calendar

✅ Calendar access granted
✅ Found source calendar: Calendar (Exchange)
✅ Found destination calendar: Personal (iCloud)

📊 Found 8 1:1 meetings

🔄 Starting synchronization...
➕ Would create: '1:1 with John Smith' at 12/19/23, 2:00 PM
➕ Would create recurring series: '1:1 with Sarah Johnson' starting 12/20/23, 10:00 AM
📝 Would update: '1:1 with Mike Chen' at 12/21/23, 3:00 PM
🗑️  Would delete orphaned: '1:1 with Former Colleague'

==================================================
📊 SYNC SUMMARY
==================================================
📋 Changes made:
  ➕ Created: 3
  📝 Updated: 2
  🗑️  Deleted: 1
  ⏭️  Skipped: 2

📈 Total events processed: 8
==================================================

🎉 Synchronization completed successfully!
```

## 🔍 How It Works

1. **Permission Check**: Requests access to your calendars
2. **Configuration Loading**: Loads settings from YAML config file
3. **Calendar Discovery**: Finds source and destination calendars by name
4. **Date Range Calculation**: Determines sync window based on configuration
6. **Event Fetching**: Retrieves events from source calendar in date range
7. **Filtering**: Applies configured filters (all-day, keywords, privacy)
8. **1:1 Analysis**: Identifies meetings with exactly 2 attendees including owner
9. **Recurring Event Detection**: Analyzes recurring 1:1 meeting series
10. **Smart Synchronization**:
    - Creates new synced events with metadata
    - Handles recurring event series properly
    - Updates existing events when source changes
    - Deletes orphaned events when source no longer exists
    - Skips unchanged events to avoid unnecessary updates
11. **Summary Report**: Shows detailed results of sync operation

## 🎛️ Advanced Configuration

### Custom Title Templates & Owner Email
```yaml
calendar_pair:
  name: "Work to Personal"
  source:
    calendar: "Work Calendar"
  destination:
    calendar: "Personal"
  title_template: "Meeting with {{otherPerson}}"  # Custom format
  owner_email: "your.email@company.com"           # For better 1:1 detection
```

### Improved 1:1 Meeting Detection

The `owner_email` configuration helps the tool accurately identify which attendee is you:

```yaml
calendar_pair:
  owner_email: "john.doe@company.com"  # Your actual email address
```

**Why this matters:**
- Calendar source titles don't always match your email address
- More accurate matching against meeting attendees
- Better detection of 1:1 meetings vs. group meetings
- Fallback: Uses calendar source title if not specified

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
```

## 🔧 Development

### Building
```bash
make build          # Release build
make debug          # Debug build
make clean          # Clean build artifacts
```

### Testing
```bash
make test           # Run all tests
swift test          # Direct test execution
swift test --parallel  # Parallel test execution
```

### Project Structure
```
CalSync1on1/
├── Package.swift                    # Swift package manifest
├── Makefile                        # Build automation
├── setup-config.sh                 # Configuration setup script
├── Sources/CalSync1on1/
│   ├── main.swift                  # CLI entry point
│   ├── Configuration.swift         # YAML config management
│   ├── CalendarManager.swift       # EventKit operations
│   ├── MeetingAnalyzer.swift      # 1:1 meeting detection
│   ├── SyncManager.swift          # Event synchronization
│   ├── EventMetadata.swift        # Metadata tracking
│   ├── DateHelper.swift           # Date utilities
│   └── Models/
│       └── SyncedEvent.swift      # Data models
├── Tests/CalSync1on1Tests/         # Unit tests
├── Resources/
│   └── default-config.yaml        # Default configuration
└── README.md
```

## 🚨 Troubleshooting

### Common Issues

**"Calendar access denied"**
- Grant permission in System Preferences > Privacy & Security > Calendars
- Restart the application after granting permission

**"Could not find calendar named 'X'"**
- Check calendar names in your Calendar app
- Run setup script again: `./setup-config.sh`
- List available calendars: the tool will show them in error messages

**"No 1:1 meetings found"**
- Verify your work calendar has meetings with exactly 2 attendees
- Check that you're included as one of the attendees
- Configure `owner_email` in your config for better detection
- Use `--verbose` flag to see detailed analysis including:
  - All available calendars with their types
  - Event details with attendee information
  - Calendar owner identifier being used
  - Why specific events aren't detected as 1:1

**Configuration not loading**
- Verify file exists: `~/.config/calsync1on1/config.yaml`
- Check YAML syntax with online validator
- Run setup script to recreate: `./setup-config.sh`

### Debug Mode

```bash
# Enable maximum verbosity - shows all calendars and detailed event analysis
calsync1on1 --verbose --dry-run

# Check configuration loading and calendar detection
calsync1on1 --config /path/to/config.yaml --verbose --dry-run

# See why events aren't detected as 1:1 meetings
calsync1on1 --verbose --dry-run | grep -A5 "has 2 attendees but not detected"
```

**Verbose mode shows:**
- All available calendars with account types and permissions
- Detailed event information including all attendees
- Calendar owner identifier being used for matching
- Why events with 2 attendees aren't detected as 1:1
- Step-by-step analysis of the sync process

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
