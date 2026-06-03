import Testing
import Foundation
@testable import Blop

@Suite("GitService")
struct GitServiceTests {

    // MARK: - Platform guard paths

    #if !os(macOS)
    @Test("isGitAvailable returns false on non-macOS platforms")
    func isGitAvailableNonMac() {
        #expect(GitService.isGitAvailable() == false)
    }

    @Test("initIfNeeded throws notSupported on non-macOS platforms")
    func initIfNeededNonMac() {
        let service = GitService()
        #expect(throws: GitError.notSupported) {
            try service.initIfNeeded(at: URL(fileURLWithPath: "/tmp"))
        }
    }

    @Test("stageAndCommit throws notSupported on non-macOS platforms")
    func stageAndCommitNonMac() {
        let service = GitService()
        #expect(throws: GitError.notSupported) {
            try service.stageAndCommit(at: URL(fileURLWithPath: "/tmp"), message: "test")
        }
    }
    #endif

    // MARK: - Error descriptions

    @Test("GitError.accessDenied has a non-nil errorDescription")
    func accessDeniedDescription() {
        #expect(GitError.accessDenied.errorDescription != nil)
    }

    @Test("GitError.initFailed embeds the output in its errorDescription")
    func initFailedDescription() {
        let desc = GitError.initFailed("fatal: not a repo").errorDescription
        #expect(desc?.contains("fatal: not a repo") == true)
    }

    @Test("GitError.stageFailed embeds the output in its errorDescription")
    func stageFailedDescription() {
        let desc = GitError.stageFailed("error: pathspec").errorDescription
        #expect(desc?.contains("error: pathspec") == true)
    }

    @Test("GitError.commitFailed embeds the output in its errorDescription")
    func commitFailedDescription() {
        let desc = GitError.commitFailed("nothing to commit").errorDescription
        #expect(desc?.contains("nothing to commit") == true)
    }

    @Test("GitError.notSupported has a non-nil errorDescription")
    func notSupportedDescription() {
        #expect(GitError.notSupported.errorDescription != nil)
    }
}
