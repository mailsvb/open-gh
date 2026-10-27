import Foundation
import Testing
@testable import GHBar

@Suite struct StatusParsingTests {
  @Test(arguments: [
    ("completed", "success", RunStatus.success),
    ("completed", "failure", .failure),
    ("completed", "timed_out", .failure),
    ("completed", "startup_failure", .failure),
    ("completed", "action_required", .failure),
    ("completed", "cancelled", .cancelled),
    ("completed", "skipped", .cancelled),
    ("in_progress", "", .inProgress),
    ("queued", "", .queued),
    ("waiting", "", .queued),
    ("requested", "", .queued),
    ("pending", "", .queued),
    ("something_new", "", .unknown),
  ])
  func runStatus(status: String, conclusion: String, expected: RunStatus) {
    #expect(parseRunStatus(status: status, conclusion: conclusion) == expected)
  }

  @Test func combinedStatusPrefersWorst() {
    #expect(combinedStatus([]) == .unknown)
    #expect(combinedStatus([.success, .success]) == .success)
    #expect(combinedStatus([.success, .queued]) == .queued)
    #expect(combinedStatus([.queued, .inProgress]) == .inProgress)
    #expect(combinedStatus([.inProgress, .failure, .success]) == .failure)
    #expect(combinedStatus([.success, .cancelled]) == .unknown)
  }

  @Test func pullRequestFixtureDecodesAndRollsUp() throws {
    let prs = try Fixture.decode("pr_list", as: [GHPullRequest].self)
    let statuses = Dictionary(uniqueKeysWithValues: prs.map { ($0.number, checksOverallStatus($0.statusCheckRollup)) })
    #expect(statuses[101] == .success)      // SKIPPED counts as passing
    #expect(statuses[102] == .inProgress)   // StatusContext PENDING
    #expect(statuses[103] == .failure)      // TIMED_OUT beats IN_PROGRESS
    #expect(statuses[104] == .unknown)      // no checks
  }

  @Test func reviewDecision() {
    #expect(parseReviewStatus("APPROVED") == .approved)
    #expect(parseReviewStatus("CHANGES_REQUESTED") == .changesRequested)
    #expect(parseReviewStatus("REVIEW_REQUIRED") == .reviewRequired)
    #expect(parseReviewStatus("") == ReviewStatus.none)
  }
}
