import Foundation

final class GitService {

    static func isGitAvailable() -> Bool {
        #if os(macOS)
        return run(["which", "git"]).exitCode == 0
        #else
        return false
        #endif
    }

    func initIfNeeded(at url: URL) throws {
        #if os(macOS)
        let gitDir = url.appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitDir.path) { return }
        let result = Self.run(["git", "init", url.path])
        if result.exitCode != 0 {
            throw GitError.initFailed(result.output)
        }
        #else
        throw GitError.notSupported
        #endif
    }

    func stageAndCommit(at url: URL, message: String) throws {
        #if os(macOS)
        guard url.startAccessingSecurityScopedResource() else {
            throw GitError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        var result = Self.run(["git", "-C", url.path, "add", "-A"])
        if result.exitCode != 0 {
            throw GitError.stageFailed(result.output)
        }

        result = Self.run(["git", "-C", url.path, "commit", "-m", message])
        if result.exitCode != 0 && !result.output.contains("nothing to commit") {
            throw GitError.commitFailed(result.output)
        }
        #else
        throw GitError.notSupported
        #endif
    }

    #if os(macOS)
    @discardableResult
    private static func run(_ args: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (-1, error.localizedDescription)
        }
    }
    #endif
}

enum GitError: LocalizedError {
    case accessDenied
    case initFailed(String)
    case stageFailed(String)
    case commitFailed(String)
    case notSupported

    var errorDescription: String? {
        switch self {
        case .accessDenied:           return "Could not access the git repository directory."
        case .initFailed(let out):    return "git init failed: \(out)"
        case .stageFailed(let out):   return "git add failed: \(out)"
        case .commitFailed(let out):  return "git commit failed: \(out)"
        case .notSupported:           return "Git backup is only available on Mac."
        }
    }
}
