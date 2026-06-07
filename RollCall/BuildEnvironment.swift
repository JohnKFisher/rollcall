import Foundation

enum BuildEnvironment: String {
    case debug = "Debug"
    case internalTesting = "Internal"
    case release = "Release"

    static let current: BuildEnvironment = {
        #if DEBUG
        return .debug
        #elseif INTERNAL
        return .internalTesting
        #else
        return .release
        #endif
    }()

    var isDebugBuild: Bool { self == .debug }
    var isInternalBuild: Bool { self == .internalTesting }
    var isReleaseBuild: Bool { self == .release }
}

struct FeatureFlags: Equatable {
    var environment: BuildEnvironment
    var experimental: ExperimentalSettings

    static var currentBuildDefaults: FeatureFlags {
        FeatureFlags(environment: .current, experimental: .default)
    }

    var isDebugBuild: Bool { environment.isDebugBuild }
    var isInternalBuild: Bool { environment.isInternalBuild }
    var isReleaseBuild: Bool { environment.isReleaseBuild }

    var showDeveloperSettings: Bool {
        !environment.isReleaseBuild
    }

    var showExperimentalFeatures: Bool {
        switch environment {
        case .debug:
            return true
        case .internalTesting:
            return experimental.showExperimentalFeatures
        case .release:
            return false
        }
    }

    var unlockPremiumForTesting: Bool {
        switch environment {
        case .debug:
            return true
        case .internalTesting:
            return experimental.unlockPremiumForTesting
        case .release:
            return false
        }
    }

    var appleMusicLocalCopyEnabled: Bool {
        showExperimentalFeatures && experimental.appleMusicLocalCopyEnabled
    }

    var appleMusicTransitionCrossfadeEnabled: Bool {
        showExperimentalFeatures && experimental.appleMusicTransitionCrossfadeEnabled
    }

    static func assertReleaseSafety(_ flags: FeatureFlags = .currentBuildDefaults) {
        guard flags.isReleaseBuild else { return }
        precondition(!flags.showDeveloperSettings, "Release builds must not show Developer Settings.")
        precondition(!flags.showExperimentalFeatures, "Release builds must not show experimental features.")
        precondition(!flags.unlockPremiumForTesting, "Release builds must not unlock premium testing.")
        precondition(!flags.appleMusicLocalCopyEnabled, "Release builds must not enable Apple Music local-copy experiments.")
        precondition(!flags.appleMusicTransitionCrossfadeEnabled, "Release builds must not enable Apple Music transition-crossfade experiments.")
    }
}
