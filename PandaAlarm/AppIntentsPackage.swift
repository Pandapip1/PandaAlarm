import AppIntents
import PandaAlarmIntents

struct PandaAlarmAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [PandaAlarmIntentsPackage.self]
    }
}
