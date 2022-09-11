import Foundation
import Facility
public struct Fusion {
  public var queue: Configuration.Asset
  public var targets: Criteria
  public var approval: Approval?
  public var proposition: Proposition
  public var replication: Replication
  public var integration: Integration
  public var createMergeCommitMessage: Configuration.Template

  func createCommitMessage(kind: Kind) -> Configuration.Template {
    switch kind {
    case .proposition: return proposition.createCommitMessage
    case .replication: return replication.createCommitMessage
    case .integration: return integration.createCommitMessage
    }
  }
  public func makeKind(supply: String) throws -> Kind {
    guard replication.prefix != integration.prefix else {
      throw Thrown("Prefix for replication and integration must be different")
    }
    guard let merge = try Merge.make(supply: supply) else {
      let rules = proposition.rules.filter { $0.source.isMet(supply) }
      guard rules.count < 2 else { throw Thrown("\(supply) matches multiple proposition rules") }
      return .proposition(rules.first)
    }
    if merge.prefix == replication.prefix { return .replication(merge) }
    if merge.prefix == integration.prefix { return .integration(merge) }
    throw Thrown("\(supply) prefix not configured")
  }
  public static func make(
    yaml: Yaml.Fusion
  ) throws -> Self { try .init(
    queue: .make(yaml: yaml.queue),
    targets: .init(yaml: yaml.targets),
    approval: yaml.approval.map(Approval.make(yaml:)),
    proposition: .init(
      createCommitMessage: .make(yaml: yaml.proposition.createCommitMessage),
      rules: yaml.proposition.rules
        .map { yaml in try .init(
          title: .init(yaml: yaml.title),
          source: .init(yaml: yaml.source)
        )}
    ),
    replication: .init(
      target: yaml.replication.target,
      prefix: yaml.replication.prefix,
      source: .init(yaml: yaml.replication.source),
      createCommitMessage: .make(yaml: yaml.replication.createCommitMessage)
    ),
    integration: .init(
      rules: yaml.integration.rules
        .map { yaml in try .init(
          source: .init(yaml: yaml.source),
          target: .init(yaml: yaml.target)
        )},
      prefix: yaml.integration.prefix,
      createCommitMessage: .make(yaml: yaml.integration.createCommitMessage),
      exportAvailableTargets: .make(yaml: yaml.integration.exportAvailableTargets)
    ),
    createMergeCommitMessage: .make(yaml: yaml.createMergeCommitMessage)
  )}
  public enum Kind {
    case proposition(Proposition.Rule?)
    case replication(Merge)
    case integration(Merge)
    public var merge: Merge? {
      switch self {
      case .proposition: return nil
      case .replication(let merge), .integration(let merge): return merge
      }
    }
  }
  public struct Proposition {
    public var createCommitMessage: Configuration.Template
    public var rules: [Rule]
    public struct Rule {
      public var title: Criteria
      public var source: Criteria
    }
  }
  public struct Replication {
    public var target: String
    public var prefix: String
    public var source: Criteria
    public var createCommitMessage: Configuration.Template
    public func makeMerge(source: String, fork: String) throws -> Merge { try .make(
      fork: .init(value: fork),
      prefix: prefix,
      source: .init(name: source),
      target: .init(name: target)
    )}
  }
  public struct Integration {
    public var rules: [Rule]
    public var prefix: String
    public var createCommitMessage: Configuration.Template
    public var exportAvailableTargets: Configuration.Template
    public func makeMerge(target: String, source: String, fork: String) throws -> Merge { try .make(
      fork: .init(value: fork),
      prefix: prefix,
      source: .init(name: source),
      target: .init(name: target)
    )}
    public struct Rule {
      public var source: Criteria
      public var target: Criteria
    }
  }
  public struct Merge {
    public let fork: Git.Sha
    public let prefix: String
    public let source: Git.Branch
    public let target: Git.Branch
    public let supply: Git.Branch
    public func changing(fork: String) throws -> Self { try .make(
      fork: .init(value: fork),
      prefix: prefix,
      source: source,
      target: target
    )}
    public static func make(
      fork: Git.Sha,
      prefix: String,
      source: Git.Branch,
      target: Git.Branch
    ) throws -> Self { try .init(
      fork: fork,
      prefix: prefix,
      source: source,
      target: target,
      supply: .init(name: "\(prefix)/-/\(target)/-/\(source)/-/\(fork)")
    )}
    public static func make(supply: String) throws -> Self? {
      let components = supply.components(separatedBy: "/-/")
      guard components.count == 4 else { return nil }
      return try .init(
        fork: .init(value: components[3]),
        prefix: components[0],
        source: .init(name: components[2]),
        target: .init(name: components[1]),
        supply: .init(name: supply)
      )
    }
  }
  public struct Queue {
    public private(set) var queue: [String: [UInt]]
    public private(set) var isChanged: Bool = false
    public private(set) var notifiables: Set<UInt> = []
    public var yaml: String {
      var result: String = ""
      for target in queue.keys.sorted() {
        guard let reviews = queue[target], !reviews.isEmpty else { continue }
        result += "'\(target)':\n"
        for review in reviews { result += "- \(review)\n" }
      }
      return result.isEmpty.else(result).get("{}\n")
    }
    public mutating func enqueue(review: UInt, target: String?) -> Bool {
      var result = false
      for (key, value) in queue {
        if key == target {
          guard !value.contains(where: { $0 == review }) else {
            result = value.first == review
            continue
          }
          queue[key] = value + [review]
          isChanged = true
          if queue[key]?.first == review { notifiables.insert(review) }
        } else {
          let targets = value.filter { $0 != review }
          guard value.count != targets.count else { continue }
          queue[key] = targets.isEmpty.else(targets)
          isChanged = true
          if let first = targets.first, first != value.first { notifiables.insert(first) }
        }
      }
      if let target = target, queue[target] == nil {
        queue[target] = [review]
        isChanged = true
        notifiables.insert(review)
      }
      return result
    }
    public static func make(queue: [String: [UInt]]) -> Self { .init(queue: queue) }
    public struct Resolve: Query {
      public var cfg: Configuration
      public var fusion: Fusion
      public init(
        cfg: Configuration,
        fusion: Fusion
      ) {
        self.cfg = cfg
        self.fusion = fusion
      }
      public typealias Reply = Fusion.Queue
    }
    public struct Persist: Query {
      public var cfg: Configuration
      public var pushUrl: String
      public var fusion: Fusion
      public var reviewQueue: Fusion.Queue
      public var review: Json.GitlabReviewState
      public var queued: Bool
      public init(
        cfg: Configuration,
        pushUrl: String,
        fusion: Fusion,
        reviewQueue: Fusion.Queue,
        review: Json.GitlabReviewState,
        queued: Bool
      ) {
        self.cfg = cfg
        self.pushUrl = pushUrl
        self.fusion = fusion
        self.reviewQueue = reviewQueue
        self.review = review
        self.queued = queued
      }
      public typealias Reply = Void
    }
  }
  public struct Approval {
    public var thread: Configuration.Thread
    public var sanityTeam: String
    public var emergencyTeam: String
    public var sourceBranch: [String: Criteria]
    public var targetBranch: [String: Criteria]
    public var teams: Git.File
    public var approves: Configuration.Asset
    public var activity: Configuration.Asset
    public static func make(yaml: Yaml.Fusion.Approval) throws -> Self { try .init(
      thread: .make(yaml: yaml.thread),
      sanityTeam: yaml.sanityTeam,
      emergencyTeam: yaml.emergencyTeam,
      sourceBranch: yaml.sourceBranch
        .get([:])
        .mapValues(Criteria.init(yaml:)),
      targetBranch: yaml.targetBranch
        .get([:])
        .mapValues(Criteria.init(yaml:)),
      teams: .make(preset: yaml.teams),
      approves: .make(yaml: yaml.approves),
      activity: .make(yaml: yaml.activity)
    )}
    public struct Team {
      public var quorum: Int
      public var random: UInt
      public var fragile: Bool
      public var selfish: Bool
      public var reserve: [String]
      public var optional: [String]
      public var required: [String]
      public var authors: [String]
      public static func make(yaml: Yaml.Fusion.Approval.Team) -> Self { .init(
        quorum: yaml.quorum,
        random: yaml.random.get(0),
        fragile: yaml.fragile,
        selfish: yaml.selfish,
        reserve: yaml.reserve.get([]),
        optional: yaml.optional.get([]),
        required: yaml.required.get([]),
        authors: yaml.authors.get([])
      )}
    }
    public struct Approve {
      public var thread: String
      public var commit: Git.Sha
      public var holders: [String]
      public var feed: [String: [String: Bool]]
      public static func make(yaml: Yaml.Fusion.Approval.Approve) throws -> Self { try .init(
        thread: yaml.thread,
        commit: .init(value: yaml.commit),
        holders: yaml.holders.get([]),
        feed: yaml.feed.get([:])
      )}
    }
  }
}
