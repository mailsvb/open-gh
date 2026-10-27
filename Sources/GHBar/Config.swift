import Foundation

struct AppConfig: Codable, Sendable {
  var orgs: [String]
  var includePersonal: Bool
  var username: String          // empty → resolved from `gh api user` at runtime
  var pollingIntervalSeconds: Int
  var maxReposPerOrg: Int
  var runsPerRepo: Int
  var activeRepoRunsLimit: Int
  var maxConcurrency: Int

  static let `default` = AppConfig(
    orgs: [],
    includePersonal: true,
    username: "",
    pollingIntervalSeconds: 30,
    maxReposPerOrg: 25,
    runsPerRepo: 8,
    activeRepoRunsLimit: 25,
    maxConcurrency: 8
  )

  static let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ghbar")
  static let configFile = configDir.appendingPathComponent("config.json")

  /// Loads the config, writing a default file only when none exists.
  /// A file that fails to parse is left untouched and its error returned.
  static func load() -> (config: AppConfig, error: String?) {
    guard FileManager.default.fileExists(atPath: configFile.path) else {
      let config = AppConfig.default
      config.save()
      return (config, nil)
    }
    do {
      let data = try Data(contentsOf: configFile)
      return (try JSONDecoder().decode(AppConfig.self, from: data), nil)
    } catch {
      return (.default, "Could not read \(configFile.path), using defaults: \(error.localizedDescription)")
    }
  }

  func save() {
    try? FileManager.default.createDirectory(at: Self.configDir, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(self) {
      try? data.write(to: Self.configFile)
    }
  }

  /// All fetchable sources: orgs + optional personal
  var allSources: [OrgSource] {
    var sources = orgs.map { OrgSource(name: $0, kind: .org) }
    if includePersonal && !username.isEmpty {
      sources.append(OrgSource(name: username, kind: .personal))
    }
    return sources
  }
}

// Declared in an extension so the memberwise initializer is kept.
extension AppConfig {
  /// Missing keys fall back to defaults instead of failing the whole file.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = AppConfig.default
    orgs = try c.decodeIfPresent([String].self, forKey: .orgs) ?? d.orgs
    includePersonal = try c.decodeIfPresent(Bool.self, forKey: .includePersonal) ?? d.includePersonal
    username = try c.decodeIfPresent(String.self, forKey: .username) ?? d.username
    pollingIntervalSeconds = max(5, try c.decodeIfPresent(Int.self, forKey: .pollingIntervalSeconds) ?? d.pollingIntervalSeconds)
    maxReposPerOrg = max(1, try c.decodeIfPresent(Int.self, forKey: .maxReposPerOrg) ?? d.maxReposPerOrg)
    runsPerRepo = max(1, try c.decodeIfPresent(Int.self, forKey: .runsPerRepo) ?? d.runsPerRepo)
    activeRepoRunsLimit = try c.decodeIfPresent(Int.self, forKey: .activeRepoRunsLimit) ?? d.activeRepoRunsLimit
    maxConcurrency = max(1, try c.decodeIfPresent(Int.self, forKey: .maxConcurrency) ?? d.maxConcurrency)
  }
}

struct OrgSource: Hashable, Identifiable, Sendable {
  let name: String
  let kind: SourceKind
  var id: String { name }

  var displayName: String {
    switch kind {
    case .org: return name
    case .personal: return "\(name) (personal)"
    }
  }

  enum SourceKind: Hashable, Sendable {
    case org, personal
  }
}
