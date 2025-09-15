import Foundation

enum Logger {

    // MARK: - Static Properties

    private nonisolated(unsafe) static var _isVerbose = false

    // MARK: - Static Computed Properties

    static var isVerbose: Bool {
        _isVerbose
    }

    // MARK: - Static Functions

    static func configure(verbose: Bool) {
        _isVerbose = verbose
    }

    static func info(_ message: String) {
        print("[INFO]  \(message)")
    }

    static func debug(_ message: String) {
        guard _isVerbose else { return }
        print("[DEBUG] \(message)")
    }

    static func error(_ message: String) {
        fputs("\u{001B}[31m[ERROR] \(message)\u{001B}[0m\n", stderr)
    }
}
