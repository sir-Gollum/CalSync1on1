# CalSync1on1 Comprehensive Debug Features

## 🎯 Overview

This document describes the comprehensive debugging features added to CalSync1on1 to help troubleshoot why 1:1 meetings aren't being detected in your source calendar.

## 🚀 Quick Start Debugging

### Essential Debug Command
```bash
calsync1on1 --verbose --dry-run
```

### Save Debug Data for Analysis
```bash
calsync1on1 --verbose --dry-run > debug_output.log 2>&1
```

## 📊 What You'll See in Verbose Mode

### 1. 🔐 Calendar Access Details
Shows your calendar permissions and authorization status:
```
🔐 Calendar Access Details:
   Authorization status: 3
   Has full access: true
   Has write access: true
```

### 2. 📋 All Available Calendars
Complete list of calendars with metadata:
```
📋 All available calendars:
   • Work Calendar (Exchange) - CalDAV, writable
   • Personal Calendar (iCloud) - CalDAV, writable
   • Holidays (iCloud) - Subscription, read-only
   • Birthdays (Local) - Birthday, read-only
```

### 3. 🔍 Source Calendar Details
Detailed information about your selected source calendar:
```
🔍 Source calendar details:
   Calendar title: 'Work Calendar'
   Calendar source: 'Exchange'
   Calendar type: CalDAV
   Source type: 0
   Allows modifications: true
   Is immutable: false
```

### 4. 🔍 Owner Identification Analysis
How the tool identifies you as the calendar owner:
```
🔍 Owner identification details:
   ✅ Using configured owner email: 'john.doe@company.com'
   Generated matching patterns: ["john.doe@company.com", "john.doe"]
   ✅ Owner identifier looks like an email address
```

### 5. 📅 ALL EVENTS COMPREHENSIVE DATA
**This is the key new feature** - complete data for every event:

```
========== EVENT 1 ==========
📝 BASIC INFO:
  Title: Weekly 1:1 with Sarah
  Event ID: ABC123-DEF456
  Start: 12/19/23, 2:00 PM
  End: 12/19/23, 2:30 PM
  All-day: false
  Duration: 30.0 minutes
  Notes: Discuss project progress
  Location: Conference Room A
  URL: https://zoom.us/meeting/123
  Status: 3 (Confirmed)
  Availability: 0 (Busy)

🔄 RECURRENCE:
  Has recurrence rules: true
  Rule 1: Weekly on Tuesday

👤 ORGANIZER:
  Name: Sarah Johnson
  Email: sarah@company.com
  Type: 1 (Person)
  Role: 1 (Chair)
  Status: 3 (Accepted)

👥 ATTENDEES:
  Count: 2
  [1] Name: John Doe
      Email: john.doe@company.com
      URL (raw): mailto:john.doe@company.com
      Type: 1 (1=Person, 2=Room, 3=Group)
      Role: 2 (1=Chair, 2=Required, 3=Optional)
      Status: 3 (1=Unknown, 2=Pending, 3=Accepted, 4=Declined, 5=Tentative)
  [2] Name: Sarah Johnson
      Email: sarah@company.com
      URL (raw): mailto:sarah@company.com
      Type: 1, Role: 1, Status: 3

📆 CALENDAR INFO:
  Calendar: Work Calendar
  Calendar source: Exchange
  Calendar type: CalDAV

🔍 METADATA:
  Created: 12/15/23, 10:30 AM
  Modified: 12/18/23, 9:15 AM
  Time zone: America/New_York

✅ FILTER STATUS:
  Passes filters: true

🎯 1:1 ANALYSIS (Raw Check):
  Has exactly 2 attendees - checking owner match...
  Owner patterns: ["john.doe@company.com", "john.doe"]
  Attendee [1] 'john.doe@company.com' matches owner: true
  Attendee [2] 'sarah@company.com' matches owner: false

📊 RAW EVENT DATA SUMMARY:
  JSON-like representation:
  {
    "title": "Weekly 1:1 with Sarah",
    "eventIdentifier": "ABC123-DEF456",
    "isAllDay": false,
    "attendeeCount": 2,
    "hasRecurrenceRules": true,
    "status": 3,
    "availability": 0
    "attendees": [
      {
        "name": "John Doe",
        "email": "john.doe@company.com",
        "participantType": 1,
        "participantRole": 2,
        "participantStatus": 3
      },
      {
        "name": "Sarah Johnson",
        "email": "sarah@company.com",
        "participantType": 1,
        "participantRole": 1,
        "participantStatus": 3
      }
    ]
  }
```

### 6. 📈 EVENT STATISTICS
Summary statistics about your calendar:
```
📈 EVENT STATISTICS:
   Total events: 25
   All-day events: 3 (12.0%)
   Events with attendees: 18 (72.0%)
   Events with exactly 2 attendees: 8 (32.0%)
   Recurring events: 12 (48.0%)
```

### 7. 📊 DEBUGGING SUMMARY
Analysis results and recommendations:
```
📊 DEBUGGING SUMMARY:
   Total events fetched: 25
   Events after filtering: 20
   Events detected as 1:1: 3

   📈 Attendee count distribution:
     0 attendees: 5 events (25.0%)
     1 attendees: 8 events (40.0%)
     2 attendees: 4 events (20.0%)
     3+ attendees: 3 events (15.0%)

   ⚠️  2 events with 2 attendees NOT detected as 1:1:
     [1] Project Review Meeting
        - John Doe <john.doe@company.com>
        - Conference Room <room.booking@company.com>
     [2] Client Call Setup
        - John Doe <john.doe@company.com>
        - External User <external@client.com>

   📧 Unique organizer emails found:
     - john.doe@company.com
     - sarah@company.com
     - mike.chen@company.com

   💡 DIAGNOSTIC RECOMMENDATIONS:
     🔍 No 1:1 meetings found. Potential issues:
       • Events with 2 attendees exist but owner matching failed
       • Try setting 'owner_email' in your configuration
       • Check if your email matches the attendee emails in events
```

## 🔍 Key Debugging Data Points

### Event Structure Analysis
For each event, you can see:
- **Complete attendee list** with names, emails, types, roles, statuses
- **Organizer information** including email and permissions
- **Raw URL data** to understand email extraction
- **Event metadata** like creation/modification dates
- **Filter application results** showing why events are included/excluded
- **1:1 matching analysis** showing exact owner matching logic

### Participant Types Reference
- **Type 1:** Person (human attendee)
- **Type 2:** Room/Resource (conference room, equipment)
- **Type 3:** Group (distribution list, team)

### Participant Roles Reference
- **Role 1:** Chair/Organizer
- **Role 2:** Required Participant
- **Role 3:** Optional Participant

### Participant Status Reference
- **Status 1:** Unknown
- **Status 2:** Pending
- **Status 3:** Accepted
- **Status 4:** Declined
- **Status 5:** Tentative

## 🚨 Common Issues Revealed

### 1. Owner Email Mismatch
**Symptom:**
```
Owner patterns: ["Exchange", "exchange@gmail.com"]
Attendee [1] 'john.doe@company.com' matches owner: false
```
**Solution:** Set correct `owner_email` in configuration.

### 2. Room/Resource Attendees
**Symptom:**
```
[2] Name: Conference Room A
    Type: 2 (Room)
```
**Solution:** Normal - tool correctly excludes room bookings.

### 3. Events Without Attendees
**Symptom:**
```
👥 ATTENDEES:
  Attendees list is nil
```
**Solution:** Check calendar permissions or event privacy.

### 4. Non-Standard Email URLs
**Symptom:**
```
URL (raw): tel:+1234567890
```
**Solution:** Tool only processes `mailto:` URLs for email extraction.

### 5. Filter Issues
**Symptom:**
```
✅ FILTER STATUS:
  Passes filters: false
  Reason: Contains excluded keyword 'meeting'
```
**Solution:** Adjust filter keywords in configuration.

## 🛠️ Debugging Workflow

### Step 1: Run Comprehensive Analysis
```bash
calsync1on1 --verbose --dry-run > debug.log 2>&1
```

### Step 2: Check Key Sections
1. **EVENT STATISTICS** - Understand your calendar composition
2. **Events with exactly 2 attendees** - Focus on potential 1:1s
3. **Owner identification details** - Verify matching patterns
4. **DIAGNOSTIC RECOMMENDATIONS** - Follow automated suggestions

### Step 3: Analyze Specific Events
Search the debug log for patterns:
```bash
# Find all 2-attendee events
grep -A 10 "attendeeCount.*2" debug.log

# Find your email variations
grep -i "your.name@" debug.log

# Find owner matching failures
grep -A 5 "matches owner: false" debug.log
```

### Step 4: Test Configuration Changes
Based on findings:
1. Set correct `owner_email`
2. Adjust filter settings
3. Extend sync window if needed
4. Re-run with changes

## 📋 Debug Data Export

The comprehensive event data can be exported in multiple ways:

### Save to File
```bash
calsync1on1 --verbose --dry-run > calendar_analysis.log 2>&1
```

### Extract Specific Data
```bash
# Get all attendee information
grep -A 20 "👥 ATTENDEES:" debug.log

# Get JSON-like event summaries
grep -A 30 "📊 RAW EVENT DATA SUMMARY:" debug.log

# Get filtering results
grep -A 5 "✅ FILTER STATUS:" debug.log
```

### Search for Issues
```bash
# Find events that should be 1:1 but aren't
grep -B 5 -A 15 "exactly 2 attendees.*checking owner match" debug.log

# Find owner matching problems
grep -A 10 "matches owner: false" debug.log
```

## 🎯 Success Indicators

When debugging is working correctly, you should see:
- Events with exactly 2 attendees
- Your email appearing in attendee lists
- Owner matching returning `true` for your attendee entry
- Events passing through filters appropriately
- Final 1:1 detection results showing `true`

## 📞 Getting Help

If comprehensive debugging doesn't reveal the issue:

1. **Save complete debug output:**
   ```bash
   calsync1on1 --verbose --dry-run > full_debug.log 2>&1
   ```

2. **Focus on these sections:**
   - Owner identification details
   - Events with 2 attendees NOT detected as 1:1
   - Raw event data for meetings you know should be 1:1

3. **Check for edge cases:**
   - Unusual email formats
   - Calendar-specific metadata issues
   - Permission or privacy restrictions

The comprehensive debugging features provide complete visibility into every aspect of the 1:1 detection process, making it possible to identify and resolve even complex calendar integration issues.