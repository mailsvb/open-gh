import Foundation
import Testing
@testable import GHBar

@Suite struct WorkflowStatsTests {
  @Test func statsFromRunFixture() throws {
    let runs = try Fixture.decode("run_list", as: [GHRun].self)
    let stats = computeWorkflowStats(runs: runs)
    #expect(stats.totalRuns == 3)
    #expect(stats.successRate == 50)        // 1 of 2 completed
    #expect(stats.failCount == 1)           // timed_out counts as a failure
    #expect(stats.avgDuration == "4m 0s")   // (2m + 6m) / 2
  }

  @Test func noCompletedRunsHasNoRate() throws {
    let runs = try Fixture.decode("run_list", as: [GHRun].self).filter { $0.status != "completed" }
    #expect(computeWorkflowStats(runs: runs).successRate == nil)
  }

  @Test func durations() {
    #expect(formatDuration(seconds: -1) == "-")
    #expect(formatDuration(seconds: 42) == "42s")
    #expect(formatDuration(seconds: 135) == "2m 15s")
    #expect(formatDuration(seconds: 3_900) == "1h 5m")
  }

  @Test func relativeTimes() {
    let now = Date()
    #expect(relativeTime(from: now.addingTimeInterval(10), now: now) == "just now")
    #expect(relativeTime(from: now.addingTimeInterval(-30), now: now) == "30s ago")
    #expect(relativeTime(from: now.addingTimeInterval(-600), now: now) == "10m ago")
    #expect(relativeTime(from: now.addingTimeInterval(-7_200), now: now) == "2h ago")
    #expect(relativeTime(from: now.addingTimeInterval(-259_200), now: now) == "3d ago")
  }
}
