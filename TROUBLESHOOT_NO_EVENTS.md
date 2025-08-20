# Troubleshooting: 0 Events Found

## Overview

If CalSync1on1 reports "📊 Found 0 total events in source calendar", this means the tool can't access any events from your selected calendar in the specified date range. This guide helps you diagnose and fix this issue.

## Quick Diagnosis

### Step 1: Run Verbose Debugging
```bash
calsync1on1 --verbose --dry-run
```

This will show you:
- All available calendars
- Calendar access permissions
- Event fetching details
- Date range being used
- Test results across different calendars and time periods

## Common Causes & Solutions

### 1. Wrong Calendar Selected

#### Symptoms:
- Other calendars show events, but your source calendar shows 0
- You see: `• Calendar Name: 0 events ← SOURCE`

#### Solution:
Check the "All available calendars" list in verbose output and update your config:
```yaml
calendar_pair:
  source:
    calendar: "Correct Calendar Name"  # Use exact name from list
```

### 2. Date Range Too Narrow

#### Symptoms:
- Verbose output shows: `Events in wider 12-month range: 15`
- Your current sync window shows 0 events

#### Solution:
Expand your sync window in config:
```yaml
sync_window:
  weeks: 8          # Increase from default 2
  start_offset: -2  # Include past 2 weeks
```

### 3. Calendar Permissions Issue

#### Symptoms:
- Authorization status is not "authorized" or "full access"
- Event access test fails
- All calendars show 0 events

#### Solution:
1. Go to **System Preferences > Privacy & Security > Calendars**
2. Ensure CalSync1on1 has **Full Disk Access** or **Calendar** permissions
3. Remove and re-add the app if needed
4. Restart the application

### 4. Empty Calendar

#### Symptoms:
- Even 12-month range shows 0 events
- Calendar exists but has no content

#### Solution:
1. Open **Calendar app** and verify events exist in your calendar
2. Check if events are in the correct calendar
3. Verify events aren't in a different calendar with similar name

### 5. Calendar Synchronization Issues

#### Symptoms:
- Events exist in Calendar app but tool can't see them
- Calendar type shows as "Subscription" or "External"

#### Solution:
1. Force sync your calendar:
   - Open **Calendar app**
   - Go to **Calendar > Refresh All**
2. For Exchange/Outlook calendars:
   - Check network connectivity
   - Re-authenticate if needed
3. For subscribed calendars:
   - These are often read-only
   - May have synchronization delays

## Verbose Output Interpretation

### Calendar Access Test Results
```
🔐 Calendar Access Details:
   Authorization status: 3        # 3 = authorized, good
   Has full access: true          # Should be true
   Has write access: true         # Should be true
```

### Event Fetching Details
```
📥 Fetching events from source calendar...
   🔍 Event fetching details:
   Calendar: Work Calendar
   Date range: Monday, December 18, 2023 to Monday, January 1, 2024
   Total days in range: 14
   ✅ Successfully created event predicate
```

### Cross-Calendar Comparison
```
🔍 Testing event access across all calendars...
   • Personal Calendar: 25 events
   • Work Calendar: 0 events ← SOURCE  # Problem: your calendar is empty
   • Holidays: 12 events
```

### Time Period Analysis
```
📅 Testing specific time periods:
     Today: 0 events
     This week: 0 events
     Last 30 days: 5 events        # Events exist but in past
     Next 30 days: 12 events       # Events exist but in future
```

## Advanced Troubleshooting

### Test Different Time Ranges
If the verbose output shows events in wider ranges, adjust your config:

**For past events:**
```yaml
sync_window:
  weeks: 4
  start_offset: -4  # Go back 4 weeks
```

**For future events:**
```yaml
sync_window:
  weeks: 8          # Look further ahead
  start_offset: 0
```

### Calendar Type Issues
Some calendar types have limitations:

**Subscription Calendars:**
- Often read-only
- May not expose attendee information
- Limited metadata access

**Exchange/Corporate Calendars:**
- May require specific permissions
- Network connectivity issues
- Authentication problems

### Debug Commands
```bash
# Save full debug output
calsync1on1 --verbose --dry-run > debug.log 2>&1

# Check specific sections
grep -A 10 "Testing event access across all calendars" debug.log
grep -A 5 "Events in wider.*month range" debug.log
grep -A 3 "Authorization status" debug.log
```

## Step-by-Step Resolution

1. **Verify Calendar Content**
   - Open Calendar app
   - Confirm events exist in the calendar you're trying to sync
   - Note the exact calendar name

2. **Check Date Range**
   - Look at your event dates in Calendar app
   - Compare with the sync window shown in verbose output
   - Adjust sync window if needed

3. **Test Calendar Access**
   - Run with `--verbose` to see permission status
   - Grant necessary permissions in System Preferences
   - Restart if needed

4. **Try Different Calendar**
   - If other calendars show events, try syncing from one of those
   - Update your config with a calendar that has events

5. **Expand Time Window**
   - Use wider date ranges to catch events outside normal window
   - Look at the time period analysis to see where events exist

## Quick Fixes

### Config Template for Common Issues
```yaml
version: "1.0"
calendar_pair:
  name: "Debug Test"
  source:
    calendar: "EXACT_CALENDAR_NAME_FROM_VERBOSE_OUTPUT"
  destination:
    calendar: "Personal"
  title_template: "1:1 with {{otherPerson}}"
  owner_email: "your.email@domain.com"

sync_window:
  weeks: 8       # Wider range
  start_offset: -2  # Include past

filters:
  exclude_all_day: false      # Disable temporarily
  exclude_keywords: []        # Disable temporarily
  exclude_private: false      # Disable temporarily

logging:
  level: "debug"
  colored_output: true
```

### Emergency Workarounds

**If still no events found:**
1. Try syncing from a different calendar temporarily
2. Use a much wider date range (12+ weeks)
3. Check if events are actually in a different calendar
4. Verify calendar isn't corrupted by creating a test event

## Getting Help

If none of these solutions work, run this command and examine the output:

```bash
calsync1on1 --verbose --dry-run > complete_debug.log 2>&1
```

Look for:
- The exact calendar names available
- Event counts for each calendar
- Your date range vs where events actually exist
- Permission and access status
- Any error messages in the detailed output

The verbose output will show exactly why your calendar appears empty and guide you to the specific solution needed.