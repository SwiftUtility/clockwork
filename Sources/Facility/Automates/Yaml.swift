import Foundation
import Facility
public enum Yaml {
  public struct Profile: Decodable {
    public var controls: Controls
    public var codeOwnage: String?
    public var fileTaboos: String?
    public var obsolescence: Criteria?
    public var stencilTemplates: String?
    public struct FileTaboo: Decodable {
      public var rule: String
      public var file: Criteria?
      public var line: Criteria?
    }
    public struct Controls: Decodable {
      public var file: String
      public var branch: String
    }
  }
  public struct Controls: Decodable {
    public var mainatiners: [String]?
    public var gitlabCi: GitlabCi?
    public var communication: String
    public var awardApproval: String?
    public var production: String?
    public var requisition: String?
    public var flow: String?
    public var stencilTemplates: String?
    public var stencilCustom: String?
    public var forbiddenCommits: [String]?
    public struct Production: Decodable {
      public var mainatiners: [String]?
      public var builds: Asset
      public var versions: Asset
      public var createNextBuildTemplate: String
      public var products: [String: Product]
      public var releaseNotesTemplate: String?
      public var maxBuildsCount: Int?
      public struct Product: Decodable {
        public var mainatiners: [String]?
        public var deployTag: DeployTag
        public var releaseBranch: ReleaseBranch
        public var createNextVersionTemplate: String
        public var createHotfixVersionTemplate: String
        public struct DeployTag: Decodable {
          public var nameMatch: Criteria
          public var createTemplate: String
          public var parseBuildTemplate: String
          public var parseVersionTemplate: String
          public var annotationTemplate: String
        }
        public struct ReleaseBranch: Decodable {
          public var nameMatch: Criteria
          public var createTemplate: String
          public var parseVersionTemplate: String
        }
      }
      public struct Build: Codable {
        public var build: String
        public var sha: String
        public var branch: String?
        public var tag: String?
        public static func make(build: String, sha: String, branch: String) -> Self { .init(
          build: build,
          sha: sha,
          branch: branch
        )}
        public static func make(build: String, sha: String, tag: String) -> Self { .init(
          build: build,
          sha: sha,
          tag: tag
        )}
      }
    }
    public struct Requisition: Decodable {
      public var keychains: [String: Keychain]
      public var provisions: [String: String]
      public struct Keychain: Decodable {
        public var crypto: String
        public var password: Token
      }
    }
    public struct Flow: Decodable {
      public var squash: Squash?
      public var replication: Replication?
      public var integration: Integration?
      public struct Squash: Decodable {
        public var messageTemplate: String
        public var titleRule: Criteria?
      }
      public struct Replication: Decodable {
        public var target: String
        public var prefix: String
        public var source: Criteria
        public var messageTemplate: String
      }
      public struct Integration: Decodable {
        public var mainatiners: [String]?
        public var rules: [Rule]
        public var prefix: String
        public var messageTemplate: String
        public struct Rule: Decodable {
          public var mainatiners: [String]?
          public var source: Criteria
          public var target: Criteria
        }
      }
    }
    public struct GitlabCi: Decodable {
      public var bot: Bot
      public var trigger: Trigger
      public struct Bot: Decodable {
        public var login: String
        public var apiToken: Token?
        public var pushToken: Token?
      }
      public struct Trigger: Decodable {
        public var pipeline: String
        public var review: String
        public var profile: String
      }
    }
    public struct AwardApproval: Decodable {
      public var userActivity: Asset
      public var holdAward: String
      public var sanity: String
      public var groups: [String: Group]
      public var emergency: String?
      public var sourceBranch: [String: Criteria]?
      public var targetBranch: [String: Criteria]?
      public var personal: [String: [String]]?
      public struct Group: Decodable {
        public var award: String
        public var quorum: Int
        public var reserve: [String]?
        public var optional: [String]?
        public var required: [String]?
      }
    }
    public struct Communication: Decodable {
      public var slackHooks: [String: Token]
      public var slackHookTextMessages: [SlackHookTextMessage]?
      public struct SlackHookTextMessage: Decodable {
        public var hook: String
        public var messageTemplate: String
        public var userName: String?
        public var channel: String?
        public var emojiIcon: String?
        public var events: [String]
      }
    }
  }
  public struct Asset: Decodable {
    public var file: String
    public var branch: String
    public var commitMessageTemplate: String
  }
  public struct Token: Decodable {
    public var value: String?
    public var envVar: String?
    public var envFile: String?
  }
  public struct Criteria: Decodable {
    var include: [String]?
    var exclude: [String]?
  }
}
