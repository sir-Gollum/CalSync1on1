import Foundation

class Logger {
    private let isVerbose: Bool

    // Shared instance for static methods
    static var shared = Logger()

    init(verbose: Bool = false) {
        isVerbose = verbose
    }

    // Static properties
    static var isVerbose: Bool {
        shared.isVerbose
    }

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

    // Instance methods
    func info(_ message: String) {
        print("[INFO]  \(message)")
    }

    func debug(_ message: String) {
        guard isVerbose else { return }
        print("[DEBUG] \(message)")
    }

    func error(_ message: String) {
        fputs("[ERROR] \(message)\n", stderr)
    }
}
