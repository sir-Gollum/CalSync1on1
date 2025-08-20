# CalSync1on1 Debug Guide

This guide helps you troubleshoot why CalSync1on1 isn't finding your 1:1 meetings. The tool now includes comprehensive debugging features to identify exactly what's happening.

## Quick Debugging Steps

### 1. Run with Verbose Mode
```bash
calsync1on1 --verbose --dry-run
```

This will show you:
- All available calendars
- Detailed event analysis
- Owner identification process
- Why specific events aren't detected as 1:1
- Diagnostic recommendations

### 2. Check the Output Sections

The verbose output is organized into these key sections:

#### 📋 All Available Calendars
```
📋 All available calendars:
   • Work Calendar (Exchange) - CalDAV, writable
   • Personal Calendar (iCloud) - CalDAV, writable
   • Holidays (iCloud) - Subscription, read-only
```
**What to check:** Make sure your source calendar name matches exactly.

#### 🔍 Source Calendar Details
```
🔍 Source calendar details:
   Calendar title: 'Work Calendar'
   Calendar source: 'Exchange'
   Calendar type: CalDAV
   Allows modifications: true
```
**What to check:** Verify this is the right calendar with your meetings.

#### 🔍 Owner Identification Details
```
🔍 Owner identification details:
   ✅ Using configured owner email: 'john.doe@company.com'
   Generated matching patterns: ["john.doe@company.com", "john.doe"]
   ✅ Owner identifier looks like an email address
```
**What to check:** Make sure the owner identifier matches how you appear in meeting attendees.

#### 🔍 Detailed Event Analysis
```
[1] Weekly 1:1 with Sarah - 2 attendees
     Attendees: John Doe <john.doe@company.com>, Sarah Johnson <sarah@company.com>
     Time: 12/19/23, 2:00 PM
     All-day: false
     Event ID: ABC123
     Organizer: Sarah Johnson <sarah@company.com>

   📋 Analyzing 'Weekly 1:1 with Sarah':
     - Attendee count: 2
     - All-day event: false
     - Has attendees list: true
     - Attendee details:
       [1] John Doe <john.doe@company.com>
           Type: 1, Role: 2, Status: 2
       [2] Sarah Johnson <sarah@company.com>
           Type: 1, Role: 1, Status: 2
     - Owner matching analysis:
       Calendar owner identifier: 'john.doe@company.com'
       Generated owner emails: ["john.doe@company.com", "john.doe"]
       Attendee emails: ["john.doe@company.com", "sarah@company.com"]
       Attendee [1] 'john.doe@company.com' matches owner: true
       Attendee [2] 'sarah@company.com' matches owner: false
     - Final 1:1 detection result: true
   ✅ Successfully detected as 1:1 meeting
```

#### 📊 Debugging Summary
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
```

## Common Issues and Solutions

### Issue 1: No 1:1 Meetings Found

#### Symptoms:
```
📊 Found 0 1:1 meetings
💡 DIAGNOSTIC RECOMMENDATIONS:
   🔍 No 1:1 meetings found. Potential issues:
     • Events with 2 attendees exist but owner matching failed
     • No 'owner_email' configured - using calendar source: 'Exchange'
```

#### Solutions:
1. **Add owner_email to config:**
```yaml
calendar_pair:
  source:
    calendar: "Work Calendar"
  destination:
    calendar: "Personal Calendar"
  title_template: "1:1 with {{otherPerson}}"
  owner_email: "your.actual.email@company.com"  # Add this line
```

2. **Find your correct email from the debug output:**
Look for the "📧 Unique organizer emails found" section to see what emails appear in your calendar.

### Issue 2: Owner Email Not Matching

#### Symptoms:
```
   📋 Analyzing 'Team Sync':
     - Attendee count: 2
     - Owner matching analysis:
       Calendar owner identifier: 'Exchange'
       Generated owner emails: ["Exchange", "exchange@gmail.com"]
       Attendee emails: ["john.doe@company.com", "sarah@company.com"]
       Attendee [1] 'john.doe@company.com' matches owner: false
       Attendee [2] 'sarah@company.com' matches owner: false
     - Final 1:1 detection result: false
```

#### Solutions:
1. **Set the correct owner_email:**
```yaml
owner_email: "john.doe@company.com"
```

2. **Check your email variations:**
If your email in events differs from your config, try common variations:
- Full email: `john.doe@company.com`
- Display name: `John Doe`
- Username only: `jdoe`

### Issue 3: Events Filtered Out

#### Symptoms:
```
📊 Found 25 total events in source calendar
📊 15 events after applying filters
💡 10 events were filtered out - check filter settings if needed
```

#### Solutions:
Check your filter settings:
```yaml
filters:
  exclude_all_day: true        # May be filtering out your meetings
  exclude_keywords:            # May be too restrictive
    - "standup"
    - "meeting"               # This might filter out "1:1 meeting"
  exclude_private: true        # May be filtering private meetings
```

### Issue 4: Calendar Not Found

#### Symptoms:
```
❌ Error: Could not find source calendar named 'Work Calendar'
   Available calendars:
   • Calendar (iCloud)
   • Personal (iCloud)
```

#### Solutions:
1. **Use exact calendar name from the available list**
2. **Check calendar visibility in Calendar app**
3. **Verify calendar permissions**

### Issue 5: Wrong Date Range

#### Symptoms:
```
📅 Sync window: 2 weeks
   From: Monday, December 18, 2023
   To: Monday, January 1, 2024
📊 Found 0 total events in source calendar
```

#### Solutions:
1. **Extend sync window:**
```yaml
sync_window:
  weeks: 4              # Increase from 2
  start_offset: -1      # Include past week
```

2. **Check if your meetings are in the date range shown**

## Advanced Debugging

### Deep Dive Analysis

For complex issues, examine each event individually:

```bash
calsync1on1 --verbose --dry-run | grep -A 20 "📋 Analyzing"
```

This shows the detailed analysis of each event including:
- Attendee types, roles, and statuses
- Email matching attempts
- Why each attendee does/doesn't match the owner

### Participant Types Reference

From the debug output, participant types mean:
- Type 1: Person
- Type 2: Room/Resource  
- Type 3: Group

Role values:
- Role 1: Chair/Organizer
- Role 2: Required Participant
- Role 3: Optional Participant

### Email Matching Logic

The tool tries these matching strategies in order:
1. **Exact match:** `john@company.com` == `john@company.com`
2. **Contains match:** `john@company.com` contains `john` or vice versa
3. **Local part match:** `john@company.com` matches `john@different.com`

### Configuration Testing

Create a test config to isolate issues:

```yaml
version: "1.0"
calendar_pair:
  name: "Debug Test"
  source:
    calendar: "Your Exact Calendar Name"  # From available calendars list
  destination:
    calendar: "Personal"
  title_template: "1:1 with {{otherPerson}}"
  owner_email: "your.email@domain.com"   # From debug output

sync_window:
  weeks: 4
  start_offset: -1

filters:
  exclude_all_day: false     # Disable to see all events
  exclude_keywords: []       # Disable to see all events
  exclude_private: false     # Disable to see all events

logging:
  level: "debug"
  colored_output: true
```

## Getting Help

If you're still having issues:

1. **Run the full debug command:**
```bash
calsync1on1 --config your-config.yaml --verbose --dry-run > debug.log 2>&1
```

2. **Check these sections in debug.log:**
- Owner identification details
- Events with 2 attendees NOT detected as 1:1
- Diagnostic recommendations

3. **Common fixes based on debug output:**
- Add/correct `owner_email` in configuration
- Adjust filter settings
- Verify calendar names and date ranges
- Check calendar permissions

## Debug Output Cheat Sheet

| Section | What It Shows | What to Look For |
|---------|---------------|------------------|
| 📋 All available calendars | Calendar names and types | Exact name for config |
| 🔍 Source calendar details | Calendar properties | Right calendar selected |
| 🔍 Owner identification | How you're identified | Email vs account name |
| 🔍 Detailed event analysis | Each event's attendees | Your email in attendees |
| 📊 Debugging summary | Statistics and missed events | Why 2-attendee events failed |
| 📧 Unique organizer emails | All organizer emails found | Your email variations |
| 💡 Diagnostic recommendations | Automated suggestions | Quick fixes to try |

## 🔍 Comprehensive Event Data Debugging

### New: Complete Event Analysis

The latest version now shows **ALL event data** in verbose mode, giving you complete visibility into your calendar events:

```bash
calsync1on1 --verbose --dry-run
```

#### What You'll See:

**📅 ALL EVENTS COMPREHENSIVE DATA:**
For each event in your calendar, you'll see:

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
      Type: 1 (Person, 2=Room, 3=Group)
      Role: 2 (Required, 1=Chair, 3=Optional)
      Status: 3 (Accepted, 1=Unknown, 2=Pending, 4=Declined, 5=Tentative)
  [2] Name: Sarah Johnson
      Email: sarah@company.com
      Type: 1, Role: 1, Status: 3

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

**📈 EVENT STATISTICS:**
```
Total events: 25
All-day events: 3 (12.0%)
Events with attendees: 18 (72.0%)
Events with exactly 2 attendees: 8 (32.0%)
Recurring events: 12 (48.0%)
```

### 🔧 Using the Complete Data for Debugging

#### 1. **Check Event Structure**
Look at the raw event data to understand:
- How your email appears in attendee lists
- What participant types, roles, and statuses are present
- Whether events have the expected structure

#### 2. **Analyze Owner Matching**
The "🎯 1:1 ANALYSIS" section shows:
- Your owner patterns being tested
- Exact matching results for each attendee
- Why specific attendees do/don't match

#### 3. **Verify Filter Logic** 
The "✅ FILTER STATUS" shows:
- Whether each event passes your filters
- Specific reasons why events are filtered out
- Impact of different filter settings

#### 4. **Examine Edge Cases**
Look for unusual patterns:
- Events without attendee lists (`attendees: null`)
- Non-standard email formats in URLs
- Room/resource attendees (Type: 2) 
- Events with unusual participant statuses

### 💡 Common Issues Revealed by Complete Data

#### **Issue: Attendees List is Null**
```
👥 ATTENDEES:
  Attendees list is nil
```
**Solution:** These events can't be 1:1 meetings. Check calendar permissions or event privacy settings.

#### **Issue: Room/Resource Attendees**
```
[2] Name: Conference Room A
    Email: room.booking@company.com
    Type: 2 (Room)
```
**Solution:** Tool correctly ignores these as they're not person-to-person meetings.

#### **Issue: Non-Standard Email URLs**
```
URL (raw): tel:+1234567890
```
**Solution:** Some calendar systems use different URL schemes. Tool extracts emails from `mailto:` URLs only.

#### **Issue: Owner Email Variations**
```
Owner patterns: ["Exchange", "exchange@gmail.com"]
Attendee [1] 'john.doe@company.com' matches owner: false
```
**Solution:** Set correct `owner_email` in config - the generated patterns don't match your actual email.

### 📊 Data Analysis Tips

1. **Export for Analysis:**
   Save the complete output to a file:
   ```bash
   calsync1on1 --verbose --dry-run > calendar_debug.log 2>&1
   ```

2. **Search for Patterns:**
   ```bash
   # Find all 2-attendee events
   grep -A 10 "attendeeCount.*2" calendar_debug.log
   
   # Find your email variations
   grep -i "your.name@" calendar_debug.log
   
   # Find events that should be 1:1 but aren't detected
   grep -A 20 "exactly 2 attendees" calendar_debug.log
   ```

3. **Compare Event Structures:**
   Look at events you know should be 1:1 vs those that shouldn't to identify patterns.

### 🚀 Advanced Debugging Workflow

1. **Run comprehensive analysis:**
   ```bash
   calsync1on1 --verbose --dry-run > full_debug.log 2>&1
   ```

2. **Check statistics first:**
   Look for the "📈 EVENT STATISTICS" section to understand your calendar composition.

3. **Focus on 2-attendee events:**
   Search for events with exactly 2 attendees and examine their 1:1 analysis.

4. **Verify owner matching:**
   Ensure your owner patterns include the email format used in your events.

5. **Test configuration changes:**
   Based on the data, adjust your `owner_email` and filter settings.

Remember: The most common issue is owner email mismatch. Make sure your `owner_email` in the config exactly matches how you appear as an attendee in your calendar events.