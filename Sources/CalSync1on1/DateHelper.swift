import Foundation

class DateHelper {
    private let calendar = Calendar.current
    private let configuration: Configuration?

    init(configuration: Configuration? = nil) {
        self.configuration = configuration
    }

    func getCurrentWeekStart() -> Date {
        let now = Date()
        let startOffset = configuration?.syncWindow.startOffset ?? 0

        let offsetDate = calendar.date(byAdding: .weekOfYear, value: startOffset, to: now) ?? now
        let weekday = calendar.component(.weekday, from: offsetDate)
        let daysFromMonday = (weekday + 5) % 7 // Convert Sunday=1 to Monday=0

        let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: offsetDate) ?? offsetDate
        return calendar.startOfDay(for: startOfWeek)
    }

    func getDateTwoWeeksFromNow() -> Date {
        let startOfWeek = getCurrentWeekStart()
        let weeks = configuration?.syncWindow.weeks ?? 2
        return calendar.date(byAdding: .weekOfYear, value: weeks, to: startOfWeek) ?? Date()
    }

    func getSyncEndDate() -> Date {
        return getDateTwoWeeksFromNow()
    }

    func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
