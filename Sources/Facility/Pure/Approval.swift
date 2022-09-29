import Foundation
import Facility
public struct Review {
  public let bot: String
  public let statuses: [UInt: Fusion.Approval.Status]
  public let state: Json.GitlabReviewState
  public let approvers: [String: Fusion.Approval.Approver]
  public let activeApprovers: Set<String>
  public let kind: Fusion.Kind
  public let ownage: [String: Criteria]
  public let rules: Fusion.Approval.Rules
  public let antagonists: [String: [String]]
  public private(set) var status: Fusion.Approval.Status
  public private(set) var diffTeams: Set<String> = []
  public private(set) var changes: [Git.Sha: Set<String>] = [:]
  public private(set) var breakers: [Git.Sha: Set<Git.Sha>] = [:]
  public private(set) var antagonistApprovers: Set<String> = []
  public private(set) var utilityTeams: Set<String> = []
  public private(set) var newTeams: Set<String> = []
  public private(set) var diffs: [String: [String]] = [:]
  public private(set) var isApproved: Bool = false
  public private(set) var presentTeams: [String: Fusion.Approval.Rules.Team] = [:]
  public struct Unapprovable {
    public var author: Bool = false
    public var teams: [String]? = nil
  }
  public var unapprovable: Unapprovable? {
    var result = Unapprovable()
    if status.review?.approves[status.author]?.resolution.approved != true {
      result.author = !activeApprovers.contains(status.author)
    }
    var teams: Set<String> = []
    let approvers = activeApprovers
      .union(status.review.map(\.approves).get([:]).filter(\.value.resolution.approved).keys)
    for name in diffTeams.union(utilityTeams).union(rules.emergency.array) {
      guard let team = rules.teams[name] else {
        teams.insert(name)
        continue
      }
      var unapprovers: Set<String> = []
      if !team.selfApproval { unapprovers = unapprovers.union([status.author]) }
      if !team.ignoreAntagonism { unapprovers = unapprovers.union(antagonistApprovers) }
      if team.quorum > team.required
        .union(team.optional)
        .union(team.reserve)
        .subtracting(unapprovers)
        .intersection(approvers)
        .count
      { teams.insert(name) }
    }
    result.teams = teams.isEmpty.else(teams.sorted())
    guard result.author || result.teams != nil else { return nil }
    return result
  }
  public init(
    gitlabCi: GitlabCi,
    statuses: [UInt: Fusion.Approval.Status],
    approvers: [String: Fusion.Approval.Approver],
    review: Json.GitlabReviewState,
    kind: Fusion.Kind,
    ownage: [String: Criteria],
    rules: Fusion.Approval.Rules,
    antagonists: [String: [String]]
  ) throws {
    self.bot = try gitlabCi.protected.get().user.username
    self.state = review
    self.statuses = statuses
    self.status = try statuses[review.iid].get { throw Thrown("No Status") }
    self.approvers = approvers
    self.activeApprovers = .init(approvers.filter(\.value.active).keys)
    self.kind = kind
    self.ownage = ownage
    self.rules = rules
    self.antagonists = antagonists
    self.antagonistApprovers = .init(antagonists[status.author].get([]))
  }
  public mutating func addDiff(files: [String]) {
    for (group, criteria) in ownage {
      if files.contains(where: criteria.isMet(_:)) { diffTeams.insert(group) }
    }
  }
  public mutating func addChanges(sha: Git.Sha, files: [String]) {
    var groups: Set<String> = []
    for (group, criteria) in ownage {
      if files.contains(where: criteria.isMet(_:)) { groups.insert(group) }
    }
    changes[sha] = groups
  }
  public mutating func addBreakers(sha: Git.Sha, commits: [String]) throws {
    breakers[sha] = try Set(commits.map(Git.Sha.init(value:)))
  }
  public mutating func setAuthor(user: String) throws {
    status.author = user
    antagonistApprovers = .init(antagonists[status.author].get([]))
    #warning("invalidate approvas")
  }
  public mutating func update(kind: Fusion.Kind) {
    #warning("tbd")
//    var review = state.status.review.get(.init(
//      randoms: randoms,
//      teams: state.changes.mapValues { $0.union(state.utilityTeams) },
//      approves: [:]
//    ))
//    return state
//    for (team, criteria) in self.rules.sourceBranch {
//      if criteria.isMet(review.sourceBranch) { utilityTeams.insert(team) }
//    }
//    for (team, criteria) in self.rules.targetBranch {
//      if criteria.isMet(review.targetBranch) { utilityTeams.insert(team) }
//    }
//    for (team, authors) in self.rules.authorship {
//      if authors.contains(status.author) { utilityTeams.insert(team) }
//    }
  }

  var randoms: Set<String> {
    #warning("tbd")
    var involved: Set<String> = []
    var count: Int = 0
    for team in diffTeams.union(utilityTeams).compactMap(team(_:)) {

      team.required.subtracting(involved)
    }
    return []
  }
  func team(_ name: String) -> Fusion.Approval.Rules.Team? {
    rules.teams[name]!
  }
  public struct Team {
    
  }
}
//public struct AwardApproval {
//  public var holdAward: String
//  public var sanityGroup: String
//  public var allGroups: [String: Group]
//  public var emergencyGroup: String?
//  public var sourceBranch: [String: Criteria]
//  public var targetBranch: [String: Criteria]
//  public var personal: [String: Set<String>]
//  public var statusLabel: String
//  public static func make(yaml: Yaml.AwardApproval) throws -> Self { try Self.init(
//    holdAward: yaml.holdAward,
//    sanityGroup: yaml.sanity,
//    allGroups: yaml.groups
//      .map(Group.make(name:yaml:))
//      .reduce(into: [:]) { $0[$1.name] = $1 },
//    emergencyGroup: yaml.emergency,
//    sourceBranch: yaml.sourceBranch
//      .get([:])
//      .mapValues(Criteria.init(yaml:)),
//    targetBranch: yaml.targetBranch
//      .get([:])
//      .mapValues(Criteria.init(yaml:)),
//    personal: yaml.personal
//      .get([:])
//      .mapValues(Set.init(_:)),
//    statusLabel: yaml.statusLabel
//  )}
//  public func get(group: String) throws -> Group {
//    try allGroups[group].get { throw Thrown("Group \(group) not configured") }
//  }
//  public struct Users {
//    public var bot: String
//    public var author: String
//    public var voiceless: Set<String>
//    public var holdables: Set<String>
//    public var coauthors: Set<String>
//    public var awarders: [String: Set<String>]
//    public init(
//      bot: String,
//      author: String,
//      participants: [String],
//      approval: AwardApproval,
//      awards: [Json.GitlabAward],
//      userActivity: [String: Bool]
//    ) throws {
//      self.bot = bot
//      self.author = author
//      self.coauthors = Set(participants).union([author])
//      let known = Set(userActivity.keys).union([bot])
//      self.voiceless = Set(userActivity.filter(\.value.not).keys).union([author, bot])
//      self.holdables = known
//        .subtracting(voiceless)
//        .union([author])
//        .subtracting([bot])
//      self.awarders = awards.reduce(into: [:]) { awarders, award in
//        awarders[award.name] = awarders[award.name].get([]).union([award.user.username])
//      }
//      let unknown = approval.allGroups.values
//        .reduce(into: coauthors) { unknown, group in
//          unknown.formUnion(group.required)
//          unknown.formUnion(group.optional)
//          unknown.formUnion(group.reserved)
//        }
//        .subtracting(known)
//        .joined(separator: ", ")
//      guard unknown.isEmpty else { throw Thrown("Not configured users: \(unknown)") }
//    }
//  }
//  public struct Groups {
//    public var emergency: Bool
//    public var cheaters: Set<String>
//    public var unhighlighted: Set<String> = []
//    public var unreported: [Group.Report] = []
//    public var unapproved: [Group.Report] = []
//    public var neededLabels: String
//    public var extraLabels: String
//    public var reportSuccess: Bool
//    public var holders: Set<String>
//    public init(
//      sourceBranch: String,
//      targetBranch: String,
//      labels: [String],
//      users: Users,
//      approval: AwardApproval,
//      sanityFiles: [String],
//      fileApproval: [String: Criteria],
//      changedFiles: [String]
//    ) throws {
//      let sanity = try fileApproval[approval.sanityGroup]
//        .get { throw Thrown("\(approval.sanityGroup) ownage not configured locally") }
//      try sanityFiles
//        .filter { !sanity.isMet($0) }
//        .forEach { throw Thrown("\($0) not in \(approval.sanityGroup)") }
//      let reported = Set(labels)
//      var involved: Set<String> = []
//      for (group, authors) in approval.personal
//      where !involved.contains(group) && authors.contains(users.author)
//      { involved.insert(group) }
//      for (group, criteria) in approval.targetBranch
//      where !involved.contains(group) && criteria.isMet(targetBranch)
//      { involved.insert(group) }
//      for (group, criteria) in approval.sourceBranch
//      where !involved.contains(group) && criteria.isMet(sourceBranch)
//      { involved.insert(group) }
//      for (group, criteria) in fileApproval
//      where !involved.contains(group) && changedFiles.contains(where: criteria.isMet(_:))
//      { involved.insert(group) }
//      if !users.awarders[approval.holdAward].get([]).contains(users.bot)
//      { unhighlighted.insert(approval.holdAward) }
//      for group in try involved.map(approval.get(group:)) {
//        if !users.awarders[group.award].get([]).contains(users.bot)
//        { unhighlighted.insert(group.award) }
//        if !reported.contains(group.name)
//        { unreported.append(.makeUnreported(group: group, users: users)) }
//        if try !group.isApproved(users: users)
//        { unapproved.append(.makeUnapproved(group: group, users: users)) }
//      }
//      if
//        let emergency = try approval.emergencyGroup.map(approval.get(group:)),
//        try emergency.isApproved(users: users)
//      {
//        let approvers = emergency.required
//          .union(emergency.optional)
//          .union(emergency.reserved)
//        self.emergency = true
//        if reported.contains(emergency.name) {
//          self.cheaters = []
//        } else {
//          self.cheaters = users.awarders[emergency.award]
//            .get([])
//            .intersection(approvers)
//            .subtracting(users.voiceless)
//        }
//        self.holders = users.awarders[approval.holdAward]
//          .get([])
//          .intersection(approvers)
//          .intersection(users.holdables)
//        involved.insert(emergency.name)
//      } else {
//        self.emergency = false
//        self.cheaters = []
//        self.holders = users.awarders[approval.holdAward]
//          .get([])
//          .intersection(users.holdables)
//      }
//      let isApproved = holders.isEmpty && (emergency || unapproved.isEmpty)
//      self.neededLabels = involved
//        .union(isApproved.then(approval.statusLabel).array)
//        .subtracting(reported)
//        .joined(separator: ",")
//      self.extraLabels = Set(approval.allGroups.keys)
//        .subtracting(involved)
//        .union(isApproved.else(approval.statusLabel).array)
//        .intersection(reported)
//        .joined(separator: ",")
//      self.reportSuccess = isApproved
//      && !reported.contains(approval.statusLabel)
//      && !involved.isEmpty
//    }
//  }
//  public struct Group {
//    public var name: String
//    public var award: String
//    public var quorum: Int
//    public var required: Set<String>
//    public var optional: Set<String>
//    public var reserved: Set<String>
//    public static func make(
//      name: String,
//      yaml: Yaml.AwardApproval.Group
//    ) throws -> Self { try .init(
//      name: name,
//      award: yaml.award,
//      quorum: (yaml.quorum > 0)
//        .then(yaml.quorum)
//        .get { throw Thrown("Zero quorum group: \(name)") },
//      required: .init(yaml.required.get([])),
//      optional: .init(yaml.optional.get([])),
//      reserved: .init(yaml.reserve.get([]))
//    )}
//    public func isApproved(users: Users) throws -> Bool {
//      guard quorum <= required.union(optional).union(reserved).subtracting(users.voiceless).count
//      else { throw Thrown("Unapprovable group: \(name)") }
//      let awarders = users.awarders[award].get([])
//      let required = required
//        .subtracting(users.voiceless)
//      guard awarders.isSuperset(of: required) else { return false }
//      var quote = quorum - required.count
//      guard quote > 0 else { return true }
//      let optional = optional
//        .subtracting(required)
//        .subtracting(users.voiceless)
//      quote -= optional.intersection(awarders).count
//      guard quote > 0 else { return true }
//      let reserved = reserved
//        .subtracting(required)
//        .subtracting(optional)
//        .subtracting(users.voiceless)
//      quote -= reserved.intersection(awarders).count
//      guard quote > 0 else { return true }
//      return false
//    }
//    public struct Report: Encodable {
//      public var name: String
//      public var award: String
//      public var required: [String]?
//      public var optional: [String]?
//      public var optionals: Int
//      public static func makeUnreported(group: Group, users: Users) -> Self {
//        let required = group.required.subtracting(users.voiceless)
//        let optionals = max(0, group.quorum - required.count)
//        var optional = group.optional
//          .subtracting(group.required)
//          .subtracting(users.voiceless)
//        if optional.count < optionals { optional = optional
//          .union(group.reserved)
//          .subtracting(group.required)
//          .subtracting(users.voiceless)
//        }
//        return .init(
//          name: group.name,
//          award: group.award,
//          required: required.isEmpty
//            .else(required)
//            .map(Array.init(_:)),
//          optional: (optionals == 0)
//            .else(optional)
//            .map(Array.init(_:)),
//          optionals: optionals
//        )
//      }
//      public static func makeUnapproved(group: Group, users: Users) -> Self {
//        var required = group.required.subtracting(users.voiceless)
//        var optionals = max(0, group.quorum - required.count)
//        let awarders = users.awarders[group.award].get([])
//        required = required.subtracting(awarders)
//        var optional = group.optional
//          .subtracting(group.required)
//          .subtracting(users.voiceless)
//        if optional.count < optionals { optional = optional
//          .union(group.reserved)
//          .subtracting(group.required)
//          .subtracting(users.voiceless)
//        }
//        optionals = max(0, optionals - optional.intersection(awarders).count)
//        optional = optional.subtracting(awarders)
//        return .init(
//          name: group.name,
//          award: group.award,
//          required: required.isEmpty
//            .else(required)
//            .map(Array.init(_:)),
//          optional: optional.isEmpty
//            .else(optional)
//            .map(Array.init(_:)),
//          optionals: optionals
//        )
//      }
//    }
//  }
//  public enum Mode {
//    case resolution
//    case replication
//    case integration
//  }
//}
