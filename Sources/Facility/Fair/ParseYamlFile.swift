import Foundation
import Facility
import FacilityPure
public struct ParseYamlFile<T>: Query {
  public var git: Git
  public var file: Git.File
  public var parse: Try.Of<AnyCodable.Dialect>.Of<AnyCodable>.Do<T>
  public typealias Reply = T
}
public extension Configuration {
  var parseFusion: Lossy<ParseYamlFile<Fusion>> { .init(try .init(
    git: git,
    file: profile.fusion.get(),
    parse: { try .make(yaml: $0.read(Yaml.Review.self, from: $1)) }
  ))}
  var parseProduction: Lossy<ParseYamlFile<Production>> { .init(try .init(
    git: git,
    file: profile.production.get(),
    parse: { try .make(yaml: $0.read(Yaml.Flow.self, from: $1)) }
  ))}
  var parseRequisition: Lossy<ParseYamlFile<Requisition>> { .init(try .init(
    git: git,
    file: profile.requisition.get(),
    parse: { try .make(env: env, yaml: $0.read(Yaml.Requisition.self, from: $1)) }
  ))}
  var parseCocoapods: Lossy<ParseYamlFile<Cocoapods>> { .init(try .init(
    git: git,
    file: profile.requisition.get(),
    parse: { try .make(yaml: $0.read(Yaml.Cocoapods.self, from: $1)) }
  ))}
  var parseFileTaboos: Lossy<ParseYamlFile<[FileTaboo]>> { .init(try .init(
    git: git,
    file: profile.requisition.get(),
    parse: { try $0.read([Yaml.FileTaboo].self, from: $1).map(FileTaboo.init(yaml:)) }
  ))}
  func parseCodeOwnage(
    profile: Configuration.Profile
  ) -> ParseYamlFile<[String: Criteria]>? {
    guard let codeOwnage = profile.codeOwnage else { return nil }
    return .init(.init(
      git: git,
      file: codeOwnage,
      parse: { try $0.read([String: Yaml.Criteria].self, from: $1).mapValues(Criteria.init(yaml:)) }
    ))
  }
  func parseProfile(file: Git.File) -> ParseYamlFile<Configuration.Profile> { .init(
    git: git,
    file: file,
    parse: { try .make(location: file, yaml: $0.read(Yaml.Profile.self, from: $1)) }
  )}
  func parseBuilds(
    production: Production
  ) -> ParseYamlFile<[AlphaNumeric: Production.Build]> { .init(
    git: git,
    file: .make(asset: production.builds),
    parse: { dialect, yaml in try dialect
      .read([String: Yaml.Flow.Build].self, from: yaml)
      .map(Production.Build.make(build:yaml:))
      .reduce(into: [:], { $0[$1.build] = $1 })
    }
  )}
  func parseVersions(
    production: Production
  ) -> ParseYamlFile<[String: Production.Version]> { .init(
    git: git,
    file: .make(asset: production.versions),
    parse: { dialect, yaml in try dialect
      .read(Yaml.Flow.Versions.self, from: yaml)
      .map(Production.Version.make(product:yaml:))
      .reduce(into: [:], { $0[$1.product] = $1 })
    }
  )}
  func parseFusionStatuses(
    approval: Fusion.Approval
  ) -> ParseYamlFile<[UInt: Fusion.Approval.Status]> { .init(
    git: git,
    file: .make(asset: approval.statuses),
    parse: { dialect, yaml in try dialect
      .read([String: Yaml.Review.Approval.Status].self, from: yaml)
      .map(Fusion.Approval.Status.make(review:yaml:))
      .reduce(into: [:], { $0[$1.review] = $1 })
    }
  )}
  func parseApprovers(
    approval: Fusion.Approval
  ) -> ParseYamlFile<[String: Fusion.Approval.Approver]> { .init(
    git: git,
    file: .make(asset: approval.approvers),
    parse: { dialect, yaml in try dialect
      .read([String: Yaml.Review.Approval.Approver].self, from: yaml)
      .map(Fusion.Approval.Approver.make(login:yaml:))
      .reduce(into: [:], { $0[$1.login] = $1 })
    }
  )}
  func parseReviewQueue(
    fusion: Fusion
  ) -> ParseYamlFile<Fusion.Queue> { .init(
    git: git,
    file: .make(asset: fusion.queue),
    parse: { try .make(queue: $0.read([String: [UInt]].self, from: $1)) }
  )}
}
