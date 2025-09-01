import Foundation

class Logger {

    // MARK: - Static Properties

    // Shared instance for static methods
    static var shared = Logger()

    // MARK: - Static Computed Properties

    // Static properties
    static var isVerbose: Bool {
        shared.isVerbose
    }

    // MARK: - Properties

    private let isVerbose: Bool

    // MARK: - Lifecycle

    init(verbose: Bool = false) {
        isVerbose = verbose
    }

    // MARK: - Static Functions

    // Static methods that delegate to shared instance
    static func info(_ message: String) {
        shared.info(message)
    }

    static func debug(_ message: String) {
        shared.debug(message)
    }

    static func error(_ message: String) {
        shared.error(message)
    }

    // Configure the shared logger
    static func configure(verbose: Bool) {
        shared = Logger(verbose: verbose)
    }

    // MARK: - Functions

    // Instance methods
    func info(_ message: String) {
        print("[INFO]  \(message)")
    }

    func debug(_ message: String) {
        guard isVerbose else { return }
        print("[DEBUG] \(message)")
    }

    func error(_ message: String) {
        fputs("\u{001B}[31m[ERROR] \(message)\u{001B}[0m\n", stderr)
    }
}
