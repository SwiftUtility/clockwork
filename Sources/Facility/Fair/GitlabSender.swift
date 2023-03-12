import Foundation
import Facility
import FacilityPure
public final class GitlabSender: ContextGitlab {
  public let sh: Ctx.Sh
  public let git: Ctx.Git
  public let repo: Ctx.Repo
  public let gitlab: Ctx.Gitlab
  public init(ctx: ContextRepo) throws {
    self.sh = ctx.sh
    self.git = ctx.git
    self.repo = ctx.repo
    guard let cfg = try ctx.parseGitlab() else { throw Thrown("No gitlab in profile") }
    let apiEncoder = JSONEncoder()
    apiEncoder.keyEncodingStrategy = .convertToSnakeCase
    let apiDecoder = JSONDecoder()
    apiDecoder.keyDecodingStrategy = .convertFromSnakeCase
    let api = try ctx.sh.get(env: "CI_API_V4_URL")
    let token = try ctx.sh.get(env: "CI_JOB_TOKEN")
    let job = try Id
      .make(Execute.makeCurl(
        url: "\(api)/job",
        headers: ["Authorization: Bearer \(token)"],
        secrets: [token]
      ))
      .map(sh.execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabJob.self, apiDecoder.decode(_:from:))
      .get()
    self.gitlab = Ctx.Gitlab.make(
      cfg: cfg,
      api: api,
      token: token,
      current: job,
      apiEncoder: apiEncoder,
      apiDecoder: apiDecoder
    )
  }
  public func protected() throws -> Ctx.Gitlab.Protected {
    let rest = try parse(secret: gitlab.cfg.apiToken)
    let project = try Id
      .make(Execute.makeCurl(
        url: gitlab.project,
        headers: ["Authorization: Bearer \(rest)"],
        secrets: [rest]
      ))
      .map(sh.execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabProject.self, gitlab.apiDecoder.decode(_:from:))
      .get()
    return Ctx.Gitlab.Protected.make(rest: rest, project: project)
  }
}
