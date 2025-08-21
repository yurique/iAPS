import Foundation

extension ISFEditor {
    final class Provider: BaseProvider, ISFEditorProvider {
        var profile: InsulinSensitivities {
            storage.insulinSensitivities.retrieve()
        }

        func saveProfile(_ profile: InsulinSensitivities) {
            storage.insulinSensitivities.save(profile)
        }

        var autosense: Autosens {
            storage.autosens.retrieveOpt()
                ?? Autosens(ratio: 1, newisf: nil, timestamp: nil)
        }

        var suggestion: Suggestion? {
            storage.suggested.retrieveOpt()
        }

        var autotune: Autotune? {
            guard let profile = storage.autotune.retrieveOpt() else { return nil }
            return Autotune.from(profile: profile)
        }

        var sensitivity: NSDecimalNumber? {
            if let suggestion = CoreDataStorage().fetchReason() {
                return suggestion.isf ?? 15
            }
            return nil
        }
    }
}
