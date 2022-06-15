import Foundation
import Facility
public struct Generator {
  public var template: String
  public var templates: [String: String]
  public var context: Encodable
  public struct Versions: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var versions: [String: String]
  }
  public struct Build: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var versions: [String: String]
    public var build: String
  }
  public struct Integration: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var targets: [String]
  }
  public struct ReleaseVersion: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var ref: String
  }
  public struct ReleaseName: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct DeployName: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var version: String
    public var build: String
  }
  public struct DeployAnnotation: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String
    public var product: String
    public var version: String
    public var build: String
  }
  public struct NextVersion: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct NextBuild: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var build: String
  }
  public struct DeployVersion: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var ref: String
  }
  public struct DeployBuild: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var ref: String
  }
  public struct HotfixVersion: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct VersionCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct BuildCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var build: String
  }
  public struct UserActivityCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String
    public var active: Bool
  }
  public struct SquashCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var review: Json.GitlabReviewState
  }
  public struct IntegrationCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var fork: String
    public var source: String
    public var target: String
  }
  public struct ReplicationCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var fork: String
    public var source: String
    public var target: String
  }
}
public extension Configuration {
  func generateVersions(
    template: String,
    versions: [String: String]
  ) -> Generator { .init(
    template: template,
    templates: profile.stencilTemplates,
    context: Generator.Versions(
      env: env,
      custom: controls.stencilCustom,
      versions: versions
    )
  )}
  func generateBuild(
    template: String,
    build: String,
    versions: [String: String]
  ) -> Generator { .init(
    template: template,
    templates: profile.stencilTemplates,
    context: Generator.Build(
      env: env,
      custom: controls.stencilCustom,
      versions: versions,
      build: build
    )
  )}
  func generateIntegration(
    template: String,
    targets: [String]
  ) -> Generator { .init(
    template: template,
    templates: profile.stencilTemplates,
    context: Generator.Integration(
      env: env,
      custom: controls.stencilCustom,
      targets: targets
    )
  )}
  func generateReleaseVersion(
    product: Production.Product,
    ref: String
  ) -> Generator { .init(
    template: product.releaseBranch.parseVersionTemplate,
    templates: controls.stencilTemplates,
    context: Generator.ReleaseVersion(
      env: env,
      custom: controls.stencilCustom,
      product: product.name,
      ref: ref
    )
  )}
  func generateDeployName(
    product: Production.Product,
    version: String,
    build: String
  ) -> Generator { .init(
    template: product.deployTag.createTemplate,
    templates: controls.stencilTemplates,
    context: Generator.DeployName(
      env: env,
      custom: controls.stencilCustom,
      product: product.name,
      version: version,
      build: build
    )
  )}
  func generateDeployAnnotation(
    job: Json.GitlabJob,
    product: Production.Product,
    version: String,
    build: String
  ) -> Generator { .init(
    template: product.deployTag.createTemplate,
    templates: controls.stencilTemplates,
    context: Generator.DeployAnnotation(
      env: env,
      custom: controls.stencilCustom,
      user: job.user.username,
      product: product.name,
      version: version,
      build: build
    )
  )}
  func generateReleaseName(
    product: Production.Product,
    version: String
  ) -> Generator { .init(
    template: product.releaseBranch.createTemplate,
    templates: controls.stencilTemplates,
    context: Generator.ReleaseName(
      env: env,
      custom: controls.stencilCustom,
      product: product.name,
      version: version
    )
  )}
  func generateNextVersion(
    product: Production.Product,
    version: String
  ) -> Generator { .init(
    template: product.createNextVersionTemplate,
    templates: controls.stencilTemplates,
    context: Generator.NextVersion(
      env: env,
      custom: controls.stencilCustom,
      product: product.name,
      version: version
    )
  )}
  func generateNextBuild(
    production: Production,
    build: String
  ) -> Generator { .init(
    template: production.createNextBuildTemplate,
    templates: controls.stencilTemplates,
    context: Generator.NextBuild(
      env: env,
      custom: controls.stencilCustom,
      build: build
    )
  )}
  func generateDeployVersion(
    product: Production.Product,
    ref: String
  ) -> Generator { .init(
    template: product.deployTag.parseVersionTemplate,
    templates: controls.stencilTemplates,
    context: Generator.DeployVersion(
      env: env,
      custom: controls.stencilCustom,
      product: product.name,
      ref: ref
    )
  )}
  func generateDeployBuild(
    product: Production.Product,
    ref: String
  ) -> Generator { .init(
    template: product.deployTag.parseBuildTemplate,
    templates: controls.stencilTemplates,
    context: Generator.DeployBuild(
      env: env,
      custom: controls.stencilCustom,
      ref: ref
    )
  )}
  func generateHotfixVersion(
    product: Production.Product,
    version: String
  ) -> Generator { .init(
    template: product.createHotfixVersionTemplate,
    templates: controls.stencilTemplates,
    context: Generator.HotfixVersion(
      env: env,
      custom: controls.stencilCustom,
      product: product.name,
      version: version
    )
  )}
  func generateVersionCommitMessage(
    asset: Asset,
    product: Production.Product,
    version: String
  ) -> Generator { .init(
    template: asset.commitMessageTemplate,
    templates: controls.stencilTemplates,
    context: Generator.VersionCommitMessage(
      env: env,
      custom: controls.stencilCustom,
      product: product.name,
      version: version
    )
  )}
  func generateBuildCommitMessage(
    asset: Asset,
    build: String
  ) -> Generator { .init(
    template: asset.commitMessageTemplate,
    templates: controls.stencilTemplates,
    context: Generator.BuildCommitMessage(
      env: env,
      custom: controls.stencilCustom,
      build: build
    )
  )}
  func generateUserActivityCommitMessage(
    asset: Asset,
    user: String,
    active: Bool
  ) -> Generator { .init(
    template: asset.commitMessageTemplate,
    templates: controls.stencilTemplates,
    context: Generator.UserActivityCommitMessage(
      env: env,
      custom: controls.stencilCustom,
      user: user,
      active: active
    )
  )}
  func generateSquashCommitMessage(
    squash: Flow.Squash,
    review: Json.GitlabReviewState
  ) -> Generator { .init(
    template: squash.messageTemplate,
    templates: controls.stencilTemplates,
    context: Generator.SquashCommitMessage(
      env: env,
      custom: controls.stencilCustom,
      review: review
    )
  )}
  func generateIntegrationCommitMessage(
    integration: Flow.Integration,
    merge: Flow.Merge
  ) -> Generator { .init(
    template: integration.messageTemplate,
    templates: controls.stencilTemplates,
    context: Generator.IntegrationCommitMessage(
      env: env,
      custom: controls.stencilCustom,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
  func generateReplicationCommitMessage(
    replication: Flow.Replication,
    merge: Flow.Merge
  ) -> Generator { .init(
    template: replication.messageTemplate,
    templates: controls.stencilTemplates,
    context: Generator.ReplicationCommitMessage(
      env: env,
      custom: controls.stencilCustom,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
}