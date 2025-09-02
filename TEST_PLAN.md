# CalSync1on1 Test Plan

## Overview

This document outlines a comprehensive test plan to improve test coverage for the most critical functionality in CalSync1on1. The focus is on testing core business logic, synchronization operations, and edge cases while maintaining fast, reliable, offline tests.

## 📊 Current Progress Summary

**✅ COMPLETED MODULES:**
- **MeetingAnalyzer** (100%): Email parsing, owner matching, detection logic helpers
- **EventFilter** (100%): All filtering scenarios, keyword matching, all-day events  
- **EventMetadata** (100%): JSON encoding/decoding, metadata lifecycle, notes handling
- **Configuration** (100%): Loading, validation, setup processes
- **Command Line Args** (100%): All argument parsing scenarios

**📈 COVERAGE PROGRESS:**
- **Foundation Tests**: ✅ Complete (Week 1)
- **Core Business Logic**: 🔶 60% Complete (Week 2 - EventMetadata done)
- **Sync Operations**: ❌ Pending (SyncManager, CalendarManager)
- **Integration Tests**: ❌ Pending (Week 3)

**🎯 NEXT CRITICAL PRIORITIES:**
1. **SyncManager Tests** - Core sync operations (HIGH)
2. **MeetingAnalyzer `isOneOnOneMeeting()`** - Implementation needed (CRITICAL)
3. **CalendarManager Tests** - Event retrieval logic (MEDIUM)

## Current Test Coverage Analysis

### ✅ Already Covered
- Configuration loading and validation (`ConfigurationLoadingTests.swift`)
- Command line argument parsing (`CommandLineArgsTests.swift`)
- Basic utility functions and data structures (`CalSync1on1Tests.swift`)
- Configuration setup processes (`ConfigurationSetupTests.swift`)
- **MeetingAnalyzer**: Comprehensive tests for 1:1 meeting detection logic (`MeetingAnalyzerTests.swift`)
  - Owner email generation and matching (refactored into table-driven test)
  - Email extraction and name parsing
  - Email matching logic with real-world patterns
  - Performance and consistency tests
- **EventFilter**: Complete filtering logic with various scenarios (`EventFilterTests.swift`)
  - Keyword filtering (case-insensitive, partial matches, multiple keywords)
  - All-day event filtering
  - Combined filters and realistic scenarios
  - Filter reasoning and descriptive output
- **EventMetadata**: Complete metadata operations and JSON handling (`EventMetadataTests.swift`)
  - Metadata encoding/decoding cycle with various ID formats
  - Synced event detection and lifecycle management
  - Notes preservation and metadata removal
  - Find synced event logic simulation
  - Edge cases, error handling, and special characters
  - SyncMetadata struct Codable compliance

### ❌ Missing Critical Coverage
- **SyncManager**: Core synchronization operations
- **CalendarManager**: Event retrieval and calendar operations
- **Integration Tests**: End-to-end sync flows

## Test Implementation Plan

### Phase 1: Core Business Logic (Week 1) 🔥

#### 1.1 MeetingAnalyzer Tests - `MeetingAnalyzerTests.swift` ✅ COMPLETED

**Status**: IMPLEMENTED AND REFACTORED
**Implementation Time**: Completed

**What's Implemented:**
- **Owner Email Generation**: Comprehensive table-driven test covering:
  - Full email inputs (extracting local part)
  - Account name inputs (generating Gmail variants)
  - Names with spaces (generating both space and dot variants)
  - Complex multi-word names and Unicode characters
  - Empty string handling with proper filtering
- **Email Extraction**: Various email format parsing tests
- **Name Extraction**: Email-to-name conversion with Unicode support
- **Email Matching Logic**: Real-world patterns and edge cases
- **Performance Tests**: Measuring email generation and extraction performance
- **Consistency Tests**: Ensuring deterministic behavior across multiple runs

**Key Improvements Made:**
- Refactored 6 separate tests into 1 maintainable table-driven test
- Added ANSI color codes for better error visibility in Logger
- Enhanced empty string filtering to prevent invalid email patterns
- Comprehensive edge case coverage without over-engineering

**Note**: Core 1:1 meeting detection logic (`isOneOnOneMeeting`) still needs implementation - this is the main missing piece for MeetingAnalyzer.

#### 1.2 EventFilter Tests - `EventFilterTests.swift` ✅ COMPLETED

**Status**: IMPLEMENTED AND COMPREHENSIVE
**Implementation Time**: Completed

**What's Implemented:**
- **Keyword Filtering**: Case-insensitive matching, partial matches, multiple keywords
- **All-Day Event Filtering**: Complete filtering with enable/disable options
- **Combined Filters**: All-day + keyword filters working together
- **Filter Reasoning**: Descriptive output explaining why events were filtered
- **Edge Cases**: Empty events, special characters, Unicode support
- **Realistic Scenarios**: Complex filtering combinations
- **Performance**: Event order preservation and efficient filtering

**Key Features:**
- Comprehensive test coverage for all filtering scenarios
- No over-engineered mocks - uses simple, effective test data
- Clear, maintainable test structure with descriptive assertions
- Proper error messaging and filter reasoning validation

#### 1.3 Mock Utilities Infrastructure - `MockUtilities.swift` 🚫 NOT NEEDED

**Status**: SIMPLIFIED APPROACH - NO COMPLEX MOCKING REQUIRED
**Rationale**: Current tests prove that simple, direct testing is more effective than elaborate mock infrastructure.

**Current Approach That Works:**
- Use real EventKit objects where possible
- Simple test data factories instead of complex mocks
- Table-driven tests for comprehensive coverage
- Focus on business logic, not framework mocking

```swift
import EventKit
import Foundation
@testable import CalSync1on1

// MARK: - Mock Event Creation Utilities
extension XCTestCase {

    func createMockEvent(
        title: String,
        attendeeEmails: [String] = [],
        attendeeNames: [String?] = [],
        isAllDay: Bool = false,
        startDate: Date = Date(),
        duration: TimeInterval = 3600,
        hasRecurrenceRules: Bool = false
    ) -> EKEvent {
        // Implementation needed: Create proper EKEvent mocks
        // Challenge: EKEvent has private/internal properties
        // Solution: Use dependency injection or protocol-based mocking
    }

    func createTestConfiguration(
        excludeKeywords: [String] = ["standup", "scrum"],
        excludeAllDay: Bool = true,
        weeks: Int = 2,
        startOffset: Int = 0
    ) -> Configuration {
        // Create standardized test configurations
    }

    // Convenience methods for common test scenarios
    func create1on1Event(title: String, attendeeEmails: [String]) -> EKEvent
    func createTeamEvent(title: String, attendeeEmails: [String]) -> EKEvent
    func createAllDayEvent(title: String) -> EKEvent
    func createRecurringEvent(title: String, attendeeEmails: [String]) -> EKEvent
}

// MARK: - Mock Classes
class MockEKParticipant: EKParticipant {
    var mockEmail: String = ""
    var mockName: String?

    // Override necessary properties and methods
}

class MockCalendarManager {
    // Mock calendar and event management
    private var mockEvents: [String: [EKEvent]] = [:]
    private var mockCalendars: [String: EKCalendar] = [:]

    func setMockEvents(for calendarName: String, events: [EKEvent])
    func getMockEvents(from calendarName: String) -> [EKEvent]
    func setMockCalendar(name: String, calendar: EKCalendar)
}
```

**Critical Implementation Challenges:**

1. **EKEvent Mocking Challenge**: EKEvent has many private/internal properties

   **Solutions:**
   ```swift
   // Option 1: Protocol-based abstraction
   protocol EventProtocol {
       var title: String? { get set }
       var attendees: [EKParticipant]? { get }
       var isAllDay: Bool { get set }
       var startDate: Date! { get set }
       var endDate: Date! { get set }
   }

   // Option 2: Test doubles with setValue:forKey:
   private func setValue<T>(_ value: T, forKey key: String, on object: Any) {
       // Use reflection to set internal properties
   }

   // Option 3: Factory pattern for test events
   struct TestEventFactory {
       static func createEvent(with config: TestEventConfig) -> EKEvent {
           // Centralized event creation logic
       }
   }
   ```

2. **EKParticipant URL Property**: Must return proper mailto: URLs
   ```swift
   class MockEKParticipant: EKParticipant {
       var mockEmail: String = ""

       override var url: URL {
           return URL(string: "mailto:\(mockEmail)")!
       }
   }
   ```

### Phase 2: Sync Operations (Week 2) ⚡

**PRIORITY FOCUS**: The remaining work should focus on practical, business-critical functionality.

#### 2.1 SyncManager Tests - `SyncManagerTests.swift` 🔶 HIGH PRIORITY

**Priority**: CRITICAL
**Estimated Time**: 3-4 days

```swift
final class SyncManagerTests: XCTestCase {
    private var syncManager: SyncManager!
    private var mockConfiguration: Configuration!
    private var analyzer: MeetingAnalyzer!

    func testEventNeedsUpdateDetection() {
        // Test title change detection
        // Test date/time change detection
        // Test when no update needed
        // Test metadata-based comparison
    }

    func testSyncEventCreation() {
        // Test new event creation
        // Test metadata addition
        // Test title template application
        // Test date/time copying
    }

    func testSyncEventUpdating() {
        // Test existing event updates
        // Test selective field updates
        // Test metadata preservation
    }

    func testRecurringEventSync() {
        // Test recurring series detection
        // Test series vs individual event sync
        // Test exception handling
    }

    func testOrphanedEventCleanup() {
        // Test cleanup of deleted source events
        // Test metadata-based identification
        // Test preservation of manual events
    }

    func testDryRunMode() {
        // Test dry run vs actual execution
        // Verify no actual changes in dry run
        // Test result reporting accuracy
    }

    func testErrorHandling() {
        // Test calendar access errors
        // Test event creation failures
        // Test error accumulation and reporting
    }
}
```

**Implementation Notes:**
- Use dependency injection to provide mock CalendarManager
- Test both dry-run and actual sync modes
- Verify error propagation and handling
- Test complex scenarios with mixed event types

#### 2.2 EventMetadata Tests - `EventMetadataTests.swift` ✅ COMPLETED

**Priority**: HIGH
**Estimated Time**: 1-2 days

```swift
final class EventMetadataTests: XCTestCase {

    func testMetadataEncodingDecoding() {
        // Test JSON encoding/decoding cycle
        // Test metadata format consistency
        // Test invalid JSON handling
    }

    func testMetadataWithExistingNotes() {
        // Test appending to existing notes
        // Test notes preservation
        // Test duplicate metadata prevention
    }

    func testSyncedEventDetection() {
        // Test isSyncedEvent() accuracy
        // Test with various note formats
        // Test edge cases and malformed data
    }

    func testMetadataRemoval() {
        // Test clean removal of metadata
        // Test notes preservation after removal
        // Test handling of malformed metadata
    }

    func testFindSyncedEvent() {
        // Test event lookup by source ID
        // Test with large event sets
        // Test performance considerations
    }
}
```

### Phase 3: Integration & Edge Cases (Week 3) 🔄

#### 3.1 Integration Tests - `CalendarSyncIntegrationTests.swift`

**Priority**: CRITICAL
**Estimated Time**: 3-4 days

```swift
final class CalendarSyncIntegrationTests: XCTestCase {
    private var mockCalendarManager: MockCalendarManager!
    private var syncManager: SyncManager!
    private var analyzer: MeetingAnalyzer!
    private var configuration: Configuration!

    func testEnd2EndSyncFlow() {
        // Test complete sync workflow
        // Mixed event types (1:1, team, all-day)
        // Filter application
        // Sync execution
        // Result verification
    }

    func testMultiple1on1MeetingsSync() {
        // Test batch processing of 1:1 meetings
        // Different attendee patterns
        // Various time ranges
        // Concurrent meeting handling
    }

    func testRecurringEventIntegration() {
        // Test recurring series processing
        // Exception handling
        // Series modification scenarios
    }

    func testErrorRecovery() {
        // Test partial failure scenarios
        // Error propagation through workflow
        // Recovery and continuation logic
    }

    func testPerformanceWithLargeEventSets() {
        // Test with 100+ events
        // Memory usage verification
        // Processing time benchmarks
    }
}
```

#### 3.2 CalendarManager Tests - `CalendarManagerTests.swift`

**Priority**: MODERATE
**Estimated Time**: 1-2 days

```swift
final class CalendarManagerTests: XCTestCase {

    func testCalendarDiscovery() {
        // Test findCalendar() with various names
        // Test case sensitivity
        // Test partial matches and disambiguation
    }

    func testEventRetrieval() {
        // Test date range queries
        // Test calendar-specific filtering
        // Test empty result handling
    }

    func testAccessValidation() {
        // Test permission checking
        // Test access denial scenarios
        // Test different permission levels (iOS 14+)
    }

    func testEventCreationAndUpdate() {
        // Test event creation workflow
        // Test event modification
        // Test error scenarios
    }
}
```

## Implementation Guidelines

### 🎯 FOCUS ON WHAT MATTERS

**DO:**
- Test core business logic (1:1 meeting detection, sync operations)
- Use simple, direct test approaches
- Write table-driven tests for multiple scenarios
- Focus on edge cases that could break production
- Test error handling for critical paths
- Keep things DRY and clean

**DON'T:**
- Over-engineer mocking infrastructure
- Write tests for framework code (EventKit)
- Create elaborate fixtures for simple scenarios
- Test trivial getters/setters
- Mock everything - use real objects when practical

## Implementation Guidelines

### Mocking Strategy

1. **EKEvent Mocking Approaches:**
   ```swift
   // Preferred: Protocol abstraction
   protocol CalendarEventProtocol {
       var title: String? { get set }
       var attendees: [EKParticipant]? { get }
       var isAllDay: Bool { get set }
       var startDate: Date! { get set }
       var endDate: Date! { get set }
       var hasRecurrenceRules: Bool { get }
   }

   // Fallback: Direct property setting with reflection
   extension EKEvent {
       func setTestAttendees(_ attendees: [EKParticipant]) {
           setValue(attendees, forKey: "attendees")
       }
   }
   ```

2. **Calendar Store Abstraction:**
   ```swift
   protocol CalendarStoreProtocol {
       func calendars(for entityType: EKEntityType) -> [EKCalendar]
       func events(matching predicate: NSPredicate) -> [EKEvent]
       func save(_ event: EKEvent, span: EKSpan) throws
   }

   class MockCalendarStore: CalendarStoreProtocol {
       // Implementation for testing
   }
   ```

### Test Data Management

1. **Standardized Test Fixtures:**
   ```swift
   struct TestFixtures {
       static let standardOwnerEmail = "owner@company.com"
       static let standard1on1Attendees = ["owner@company.com", "colleague@company.com"]
       static let teamMeetingAttendees = ["owner@company.com", "alice@company.com", "bob@company.com"]

       static func createStandardConfig() -> Configuration { /* ... */ }
       static func createComplex1on1Scenario() -> [EKEvent] { /* ... */ }
   }
   ```

2. **Date Handling:**
   ```swift
   extension Date {
       static var testBase: Date {
           Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 10))!
       }

       static var testWeekStart: Date {
           // Standardized test week start
       }
   }
   ```

### Test Organization

1. **File Structure:**
   ```
   Tests/CalSync1on1Tests/
   ├── Core/
   │   ├── MeetingAnalyzerTests.swift
   │   ├── EventFilterTests.swift
   │   └── EventMetadataTests.swift
   ├── Sync/
   │   ├── SyncManagerTests.swift
   │   └── CalendarManagerTests.swift
   ├── Integration/
   │   └── CalendarSyncIntegrationTests.swift
   ├── Utilities/
   │   ├── MockUtilities.swift
   │   ├── TestFixtures.swift
   │   └── TestExtensions.swift
   └── Existing/
       ├── CalSync1on1Tests.swift (existing)
       ├── ConfigurationLoadingTests.swift (existing)
       └── ...
   ```

2. **Naming Conventions:**
   - Test methods: `testSpecificFunctionality()`
   - Test cases: `testFunctionalityWithSpecificScenario()`
   - Helper methods: `createMockX()`, `setupTestScenario()`

### Performance Considerations

1. **Test Execution Speed:**
   - Keep individual tests under 100ms
   - Use lazy loading for expensive test data
   - Minimize file I/O in tests

2. **Memory Management:**
   - Clean up mock objects in `tearDown()`
   - Use weak references where appropriate
   - Avoid retaining large test data sets

### Error Testing Strategy

1. **Failure Scenarios to Test:**
   ```swift
   func testCalendarAccessDenied() {
       // Mock permission denial
       // Verify graceful degradation
   }

   func testMalformedEventData() {
       // Test with corrupted event properties
       // Verify error handling and logging
   }

   func testNetworkFailureRecovery() {
       // Mock calendar service failures
       // Test retry and fallback logic
   }
   ```

2. **Edge Cases:**
   - Empty event lists
   - Malformed attendee data
   - Timezone edge cases
   - Very large event sets (1000+ events)
   - Concurrent access scenarios

## Success Criteria

### Coverage Metrics
- **Target**: 85%+ line coverage for core business logic
- **Minimum**: 70%+ overall test coverage
- **Critical paths**: 100% coverage for sync operations

### Test Quality Metrics
- All tests run in under 30 seconds total
- No flaky tests (consistent pass/fail)
- All tests run completely offline
- No dependencies on external systems

### Functional Verification
- [x] All 1:1 meeting detection scenarios covered (MeetingAnalyzer tests)
- [x] Event filtering logic verified (EventFilter tests)
- [x] Metadata operations tested (EventMetadata tests)
- [ ] All sync operation paths tested
- [ ] Error handling verified for all critical operations
- [ ] Performance acceptable with realistic data sizes
- [ ] Integration flows work end-to-end

## Implementation Timeline

### Week 1: Foundation ✅ COMPLETED
- [x] Establish testing framework and basic test structure
- [x] Implement MeetingAnalyzer tests (comprehensive, refactored)
- [x] Implement EventFilter tests (complete coverage)
- [x] Add ANSI color coding for better error visibility
- [x] Refactor tests to be maintainable and table-driven

### Week 2: Core Operations 🔶 IN PROGRESS
- [ ] Implement SyncManager tests
- [x] Implement EventMetadata tests ✅ COMPLETED
- [ ] Implement CalendarManager tests
- [ ] Address mocking challenges

### Week 3: Integration & Polish
- [ ] Implement integration tests
- [ ] Performance testing
- [ ] Error scenario coverage
- [ ] Documentation and cleanup

## 🚀 NEXT STEPS FOR DEVELOPER

### Immediate Priorities (Week 2-3)

#### 1. Complete MeetingAnalyzer - `isOneOnOneMeeting()` Logic
**File**: `CalSync1on1/Sources/CalSync1on1/MeetingAnalyzer.swift`
**Status**: Function exists but core detection logic needs implementation
**Priority**: CRITICAL

**Missing Implementation:**
- Attendee count validation (exactly 2 people)
- Owner presence verification using `getOwnerEmails()`
- Email matching logic integration
- All-day event exclusion
- Recurring event analysis integration

**Test Coverage**: Already exists in `MeetingAnalyzerTests.swift` - use existing tests to validate implementation.

#### 2. SyncManager Tests - Core Sync Operations
**File**: `CalSync1on1/Tests/CalSync1on1Tests/SyncManagerTests.swift` (needs creation)
**Priority**: HIGH

**Focus Areas:**
- Event creation and updating logic
- Metadata handling during sync
- Dry run vs actual execution
- Error handling and recovery
- Orphaned event cleanup

#### 3. CalendarManager Tests - Event Operations
**File**: `CalSync1on1/Tests/CalSync1on1Tests/CalendarManagerTests.swift` (needs creation)
**Priority**: MEDIUM

**Focus Areas:**
- Event retrieval and calendar discovery
- Access validation and permissions
- Event creation and update operations
- Integration with existing event notes
- Synced event identification
- Metadata cleanup operations

### Implementation Approach

**✅ What's Working Well:**
- Table-driven tests provide excellent coverage and maintainability
- Simple, direct testing without over-engineered mocks
- Comprehensive edge case coverage
- Clear, readable test structure

**🎯 Continue This Approach:**
- Use real EventKit objects where possible
- Focus on business logic, not framework testing
- Prioritize practical scenarios over theoretical edge cases
- Keep tests simple and maintainable

**⚠️ Avoid:**
- Complex mocking infrastructure
- Testing framework code
- Over-engineering fixtures
- Tests that don't add real value

### Current Test Coverage Status

**✅ COMPLETED (High Quality):**
- MeetingAnalyzer: Email generation, parsing, matching logic
- EventFilter: All filtering scenarios and combinations
- EventMetadata: Complete metadata operations and JSON handling
- Configuration: Loading, validation, setup
- Command Line Args: All argument parsing

**🔶 NEXT PRIORITIES:**
- SyncManager: Core synchronization operations (HIGH)
- MeetingAnalyzer: Core 1:1 meeting detection logic (CRITICAL - implementation needed)
- CalendarManager: Event retrieval and calendar operations (MEDIUM)

**❌ TODO:**
- SyncManager: Core synchronization operations
- EventMetadata: JSON metadata handling
- CalendarManager: Basic calendar operations
- Integration: End-to-end sync flows

## Maintenance and Future Considerations

1. **Test Maintenance:**
   - Review and update tests when core logic changes
   - Keep tests simple and focused on business value

2. **CI/CD Integration:**
   - Run full test suite on every PR
   - Fail builds on test failures
   - Generate coverage reports
   - Performance regression detection

3. **Future Enhancements:**
   - Property-based testing for complex scenarios
   - Load testing with realistic calendar sizes
   - Cross-platform testing (if expanding beyond macOS)
   - Integration with calendar service testing tools

This test plan provides a solid foundation for improving CalSync1on1's test coverage while maintaining fast, reliable, offline tests that focus on the most critical functionality.
