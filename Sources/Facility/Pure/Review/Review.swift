import Foundation
import Facility
public struct Review {
  public let bot: String
  public let approvers: [String: Gitlab.User]
  public let infusion: State.Infusion
  public let ownage: [String: Criteria]
  public let rules: Fusion.Approval.Rules
  public let haters: [String: Set<String>]
  public let blockers: [Report.ReviewUpdated.Blocker]
  public internal(set) var status: Fusion.Approval.Status
  public internal(set) var unknownUsers: Set<String> = []
  public internal(set) var unknownTeams: Set<String> = []
  public internal(set) var utilityTeams: Set<String> = []
  public internal(set) var changedTeams: [Git.Sha: Set<String>] = [:]
  public internal(set) var diffTeams: Set<String> = []
  public internal(set) var randomTeams: Set<String> = []
  public internal(set) var childCommits: [Git.Sha: Set<Git.Sha>] = [:]
  public var stoppers: [Report.ReviewStopped.Reason] {
    unknownUsers.isEmpty.else(.unknownUsers).array + unknownTeams.isEmpty.else(.unknownTeams).array
  }
  public static func make(
    bot: String,
    status: Fusion.Approval.Status,
    approvers: [String: Gitlab.User],
    review: Json.GitlabReviewState,
    infusion: State.Infusion,
    blockers: [Report.ReviewUpdated.Blocker],
    ownage: [String: Criteria],
    rules: Fusion.Approval.Rules,
    haters: [String: Set<String>]
  ) -> Self {
    var result = Self(
      bot: bot,
      approvers: approvers,
      infusion: infusion,
      ownage: ownage,
      rules: rules,
      haters: haters,
      blockers: blockers,
      status: status
    )
    result.status.makeApproves(infusion: infusion)
    result.resolveUnknown()
    result.resolveUtility()
    return result
  }
  mutating func resolveUnknown() {
    unknownUsers = status.authors
      .union(status.approves.keys)
      .union(haters.keys)
      .union(haters.flatMap(\.value))
      .union(rules.authorship.flatMap(\.value))
      .union(rules.teams.flatMap(\.value.approvers))
      .union(rules.teams.flatMap(\.value.random))
      .subtracting(approvers.keys)
    unknownTeams = Set(rules.sanity.array)
      .union(ownage.keys)
      .union(rules.targetBranch.keys)
      .union(rules.sourceBranch.keys)
      .union(rules.authorship.keys)
      .union(rules.randoms.keys)
      .union(rules.randoms.flatMap(\.value))
      .filter { rules.teams[$0] == nil }
  }
  mutating func resolveUtility() {
    let source = infusion.source.name
    let target = infusion.target.name
    let authorshipTeams = infusion.proposition
      .then(rules.authorship)
      .get([:])
      .filter({ $0.value.intersection(status.authors).isEmpty.not })
      .reduce(into: Set(), { $0.insert($1.key) })
    let sourceTeams = rules.sourceBranch.filter({ $0.value.isMet(source) }).keys
    let targetTeams = rules.targetBranch.filter({ $0.value.isMet(target) }).keys
    utilityTeams = authorshipTeams
      .union(sourceTeams)
      .union(targetTeams)
    if status.target != target {
      status.emergent = nil
      status.verified = nil
      status.invalidate(users: Set(targetTeams
        .flatMap({ rules.teams[$0].map(\.approvers).get([]) })
      ))
      status.target = target
    }
    if utilityTeams.subtracting(status.teams).isEmpty.not {
      status.verified = nil
    }
    status.blocked = blockers.isEmpty.not
  }
  public mutating func resolveOwnage(diff: [String]) {
    diffTeams = Set(ownage.filter({ diff.contains(where: $0.value.isMet(_:)) }).keys)
    status.teams = diffTeams.union(utilityTeams)
    guard infusion.proposition else { return }
    randomTeams = rules.randoms
      .filter({ $0.value.intersection(status.teams).isEmpty.not })
      .reduce(into: [], { $0.insert($1.key) })
    status.teams.formUnion(randomTeams)
  }
  public mutating func addBreakers(sha: Git.Sha, commits: [Git.Sha]) {
    childCommits[sha] = Set(commits)
  }
  public mutating func addChanges(sha: Git.Sha, diff: [String]) {
    guard diff.isEmpty.not else { return }
    let teams = diffTeams.filter({ ownage[$0]
      .map({ diff.contains(where: $0.isMet(_:)) })
      .get(false)
    })
    if status.skip.contains(sha) {
      if let sanity = rules.sanity.flatMap({ rules.teams[$0]?.name }), teams.contains(sanity) {
        changedTeams[sha] = [sanity]
      }
    } else {
      changedTeams[sha] = teams
    }
  }
  public mutating func squashApproves(sha: Git.Sha) {
    for user in status.approves.keys { status.approves[user]?.commit = sha }
    if status.emergent != nil { status.emergent = sha }
    if status.verified != nil { status.verified = sha }
  }
  public mutating func resolveApproval(sha: Git.Sha) -> Approval {
    if let emergent = status.emergent { status.emergent = childCommits[emergent]
      .get([])
      .filter({ changedTeams[$0] != nil })
      .isEmpty
      .then(sha)
    }
    let fragilUtility = rules.teams.keys
      .filter(utilityTeams.contains(_:))
      .compactMap({ rules.teams[$0] })
      .filter(\.advanceApproval.not)
      .reduce(into: Set(), { $0.formUnion($1.approvers) })
    let fragilRandoms = rules.teams.keys
      .filter(randomTeams.contains(_:))
      .compactMap({ rules.teams[$0] })
      .filter(\.advanceApproval.not)
      .reduce(into: Set(), { $0.formUnion($1.random) })
      .intersection(status.randoms)
    let fragilUsers = status.authors
      .union(fragilUtility)
      .union(fragilRandoms)
      .union(status.approves.filter(\.value.resolution.fragil).keys)
    let fragilDiffApprovers = diffTeams
      .compactMap({ rules.teams[$0] })
      .filter(\.advanceApproval.not)
      .reduce(into: [:], { $0[$1.name] = $1.approvers })
    for (sha, childs) in childCommits {
      let breakers = childs.compactMap({ changedTeams[$0] })
      guard breakers.isEmpty.not else { continue }
      let approvers = status.approves.values
        .filter({ $0.commit == sha && $0.resolution.approved })
        .map(\.approver)
      status.invalidate(users: breakers
        .reduce(into: Set(), { $0.formUnion($1) })
        .compactMap({ fragilDiffApprovers[$0] })
        .reduce(into: fragilUsers, { $0.formUnion($1) })
        .intersection(approvers)
      )
    }
    let active = Set(approvers.filter(\.value.active).keys)
    let approved = Set(status.approves.filter(\.value.resolution.approved).keys)
    let yetActive = active.union(approved)
    var legates = utilityTeams.union(diffTeams).compactMap({ rules.teams[$0] })
    for index in legates.indices {
      legates[index].update(isRandom: false)
      legates[index].update(active: yetActive)
      if infusion.proposition { legates[index].update(exclude: status.authors) }
    }
    status.legates = legates
      .reduce(into: Set(), { $0.formUnion($1.approvers) })
      .intersection(status.legates)
    let haters = Set(haters.filter({ $0.value.intersection(status.authors).isEmpty.not }).keys)
    var randoms = randomTeams.compactMap({ rules.teams[$0] })
    for index in randoms.indices {
      randoms[index].update(isRandom: true)
      randoms[index].update(active: yetActive)
      randoms[index].update(exclude: status.authors)
      randoms[index].update(exclude: haters)
    }
    status.randoms = randoms
      .reduce(into: Set(), { $0.formUnion($1.random) })
      .intersection(status.randoms)
    var involved = status.legates.union(status.randoms)
    if infusion.proposition.not { involved.formUnion(status.authors) }
    var users = legates.reduce(into: Set(), { $0.formUnion($1.required) })
    status.legates.formUnion(users)
    involved.formUnion(users)
    legates.indices.forEach({ legates[$0].update(involved: involved) })
    users = legates.reduce(into: Set(), { $0.formUnion($1.necessary) })
    status.legates.formUnion(users)
    involved.formUnion(users)
    legates.indices.forEach({ legates[$0].update(involved: involved) })
    users = legates.reduce(into: Set(), { $0.formUnion($1.approvers) })
    users = selectUsers(teams: &legates, involved: &involved, users: users)
    status.legates.formUnion(users)
    involved = status.randoms
    for index in randoms.indices {
      randoms[index].update(exclude: status.legates)
      randoms[index].update(involved: involved)
    }
    status.randoms.formUnion(selectUsers(
      teams: &randoms,
      involved: &involved,
      users: randoms.reduce(into: Set(), { $0.formUnion($1.random) })
    ))
    var result = Approval()
    result.blockers = blockers
    result.orphaned = status.authors.isDisjoint(with: yetActive)
    result.unapprovable = legates
      .filter({ $0.quorum > 0 })
      .reduce(into: Set(), { $0.insert($1.name) })
    result.addLabels = status.teams
      .compactMap({ rules.teams[$0] })
      .reduce(into: Set(), { $0.formUnion($1.labels) })
    result.delLabels = rules.teams
      .reduce(into: Set(), { $0.formUnion($1.value.labels) })
      .subtracting(result.addLabels)
    result.holders = status.authors
      .subtracting(approved)
      .union(status.approves.filter(\.value.resolution.block).keys)
      .intersection(active)
    result.slackers = status.legates
      .union(status.randoms)
      .subtracting(status.approves.keys)
    result.approvers = status.legates
      .union(status.randoms)
      .intersection(approved)
    result.outdaters = status.legates
      .union(status.randoms)
      .compactMap({ status.approves[$0] })
      .filter(\.resolution.outdated)
      .map({ [$0.commit.value: Set([$0.approver])] })
      .reduce(into: [:], { $0.merge($1, uniquingKeysWith: { $0.union($1) }) })
    status.verified = (
      result.unapprovable.isEmpty
      && result.blockers.isEmpty
      && result.orphaned.not
    ).then(sha)
    if result.blockers.isEmpty.not { result.state = .blocked }
    else if status.emergent != nil { result.state = .emergent }
    else if status.verified == nil { result.state = .unapprovable }
    else if result.slackers.isEmpty.not { result.state = .slackers }
    else if result.outdaters.isEmpty.not { result.state = .outdaters }
    else if result.holders.isEmpty.not { result.state = result.holders
      .isSubset(of: status.authors)
      .then(.authors)
      .get(.holders)
    } else { result.state = .approved }
    return result
  }
  func selectUsers(
    teams: inout [Fusion.Approval.Rules.Team],
    involved: inout Set<String>,
    users: Set<String>
  ) -> Set<String> {
    var left = users
    while true {
      var weights: [String: Int] = [:]
      for user in left {
        let count = teams.filter({ $0.isNeeded(user: user) }).count
        if count > 0 { weights[user] = count * rules.weights[user].get(rules.baseWeight) }
      }
      guard let user = random(weights: weights) else { return users.subtracting(left) }
      left.remove(user)
      involved.insert(user)
      teams.indices.forEach({ teams[$0].update(involved: involved) })
    }
  }
  func random(weights: [String: Int]) -> String? {
    var acc = weights.map(\.value).reduce(0, +)
    guard acc > 0 else { return weights.keys.randomElement() }
    acc = Int.random(in: 0 ..< acc)
    return weights.keys.first(where: {
      acc -= weights[$0].get(0)
      return acc < 0
    })
  }
  public func isApproved(state: Json.GitlabReviewState) -> Bool {
    guard status.blocked.not else { return false }
    guard status.target == state.targetBranch else { return false }
    guard status.emergent?.value != state.lastPipeline.sha else { return true }
    guard status.verified?.value == state.lastPipeline.sha else { return false }
    let active = Set(approvers.filter(\.value.active).keys)
    guard active.intersection(status.approves.filter(\.value.resolution.block).keys).isEmpty
    else { return false }
    return status.authors
      .intersection(active)
      .union(status.randoms)
      .union(status.legates)
      .subtracting(status.approves.filter(\.value.resolution.approved).keys)
      .isEmpty
  }
  public var watchers: [String]? {
    let result = approvers.values
      .filter(\.active)
      .filter(status.isWatched(by:))
      .reduce(into: Set(), { $0.insert($1.login) })
    return result.isEmpty.else(result.sorted())
  }
  public var accepters: [String]? {
    guard status.verified != nil else { return [] }
    let result = status.legates
      .union(status.randoms)
      .intersection(status.approves.filter(\.value.resolution.approved).keys)
    return result.isEmpty.else(result.sorted())
  }
  public struct Approval {
    public var orphaned: Bool = false
    public var unapprovable: Set<String> = []
    public var addLabels: Set<String> = []
    public var delLabels: Set<String> = []
    public var holders: Set<String> = []
    public var slackers: Set<String> = []
    public var outdaters: [String: Set<String>] = [:]
    public var approvers: Set<String> = []
    public var blockers: [Report.ReviewUpdated.Blocker] = []
    public var state: State = .approved
    public enum State: String, Encodable {
      case blocked
      case emergent
      case unapprovable
      case slackers
      case outdaters
      case holders
      case authors
      case approved
      public var isApproved: Bool {
        switch self {
        case .emergent, .approved: return true
        default: return false
        }
      }
    }
  }
}