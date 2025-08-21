import Combine

extension AutotuneConfig {
    final class Provider: BaseProvider, AutotuneConfigProvider {
        @Injected() private var apsManager: APSManager!

        var autotune: Autotune? {
            guard let profile = storage.autotune.retrieveOpt() else { return nil }
            return Autotune.from(profile: profile)
        }

        func runAutotune() -> AnyPublisher<Autotune?, Never> {
            apsManager.autotune()
        }

        func deleteAutotune() {
            storage.autotune.remove()
        }

        var profile: [BasalProfileEntry] {
            storage.basalProfile.retrieveOpt() ?? []
        }
    }
}
