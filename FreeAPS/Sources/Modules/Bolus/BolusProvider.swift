import Foundation

extension Bolus {
    final class Provider: BaseProvider, BolusProvider {
        @Injected() var pumpHistoryStorage: PumpHistoryStorage!
        @Injected() var glucoseStorage: GlucoseStorage!

        let coreDataStorage = CoreDataStorage()

        var suggestion: Suggestion? {
            storage.suggested.retrieveOpt()
        }

        func pumpSettings() -> PumpSettings {
            storage.pumpSettings.retrieve()
        }

        func fetchGlucose() -> [Readings] {
            let fetchGlucose = coreDataStorage.fetchGlucose(interval: DateFilter().twoHours)
            return fetchGlucose
        }

        func pumpHistory() -> [PumpHistoryEvent] {
            pumpHistoryStorage.recent()
        }
    }
}
