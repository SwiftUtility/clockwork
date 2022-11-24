import Foundation
import Facility
import FacilityPure
public final class Configurator {
  let execute: Try.Reply<Execute>
  let decodeYaml: Try.Reply<Yaml.Decode>
  let resolveAbsolute: Try.Reply<Files.ResolveAbsolute>
  let readFile: Try.Reply<Files.ReadFile>
  let generate: Try.Reply<Generate>
  let writeFile: Try.Reply<Files.WriteFile>
  let logMessage: Act.Reply<LogMessage>
  let dialect: AnyCodable.Dialect
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    decodeYaml: @escaping Try.Reply<Yaml.Decode>,
    resolveAbsolute: @escaping Try.Reply<Files.ResolveAbsolute>,
    readFile: @escaping Try.Reply<Files.ReadFile>,
    generate: @escaping Try.Reply<Generate>,
    writeFile: @escaping Try.Reply<Files.WriteFile>,
    logMessage: @escaping Act.Reply<LogMessage>,
    dialect: AnyCodable.Dialect,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.decodeYaml = decodeYaml
    self.resolveAbsolute = resolveAbsolute
    self.readFile = readFile
    self.generate = generate
    self.writeFile = writeFile
    self.logMessage = logMessage
    self.dialect = dialect
    self.jsonDecoder = jsonDecoder
  }
  public func configure(
    profile: String,
    env: [String: String]
  ) throws -> Configuration {
    let profilePath = try Id(profile)
      .map(Files.ResolveAbsolute.make(path:))
      .map(resolveAbsolute)
      .get()
    let repoPath = profilePath.value
      .components(separatedBy: "/")
      .dropLast()
      .joined(separator: "/")
    var git = try Id(repoPath)
      .map(Files.Absolute.init(value:))
      .map(Git.resolveTopLevel(path:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Files.Absolute.init(value:))
      .reduce(env, Git.init(env:root:))
      .get()
    git.lfs = try Id(git.updateLfs)
      .map(execute)
      .map(Execute.parseSuccess(reply:))
      .get()
    let profile = try Git.File(
      ref: .head,
      path: .init(value: profilePath.value.dropPrefix("\(git.root.value)/"))
    )
    var cfg = try Id(profile)
      .reduce(git, parse(git:yaml:))
      .reduce(Yaml.Profile.self, dialect.read(_:from:))
      .reduce(profile, Configuration.Profile.make(location:yaml:))
      .map({ Configuration.make(git: git, env: env, profile: $0) })
      .get()
    cfg.templates = try cfg.profile.templates
      .reduce(cfg.git, parse(git:templates:))
      .get([:])
    cfg.gitlab = .init(try resolveGitlab(cfg: cfg))
    cfg.slack = .init(try resolveSlack(cfg: cfg))
    cfg.jira = .init(try resolveJira(cfg: cfg))
    return cfg
  }
  public func parseYamlFile<T>(
    query: ParseYamlFile<T>
  ) throws -> T { try Id(query.file)
    .reduce(query.git, parse(git:yaml:))
    .reduce(dialect, query.parse)
    .get()
  }
  public func parseYamlSecret<T>(
    query: ParseYamlSecret<T>
  ) throws -> T { try Id(parse(git: query.cfg.git, env: query.cfg.env, secret: query.secret))
    .map(Yaml.Decode.init(content:))
    .map(decodeYaml)
    .reduce(dialect, query.parse)
    .get()
  }
  public func persistAsset(
    query: Configuration.PersistAsset
  ) throws -> Configuration.PersistAsset.Reply {
    guard let sha = try persist(
      git: query.cfg.git,
      asset: query.asset,
      yaml: query.content,
      message: query.message
    ) else { return false }
    try Execute.checkStatus(reply: execute(query.cfg.git.push(
      url: query.cfg.gitlab.flatMap(\.protected).get().push,
      branch: query.asset.branch,
      sha: sha,
      force: false,
      secret: query.cfg.gitlab.flatMap(\.protected).get().secret
    )))
    try Execute.checkStatus(reply: execute(query.cfg.git.fetchBranch(query.asset.branch)))
    let fetched = try Execute.parseText(reply: execute(query.cfg.git.getSha(
      ref: .make(remote: query.asset.branch)
    )))
    guard sha.value == fetched else { throw Thrown("Fetch sha mismatch") }
    return true
  }
  public func resolveSecret(
    query: Configuration.ResolveSecret
  ) throws -> Configuration.ResolveSecret.Reply {
    try parse(git: query.cfg.git, env: query.cfg.env, secret: query.secret)
  }
}
extension Configurator {
  func resolveGitlab(cfg: Configuration) throws -> Gitlab {
    let yaml = try cfg.profile.gitlab
      .reduce(cfg.git, parse(git:yaml:))
      .reduce(Yaml.Gitlab.self, dialect.read(_:from:))
      .get { throw Thrown("gitlab not configured") }
    let gitlabEnv = try Gitlab.Env.make(env: cfg.env, trigger: yaml.trigger)
    let gitlabJob = try gitlabEnv.getJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    var gitlab = Gitlab.make(trigger: yaml.trigger, env: gitlabEnv, job: gitlabJob)
    guard gitlabEnv.isProtected else { return gitlab }
    gitlab.protected = Lossy
      .make({ try parse(git: cfg.git, env: cfg.env, secret: .make(yaml: yaml.token)) })
      .map({ token in try .make(
        token: token,
        env: gitlabEnv,
        user: gitlabEnv.getTokenUser(token: token)
          .map(execute)
          .reduce(Json.GitlabUser.self, jsonDecoder.decode(success:reply:))
          .get()
      )})
    gitlab.project = gitlab.getProject
      .map(execute)
      .reduce(Json.GitlabProject.self, jsonDecoder.decode(success:reply:))
    if let parentJob = try? yaml.trigger.jobId.get(env: cfg.env) {
      gitlab.parent = Lossy(try parentJob.getUInt())
        .flatMap(gitlab.getJob(id:))
        .map(execute)
        .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
    }
    if let review = try? gitlab.parent.flatMap(\.review).get() {
      gitlab.review = gitlab.getMrState(review: review)
        .map(execute)
        .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
    }
    return gitlab
  }
  func resolveSlack(cfg: Configuration) throws -> Slack {
    let yaml = try cfg.profile.slack
      .reduce(cfg.git, parse(git:yaml:))
      .reduce(Yaml.Slack.self, dialect.read(_:from:))
      .get { throw Thrown("slack not configured") }
    let token = try parse(git: cfg.git, env: cfg.env, secret: .make(yaml: yaml.token))
    return try .make(token: token, yaml: yaml)
  }
  func resolveJira(cfg: Configuration) throws -> Jira {
    let yaml = try cfg.profile.jira
      .reduce(cfg.git, parse(git:yaml:))
      .reduce(Yaml.Jira.self, dialect.read(_:from:))
      .get { throw Thrown("jira not configured") }
    return try .make(
      url: parse(git: cfg.git, env: cfg.env, secret: .make(yaml: yaml.url)),
      rest: parse(git: cfg.git, env: cfg.env, secret: .make(yaml: yaml.rest)),
      token: parse(git: cfg.git, env: cfg.env, secret: .make(yaml: yaml.token)),
      yaml: yaml
    )
  }
  func persist(
    git: Git,
    asset: Configuration.Asset,
    yaml: String,
    message: String
  ) throws -> Git.Sha? {
    let initial = try Id(.head)
      .map(git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.make(value:))
      .map(Git.Ref.make(sha:))
      .get()
    try Execute.checkStatus(reply: execute(git.detach(ref: .make(remote: asset.branch))))
    try Execute.checkStatus(reply: execute(git.clean))
    try writeFile(.init(
      file: .init(value: "\(git.root.value)/\(asset.file.value)"),
      data: .init(yaml.utf8)
    ))
    let result: Git.Sha?
    if try Execute.parseLines(reply: execute(git.changesList)).isEmpty.not {
      try Execute.checkStatus(reply: execute(git.addAll))
      try Execute.checkStatus(reply: execute(git.commit(message: message)))
      result = try .make(value: Execute.parseText(reply: execute(git.getSha(ref: .head))))
    } else {
      result = nil
    }
    try Execute.checkStatus(reply: execute(git.detach(ref: initial)))
    try Execute.checkStatus(reply: execute(git.clean))
    return result
  }
  func parse(git: Git, yaml: Git.File) throws -> AnyCodable { try Id
    .make(yaml)
    .map(git.cat(file:))
    .map(execute)
    .map(Execute.parseText(reply:))
    .map(Yaml.Decode.init(content:))
    .map(decodeYaml)
    .get()
  }
  func parse(
    git: Git,
    env: [String: String],
    secret: Configuration.Secret
  ) throws -> String {
    switch secret {
    case .value(let value): return value
    case .envVar(let envVar): return try env[envVar]
      .get { throw Thrown("No env \(envVar)") }
    case .envFile(let envFile): return try env[envFile]
      .map(Files.Absolute.init(value:))
      .map(Files.ReadFile.init(file:))
      .map(readFile)
      .map(String.make(utf8:))
      .get { throw Thrown("No env \(envFile)") }
    case .sysFile(let sysFile): return try Id(sysFile)
      .map(git.root.makeResolve(path:))
      .map(resolveAbsolute)
      .map(Files.ReadFile.init(file:))
      .map(readFile)
      .map(String.make(utf8:))
      .get()
    case .gitFile(let file): return try Id(file)
      .map(git.cat(file:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .get()
    }
  }
  func parse(
    git: Git,
    templates: Git.Dir
  ) throws -> [String: String] {
    var result: [String: String] = [:]
    let files = try Id(templates)
      .map(git.listTreeTrackedFiles(dir:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
    for file in files {
      let template = try file.dropPrefix("\(templates.path.value)/")
      result[template] = try Id(file)
        .map(Files.Relative.init(value:))
        .reduce(templates.ref, Git.File.init(ref:path:))
        .map(git.cat(file:))
        .map(execute)
        .map(Execute.parseText(reply:))
        .get()
    }
    return result
  }
}
