extension TargetsEditor {
    final class Provider: BaseProvider, TargetsEditorProvider {
        var profile: BGTargets {
            storage.bgTargets.retrieve()
        }

        func saveProfile(_ profile: BGTargets) {
            storage.bgTargets.save(profile)
        }
    }
}
