import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewRemind: ContractPerformer {
    var iid: UInt
    static var triggerContract: Bool { true }
  }
}
