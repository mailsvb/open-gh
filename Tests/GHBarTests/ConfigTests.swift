import Foundation
import Testing
@testable import GHBar

@Suite struct ConfigTests {
  private func decode(_ json: String) throws -> AppConfig {
    try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
  }

  @Test func emptyObjectUsesDefaults() throws {
    let config = try decode("{}")
    #expect(config.orgs.isEmpty)
    #expect(config.includePersonal)
    #expect(config.username.isEmpty)
    #expect(config.pollingIntervalSeconds == AppConfig.default.pollingIntervalSeconds)
  }

  @Test func missingKeysKeepProvidedValues() throws {
    let config = try decode(#"{"orgs": ["acme"], "runsPerRepo": 3}"#)
    #expect(config.orgs == ["acme"])
    #expect(config.runsPerRepo == 3)
    #expect(config.maxReposPerOrg == AppConfig.default.maxReposPerOrg)
  }

  @Test func clampsInvalidNumbers() throws {
    let config = try decode(#"{"maxConcurrency": 0, "pollingIntervalSeconds": 1, "maxReposPerOrg": -4}"#)
    #expect(config.maxConcurrency == 1)
    #expect(config.pollingIntervalSeconds == 5)
    #expect(config.maxReposPerOrg == 1)
  }

  @Test func wrongTypeIsAnError() {
    #expect(throws: DecodingError.self) { try decode(#"{"orgs": "acme"}"#) }
  }

  @Test func personalSourceNeedsUsername() {
    var config = AppConfig.default
    config.orgs = ["acme"]
    #expect(config.allSources.map(\.name) == ["acme"])
    config.username = "octocat"
    #expect(config.allSources.map(\.displayName) == ["acme", "octocat (personal)"])
    config.includePersonal = false
    #expect(config.allSources.map(\.name) == ["acme"])
  }
}
