import Foundation

extension ConfigEditor {
    final class Provider: BaseProvider, ConfigEditorProvider {
        func load(file: ConfigEditorFile) -> String {
            do {
                guard let storage = entityStorage(file) else {
                    return ""
                }
                print("storage: \(storage)")
                let content = try storage.retrieveAsString()
                return content ?? ""
            } catch {
                return ""
            }
        }

//        func urlFor(file: ConfigEditorFile) -> URL {
//            print("url for file: \(file)")
//            let fileName = entityStorage(file)?.fileName() ?? "unknown-file"
//            print("filename: \(fileName)")
//            return storage.urlFor(file: fileName)
//        }

        func fileNameFor(file: ConfigEditorFile) -> String {
            print("fileNameFor for \(file)")
            print("fileName: \(entityStorage(file)?.fileName())")
            return entityStorage(file)?.fileName() ?? "unknown-file"
        }

        func save(_ value: String, as file: ConfigEditorFile) {
            do {
                try entityStorage(file)?.saveFromString(string: value)
            } catch {
                warning(.service, "Invalid JSON")
            }
//            if file.hasSuffix(".js") {
//                storage.save(value, as: file)
//                return
//            }
//
//            guard let data = value.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data, options: [])) != nil else {
//                warning(.service, "Invalid JSON")
//                return
//            }
//            storage.save(value, as: file)
        }

        private func entityStorage(_ file: ConfigEditorFile) -> AnyEntityStorage? {
            switch file {
            case .preferences: storage.preferences
            case .pumpSettings: storage.pumpSettings
            case .autosense: storage.autosens
            case .pumpHistory: storage.pumpHistory
            case .tempBasal: storage.tempBasal
            case .basalProfile: storage.basalProfile
            case .bgTargets: storage.bgTargets
            case .tempTargets: storage.tempTargets
            case .meal: storage.meal
            case .pumpProfile: storage.pumpProfile
            case .profile: storage.profile
            case .carbHistory: storage.carbsHistory
            case .enacted: storage.enacted
            case .announcements: storage.announcements
            case .announcementsEnacted: storage.announcementsEnacted
            case .notUploadedOverrides: storage.notUploadedOverrides
            case .autotune: storage.autotune
            case .glucose: storage.glucose
            case .dynamicVariables: storage.dynamicVariables
            case .tempTargetsPresets: storage.tempTargetPresets
            case .calibrations: storage.calibrations
            case .middleware: storage.middleware
            case .statistics: storage.statistics
            case .settings: storage.settings
            case .none: nil
            }
        }
    }
}
