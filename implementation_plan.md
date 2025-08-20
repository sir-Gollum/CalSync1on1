# macOS Calendar 1:1 Meeting Sync Tool - Project Specification

## Project Idea

We are starting a new project / CLI program. It will run on a mac laptop and work with mac calendars. The use case is that I want my 1/1 meetings from a work calendar be visible in my private calendar which I have shared with folks at home. So the program will list events in a given calendar for the current week and the next one, and look for events with 2 participants, one of which is the owner of that calendar - this way it will figure one on one meetings. After these 1/1 meetings are known, the program will put events like "1/1 with ABC" to the second calendar (the home calendar). The program needs to check if any changes are necessary, and not make calendar changes if everything is up to date.

## Project Overview

Build a Swift command-line tool that automatically synchronizes 1:1 meetings from a work calendar to a personal/home calendar on macOS. The tool identifies meetings with exactly 2 participants (including the calendar owner) and creates corresponding "1:1 with [Person]" events in the destination calendar.

## Technical Requirements

- **Platform**: macOS 14.0+ (Sonoma or later)
- **Language**: Swift 5.8+
- **Frameworks**: EventKit, Foundation
- **Distribution**: Standalone CLI executable
- **Permissions**: Calendar access (will prompt user for permission)

## Functional Requirements

### Core Features
1. **Calendar Access**: Read from source (work) calendar, write to destination (home) calendar
2. **Time Range**: Process current week and next week (14 days total, starting from Monday this week)
3. **Meeting Detection**: Identify 1:1 meetings (exactly 2 attendees including calendar owner)
4. **Smart Sync**: Only make changes when necessary (compare existing events)
5. **Event Creation**: Create "1:1 with [Name]" events in destination calendar with same time slots
6. **Event Deletion**: Remove synced events if the original 1:1 meeting is deleted or changed
7. **Dry Run Mode**: Option to simulate and log changes without modifying calendars

### Business Rules
- Only process events where the calendar owner is one of exactly 2 attendees
- Exclude all-day events
- Use format "1:1 with [Other Person's Name]" for created events
- Preserve original meeting times and duration
- Skip events that already exist and are up-to-date

## Implementation Plan

### Phase 1: Core EventKit & Configuration Foundation

#### 1.1 Create Swift Package
```swift
// Package.swift setup
```
- Initialize Swift package with executable target
- Configure minimum deployment target: macOS 14.0
- Add EventKit framework dependency
- Add Yams (YAML parser) dependency
- Add a Makefile for building and running the project

#### 1.2 EventKit Setup & Calendar Operations
- Request calendar access permissions
- Handle permission denied scenarios gracefully
- Implement calendar discovery by name/identifier
Create `CalendarManager` class with methods:
- `requestAccess() -> Bool`: Request and verify calendar permissions
- `findCalendar(named: String) -> EKCalendar?`: Locate calendar by name
- `getEvents(from: EKCalendar, startDate: Date, endDate: Date) -> [EKEvent]`: Fetch events in date range

#### 1.3 YAML Configuration Management
- Create YAML configuration file support with structure:
  - Multiple calendar pairs for different sync scenarios
  - Event filtering rules (keywords, duration, privacy)
  - Custom title templates
  - Sync window preferences
- Create configuration struct to parse YAML and merge with CLI arguments
- Support command-line arguments: `--config`, `--dry-run`, `--verbose`
- Default config location: `~/.config/calsync1on1/config.yaml`
- Include default configuration file as resource

#### 1.4 Date Range Handling
Create `DateHelper` utility:
- Calculate current week start (Monday)
- Calculate configurable sync window
- Handle timezone considerations

### Phase 2: Meeting Analysis & Event Linking

#### 2.1 Event Metadata System
Create `EventMetadata` utilities:
- `addSyncMetadata(_ event: EKEvent, sourceID: String, version: String)`
- `getSyncMetadata(_ event: EKEvent) -> SyncMetadata?`
- `findSyncedEvent(sourceID: String, in: EKCalendar) -> EKEvent?`
- Store metadata in event notes/URL as JSON for reliable event linking

#### 2.2 Enhanced 1:1 Meeting Detection
Create `MeetingAnalyzer` class:
- `analyzeEvent(_ event: EKEvent, calendarOwner: String) -> AttendeeAnalysis`
  - Check attendee count == 2 (excluding resources like conference rooms)
  - Verify calendar owner participation
  - Handle external organizers
  - Exclude all-day events and configured keywords

#### 2.3 Recurring Event Support
- `analyzeRecurringSeries(_ event: EKEvent) -> RecurrenceAnalysis`
- Handle recurring 1:1 meetings intelligently
- Support for series-level vs instance-level changes
- Detect when recurring series becomes/stops being 1:1

#### 2.4 Attendee Processing
- Extract other person's name with fallback strategies
- Handle multiple email addresses for same person
- Clean up display names and corporate formatting

### Phase 3: Basic Sync Logic & Dry-Run Mode

#### 3.1 Smart Event Comparison
Create `SyncManager` class with:
- `findExistingSyncedEvent(_ originalEvent: EKEvent, in: EKCalendar) -> EKEvent?`
  - Use metadata-based lookup for reliability
- `eventNeedsUpdate(_ existing: EKEvent, _ original: EKEvent) -> UpdateAnalysis`
  - Compare times, dates, attendee names, recurrence rules
  - Detect significant vs cosmetic changes

#### 3.2 Basic Event Operations
- `createSyncedEvent(from: EKEvent, analysis: AttendeeAnalysis, config: SyncConfig) -> EKEvent`
- `updateSyncedEvent(_ existing: EKEvent, from: EKEvent, analysis: AttendeeAnalysis)`
- `deleteSyncedEvent(_ event: EKEvent, reason: DeletionReason)`

#### 3.3 Dry-Run Mode & Basic Reporting
- Implement comprehensive dry-run mode with change previews
- Basic summary of planned changes
- Simple logging output

### Phase 4: Error Handling & Recovery

#### 4.1 Comprehensive Error Handling

#### 4.2 Error Scenarios
- Calendar not found
- No calendar access permission
- Network/system calendar errors
- Invalid date ranges
- Malformed events

#### 4.3 Validation
- Verify calendars exist and are accessible
- Validate date ranges

#### 4.4 Enhanced Logging
- Implement structured logging
- Different verbosity levels
- Progress indicators for long operations

### Phase 5: Advanced Features & Performance

#### 5.1 Advanced Sync Operations
- `handleRecurringSeries(_ series: EKEvent, changes: [RecurrenceChange])`
- Batch operations with operation queue
- Performance optimizations for large calendars

#### 5.2 Enhanced User Experience
- Progress indicators for long operations
- Detailed summary reports with statistics
- Color-coded output for better readability
- Detailed statistics (X events processed, Y created, Z updated, errors encountered)
- Interactive setup wizard (optional)

### Phase 6: Polish & Comprehensive Testing

#### 6.1 CLI Polish & Advanced Features
- Implement proper argument parsing with `ArgumentParser`
- Add comprehensive flags: `--dry-run`, `--verbose`, `--help`, `--version`, `--config`
- Support multiple calendar pairs from configuration
- Add setup wizard for first-time users

#### 6.2 Comprehensive Testing
- Create test calendar setup instructions
- Unit test with various meeting scenarios including edge cases
- Verify permission handling and error recovery
- Unit test recurring event scenarios thoroughly

## Project Structure

```
CalSync1on1/
├── Package.swift
├── Sources/
│   └── CalSync1on1/
│       ├── main.swift
│       ├── Configuration.swift
│       ├── CalendarManager.swift
│       ├── MeetingAnalyzer.swift
│       ├── SyncManager.swift
│       ├── DateHelper.swift
│       └── Models/
│           └── SyncedEvent.swift
├── Tests/
│   └── CalSync1on1Tests/
│       └── CalSync1on1Tests.swift
│       └── ...
├── Resources/
│   └── default-config.yaml
└── README.md
```

## Sample Configuration File

```yaml
# ~/.config/calsync1on1/config.yaml
version: "1.0"

calendar_pairs:
  - name: "Work to Personal"
    source:
      account: "work@company.com"
      calendar: "Calendar"
    destination:
      account: "personal@gmail.com"
      calendar: "Personal"
    title_template: "1:1 with {{otherPerson}}"

sync_window:
  weeks: 2
  start_offset: 0  # 0 = current week, -1 = last week

filters:
  exclude_all_day: true
  exclude_keywords: ["standup", "all-hands", "team meeting"]
  exclude_private: true

recurring_events:
  sync_series: true      # Sync entire recurring series
  handle_exceptions: true # Handle single instance changes

logging:
  level: "info"          # error, warn, info, debug
  colored_output: true
```

## Acceptance Criteria

### Must Have
- [ ] Follows well-established Swift coding conventions and best practices
- [ ] Successfully reads events from specified source calendar
- [ ] Correctly identifies 1:1 meetings (exactly 2 attendees including owner)
- [ ] Properly handles recurring 1:1 meetings and their exceptions
- [ ] Creates "1:1 with [Name]" events in destination calendar with reliable metadata linking
- [ ] Only syncs events for configured time window (default: current + next week)
- [ ] Uses metadata-based event linking to avoid duplicates and enable reliable updates
- [ ] Updates existing synced events when source changes
- [ ] Removes synced events when source 1:1 is deleted/changed
- [ ] Handles calendar permission requests properly
- [ ] Provides clear error messages with colored output
- [ ] Supports comprehensive dry-run mode with change previews
- [ ] Loads configuration from YAML file with CLI argument override support

### Should Have
- [ ] Command-line argument parsing with help and version info
- [ ] Multiple logging levels (error, warn, info, debug) with colored output
- [ ] Progress indication for long-running operations
- [ ] Detailed summary report of changes made with statistics
- [ ] Support for multiple calendar pairs in single configuration
- [ ] Robust error handling with recovery suggestions

### Nice to Have
- [ ] Interactive configuration setup wizard
- [ ] Sync history tracking and reporting
- [ ] Custom filtering rules based on meeting properties
- [ ] Integration with system scheduling (launchd)

## Delivery Requirements

1. **Source Code**: Complete Swift package with all source files
2. **Build Instructions**: Clear steps to compile and run
3. **Usage Documentation**: Command-line options and examples
4. **Test Results**: Evidence of testing with unit tests and real calendar data
5. **Binary**: Compiled executable ready for distribution
6. **README**: Overview of the project, setup instructions, and usage examples

## Dependencies & Setup Notes
- Requires Xcode or Swift command-line tools
- EventKit framework access
- User must grant calendar access permissions when first run
