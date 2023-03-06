import Foundation
import Facility
public extension Ctx.Sh {
  func gitTopLevel(path: Ctx.Sys.Absolute) throws -> Ctx.Sys.Absolute { try Id
    .make(Execute(tasks: [.init(
      environment: env,
      arguments: ["git", "-C", path.value, "rev-parse", "--show-toplevel"],
      secrets: []
    )]))
    .map(execute)
    .map(Execute.parseText(reply:))
    .map(Ctx.Sys.Absolute.make(value:))
    .get()
  }
  func updateLfs(git: inout Ctx.Git) throws {
    git.lfs = try Id
    .make(Execute(tasks: [.init(
      environment: env,
      arguments: ["git", "-C", git.root.value, "lfs", "update"],
      secrets: []
    )]))
    .map(execute)
    .map(Execute.parseSuccess(reply:))
    .get()
  }
  func getSha(git: Ctx.Git, ref: Ctx.Git.Ref) throws -> Ctx.Git.Sha { try Id
    .make(Execute(tasks: [.init(
      environment: env,
      arguments: ["git", "-C", git.root.value, "rev-parse", ref.value],
      secrets: []
    )]))
    .map(execute)
    .map(Execute.parseText(reply:))
    .map(Ctx.Git.Sha.make(value:))
    .get()
  }
  func getCurrentBranch(git: Ctx.Git) throws -> Ctx.Git.Branch? {
    let name = try Id
      .make(Execute(tasks: [.init(
        environment: env,
        arguments: ["git", "-C", git.root.value, "branch", "--show-current"],
        secrets: []
      )]))
      .map(execute)
      .map(Execute.parseText(reply:))
      .get()
    return try name.isEmpty.not
      .then(name)
      .map(Ctx.Git.Branch.make(name:))
  }
}