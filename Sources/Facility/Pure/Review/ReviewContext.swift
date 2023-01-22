import Foundation
import Facility
extension Review {
  public struct Context {
    public var cfg: Configuration
    public var bots: Set<String>
    public var approvers: Set<String>
    public var users: [String: Gitlab.Storage.User]
    public var review: Review
    public var rules: Review.Rules
    public var storage: Review.Storage
    public var originalStorage: Review.Storage
    public var reports: [Report] = []
    public enum StateChange {
      case delete(UInt)
    }
    public mutating func makeState(merge: Json.GitlabMergeState) throws -> Storage.State? {
      guard merge.isClosed.not else {
        storage.delete(merge: merge)
        return nil
      }
      return try storage.states[merge.iid].get(.init(
        review: merge.iid,
        target: .make(name: merge.targetBranch),
        authors: [merge.author.username]
      ))
    }
    public mutating func apply(update: Update) {
      #warning("tbd")
    }
    public func isFirst(merge: Json.GitlabMergeState) -> Bool {
      #warning("tbd")
      return false
    }
    public static func make(
      cfg: Configuration,
      review: Review,
      rules: Review.Rules,
      storage: Review.Storage
    ) throws -> Self {
      let gitlab = try cfg.gitlab.get()
      let bots = try gitlab.storage.bots.union([gitlab.rest.get().user.username])
      let users = gitlab.storage.users
      return .init(
        cfg: cfg,
        bots: bots,
        approvers: Set(users.values.filter(\.active).map(\.login)).subtracting(bots),
        users: users,
        review: review,
        rules: rules,
        storage: storage,
        originalStorage: storage
      )
    }
  }
}