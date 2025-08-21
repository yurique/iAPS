import Combine

extension CREditor {
    final class Provider: BaseProvider, CREditorProvider {
        var profile: CarbRatios {
            storage.carbRatios.retrieve()
        }

        func saveProfile(_ profile: CarbRatios) {
            storage.carbRatios.save(profile)
        }

        var autotune: Autotune? {
            guard let profile = storage.autotune.retrieveOpt() else { return nil }
            return Autotune.from(profile: profile)
        }
    }
}
