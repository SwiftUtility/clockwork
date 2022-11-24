import Foundation
import Facility
public struct Gitlab {
  public var env: Env
  public let job: Json.GitlabJob
  public var api: String
  public var trigger: Yaml.Gitlab.Trigger
  public var protected: Lossy<Protected> = .error(Thrown("Not protected ref pipeline"))
  public var project: Lossy<Json.GitlabProject> = .error(MayDay("Not protected ref pipeline"))
  public var parent: Lossy<Json.GitlabJob> = .error(Thrown("Not triggered pipeline"))
  public var review: Lossy<Json.GitlabReviewState> = .error(Thrown("Not review triggered pipeline"))
  public var context: Context { .init(
    mr: try? job.review.get(),
    url: job.webUrl
      .components(separatedBy: "/-/")
      .first,
    job: job,
    bot: try? protected.map(\.user).get(),
    proj: try? project.get(),
    parent: try? parent.get(),
    review: try? review.get()
  )}
  public func matches(build: Production.Build) -> Bool {
    guard case .branch(let value) = build else { return false }
    return value.sha == job.pipeline.sha && value.branch == job.pipeline.ref
  }
  public static func make(
    trigger: Yaml.Gitlab.Trigger,
    env: Env,
    job: Json.GitlabJob
  ) -> Self { .init(
    env: env,
    job: job,
    api: "\(env.api)/projects/\(job.pipeline.projectId)",
    trigger: trigger
  )}
  public struct Context: Encodable {
    public var mr: UInt?
    public var url: String?
    public var job: Json.GitlabJob
    public var bot: Json.GitlabUser?
    public var proj: Json.GitlabProject?
    public var parent: Json.GitlabJob?
    public var review: Json.GitlabReviewState?
  }
  public struct Parent {
    public let job: UInt
    public let profile: Files.Relative
  }
  public struct Protected {
    public let secret: String
    public let auth: String
    public let push: String
    public let user: Json.GitlabUser
    public static func make(
      token: String,
      env: Env,
      user: Json.GitlabUser
    ) throws -> Self { .init(
      secret: token,
      auth: "Authorization: Bearer \(token)",
      push: env.push(user: user.username, pass: token),
      user: user
    )}
  }
  public struct Env {
    public let api: String
    public let host: String
    public let port: String
    public let path: String
    public let scheme: String
    public let token: String
    public let isProtected: Bool
    public let parent: Lossy<Parent>
    func push(user: String, pass: String) -> String {
      "\(scheme)://\(user):\(pass)@\(host):\(port)/\(path).git"
    }
    public var getJob: Lossy<Execute> {
      return .init(.makeCurl(
        url: "\(api)/job",
        headers: ["Authorization: Bearer \(token)"],
        secrets: [token]
      ))
    }
    public func getTokenUser(token: String) -> Lossy<Execute> { .init(.makeCurl(
      url: "\(api)/user",
      headers: ["Authorization: Bearer \(token)"],
      secrets: [token]
    ))}
    public static func make(env: [String: String], trigger: Yaml.Gitlab.Trigger) throws -> Self {
      guard "true" == env["GITLAB_CI"] else { throw Thrown("Not in GitlabCI context") }
      return try .init(
        api: "CI_API_V4_URL".get(env: env),
        host: "CI_SERVER_HOST".get(env: env),
        port: "CI_SERVER_PORT".get(env: env),
        path: "CI_PROJECT_PATH".get(env: env),
        scheme: "CI_SERVER_PROTOCOL".get(env: env),
        token: "CI_JOB_TOKEN".get(env: env),
        isProtected: env["CI_COMMIT_REF_PROTECTED"] == "true",
        parent: .init(try .init(
          job: trigger.jobId.get(env: env).getUInt(),
          profile: .init(value: trigger.profile.get(env: env))
        ))
      )
    }
  }
  public struct Info: Encodable {
    public var bot: String?
    public var url: String?
    public var job: Json.GitlabJob
    public var mr: UInt?
  }
}
public extension Gitlab {
  func getJob(
    id: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/jobs/\(id)",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func loadArtifact(
    job: UInt,
    file: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/jobs/\(job)/artifacts/\(file)",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  var getProject: Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func getPipeline(
    pipeline: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/pipelines/\(pipeline)",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func getMrState(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)?include_rebase_in_progress=true",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func getMrAwarders(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)/award_emoji",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func postMrPipelines(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)/pipelines",
    method: "POST",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func postMrAward(
    review: UInt,
    award: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)/award_emoji",
    method: "POST",
    form: ["name=\(award)"],
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func putMrState(
    parameters: PutMrState,
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)",
    method: "PUT",
    data: parameters.curl.get(),
    headers: [protected.get().auth, Json.contentType],
    secrets: [protected.get().secret]
  ))}
  func putMrMerge(
    parameters: PutMrMerge,
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests/\(review)/merge",
    method: "PUT",
    checkHttp: false,
    data: parameters.curl.get(),
    headers: [protected.get().auth, Json.contentType],
    secrets: [protected.get().secret]
  ))}
  func postTriggerPipeline(
    cfg: Configuration,
    ref: String,
    variables: [String: String]
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/trigger/pipeline",
    method: "POST",
    form: [
      "token=\(env.token)",
      "ref=\(ref)",
    ] + variables
      .map { try "variables[\($0.key)]=\($0.value.urlEncoded.get())" },
    secrets: [env.token]
  ))}
  func affectPipeline(
    cfg: Configuration,
    pipeline: UInt,
    action: PipelineAction
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/pipelines/\(pipeline)\(action.path)",
    method: action.method,
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func postMergeRequests(
    parameters: PostMergeRequests
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/merge_requests",
    method: "POST",
    data: parameters.curl.get(),
    headers: [protected.get().auth, Json.contentType],
    secrets: [protected.get().secret]
  ))}
  func listShaMergeRequests(
    sha: Git.Sha
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/commits/\(sha.value)/merge_requests",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func getJobs(
    action: JobAction,
    scopes: [JobScope],
    pipeline: UInt,
    page: Int,
    count: Int
  ) -> Lossy<Execute> {
    let query = [
      "include_retried=true",
      "page=\(page)",
      "per_page=\(count)",
    ] + scopes.flatMapEmpty(action.scopes).map { "scope[]=\($0.rawValue)" }
    return .init(try .makeCurl(
      url: "\(api)/pipelines/\(pipeline)/jobs?\(query.joined(separator: "&"))",
      headers: [protected.get().auth],
      secrets: [protected.get().secret]
    ))
  }
  func postJobsAction(
    job: UInt,
    action: JobAction
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/jobs/\(job)/\(action.rawValue)",
    method: "POST",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func postTags(
    name: String,
    ref: String,
    message: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/tags",
    method: "POST",
    form: [
      "tag_name=\(name)",
      "ref=\(ref)",
      "message=\(message)",
    ],
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func postBranches(
    name: String,
    ref: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/branches",
    method: "POST",
    form: [
      "branch=\(name.urlEncoded.get())",
      "ref=\(ref)",
    ],
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func deleteBranch(name: String) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/branches/\(name.urlEncoded.get())",
    method: "DELETE",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func deleteTag(name: String) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/tags/\(name.urlEncoded.get())",
    method: "DELETE",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func getBranches(page: Int, count: Int) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/branches?page=\(page)&per_page=\(count)",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  func getBranch(name: String) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(api)/repository/branches/\(name.urlEncoded.get())",
    headers: [protected.get().auth],
    secrets: [protected.get().secret]
  ))}
  struct PutMrState: Encodable {
    public var targetBranch: String?
    public var title: String?
    public var addLabels: String?
    public var removeLabels: String?
    public var stateEvent: String?
    public init(
      targetBranch: String? = nil,
      title: String? = nil,
      addLabels: String? = nil,
      removeLabels: String? = nil,
      stateEvent: String? = nil
    ) {
      self.targetBranch = targetBranch
      self.title = title
      self.addLabels = addLabels
      self.removeLabels = removeLabels
      self.stateEvent = stateEvent
    }
  }
  struct PutMrMerge: Encodable {
    public var mergeCommitMessage: String?
    public var squashCommitMessage: String?
    public var squash: Bool?
    public var shouldRemoveSourceBranch: Bool?
    public var mergeWhenPipelineSucceeds: Bool?
    public var sha: String?
    public init(
      mergeCommitMessage: String? = nil,
      squashCommitMessage: String? = nil,
      squash: Bool? = nil,
      shouldRemoveSourceBranch: Bool? = nil,
      mergeWhenPipelineSucceeds: Bool? = nil,
      sha: Git.Sha? = nil
    ) {
      self.mergeCommitMessage = mergeCommitMessage
      self.squashCommitMessage = squashCommitMessage
      self.squash = squash
      self.shouldRemoveSourceBranch = shouldRemoveSourceBranch
      self.mergeWhenPipelineSucceeds = mergeWhenPipelineSucceeds
      self.sha = sha?.value
    }
  }
  struct PostMergeRequests: Encodable {
    public var sourceBranch: String
    public var targetBranch: String
    public var title: String
    public init(
      sourceBranch: String,
      targetBranch: String,
      title: String
    ) {
      self.sourceBranch = sourceBranch
      self.targetBranch = targetBranch
      self.title = title
    }
  }
  enum PipelineAction: String {
    case cancel
    case delete
    case retry
    var path: String {
      switch self {
      case .cancel: return "/cancel"
      case .delete: return ""
      case .retry: return "/retry"
      }
    }
    var method: String {
      switch self {
      case .cancel: return "POST"
      case .delete: return "DELETE"
      case .retry: return "POST"
      }
    }
  }
  enum JobAction: String {
    case play
    case cancel
    case retry
    var scopes: [JobScope] {
      switch self {
      case .play: return [.manual]
      case .cancel: return [.pending, .running, .created]
      case .retry: return [.failed, .canceled, .success]
      }
    }
  }
  enum JobScope: String {
    case canceled
    case created
    case failed
    case manual
    case pending
    case running
    case success
  }
}
extension Encodable {
  var curl: Lossy<String> {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return Lossy(self)
      .map(encoder.encode(_:))
      .map(String.make(utf8:))
  }
}
extension String {
  var urlEncoded: Lossy<String> { .init(try self
    .addingPercentEncoding(withAllowedCharacters: .alphanumerics)
    .get { throw MayDay("addingPercentEncoding failed") }
  )}
}
