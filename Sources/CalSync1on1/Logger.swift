import Foundation

class Logger {
    let isVerbose: Bool

    init(verbose: Bool = false) {
        isVerbose = verbose
    }

    func info(_ message: String) {
        print(message)
    }

    func debug(_ message: String) {
        guard isVerbose else { return }
        print(message)
    }

    func error(_ message: String) {
        fputs("❌ \(message)\n", stderr)
    }
}
