import Foundation
import Facility
import FacilityPure
import FacilityFair
import InteractivityCommon
import InteractivityYams
import InteractivityStencil
import InteractivityPathKit
final class Shell: ContextLocal {
  public let sh: Ctx.Sh
  public let repo: Ctx.Repo
  init(profile: String, version: String) throws {
    self.sh = Ctx.Sh.make(
      env: ProcessInfo.processInfo.environment,
      stdin: FileHandle.standardInput.readToEnd,
      stdout: FileHandle.standardOutput.write(_:),
      stderr: FileHandle.standardError.write(_:),
      read: FileHandle.read(file:),
      lineIterator: FileHandle.lineIterator(file:),
      listDirectories: Finder.listDirectories(path:),
      unyaml: YamlParser.decodeYaml(content:),
      execute: Processor.execute(query:),
      resolveAbsolute: Finder.resolve(query:),
      getTime: Date.init
    )
    let file = try sh.resolveAbsolute(.make(path: profile))
    let git = try Ctx.Git.make(sh: sh, dir: Finder.parent(path: file))
    let sha = try git.getSha(sh: sh, ref: .head)
    let profile = try Profile.make(
      location: .make(ref: sha.ref, path: file.relative(to: git.root)),
      yaml: sh.dialect.read(
        Yaml.Profile.self,
        from: sh.unyaml(String.make(utf8: FileHandle.read(file: file)))
      )
    )
    guard version == profile.version
    else { throw Thrown("Profile version(\(version)) mismatch executable(\(profile.version))") }
    self.repo = try .make(
      git: git,
      sha: sha,
      branch: git.currentBranch(sh: sh),
      profile: profile,
      generate: StencilParser(sh: sh, git: git, profile: profile).generate(query:)
    )
  }
  func contractReview(_ payload: ContractPayload) throws -> Bool {
    let sender = try GitlabSender(ctx: self)
    guard case .value = sender.gitlab.current.review else { throw Thrown("Not review job") }
    try sender.triggerPipeline(variables: payload.encode(
      job: sender.gitlab.current.id, version: repo.profile.version
    ))
    return true
  }
  func contractProtected(_ payload: ContractPayload) throws -> Bool {
    let sender = try GitlabSender(ctx: self)
    let protected = try sender.gitlab.protected.get()
    try sender.createPipeline(protected: protected, variables: payload.encode(
      job: sender.gitlab.current.id, version: repo.profile.version
    ))
    return true
  }
  func contract(_ payload: ContractPayload) throws -> Bool {
    let sender = try GitlabSender(ctx: self)
    let variables = try payload.encode(job: sender.gitlab.current.id, version: repo.profile.version)
    if let protected = try? sender.gitlab.protected.get() {
      try sender.createPipeline(protected: protected, variables: variables)
    } else if case .value = sender.gitlab.current.review {
      try sender.triggerPipeline(variables: variables)
    } else {
      throw Thrown("Not either review or protected ref job")
    }
    return true
  }
  func render(template: String, stdin: Common.Stdin.Kind, args: [String]) throws -> Bool {
    try Id
      .make(generate(
        template: template,
        stdin: parse(stdin: stdin),
        args: args
      ))
      .map(repo.generate)
      .map(\.utf8)
      .map(Data.init(_:))
      .map(sh.stdout)
      .get()
    return true
  }
  func parse(stdin: Common.Stdin.Kind) throws -> AnyCodable? {
    switch stdin {
    case .ignore: return nil
    case .lines:
      let stdin = try sh.stdin()
        .map(String.make(utf8:))?
        .trimmingCharacters(in: .newlines)
        .components(separatedBy: .newlines)
      return try stdin.map(AnyCodable.init(any:))
    case .json: return try sh.stdin().reduce(AnyCodable.self, sh.rawDecoder.decode(_:from:))
    case .yaml: return try sh.stdin()
      .map(String.make(utf8:))
      .map(sh.unyaml)
    }
  }
}
