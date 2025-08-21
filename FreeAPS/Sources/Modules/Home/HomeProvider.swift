import Foundation
import LoopKitUI
import SwiftDate

extension Home {
    final class Provider: BaseProvider, HomeProvider {
        @Injected() var apsManager: APSManager!
        @Injected() var glucoseStorage: GlucoseStorage!
        @Injected() var pumpHistoryStorage: PumpHistoryStorage!
        @Injected() var tempTargetsStorage: TempTargetsStorage!
        @Injected() var carbsStorage: CarbsStorage!
        @Injected() var announcementStorage: AnnouncementsStorage!

        var suggestion: Suggestion? {
            storage.suggested.retrieveOpt()
        }

        var dynamicVariables: DynamicVariables? {
            storage.dynamicVariables.retrieveOpt()
        }

        let overrideStorage = OverrideStorage()

        func overrides() -> [Override] {
            overrideStorage.fetchOverrides(interval: DateFilter().day)
        }

        func overrideHistory() -> [OverrideHistory] {
            overrideStorage.fetchOverrideHistory(interval: DateFilter().day)
        }

        var enactedSuggestion: Suggestion? {
            storage.enacted.retrieveOpt()
        }

        func iob() async throws -> Decimal? {
            await apsManager.iobSync()
        }

        func reasons() -> [IOBData]? {
            let reasons = CoreDataStorage().fetchReasons(interval: DateFilter().day)

            guard reasons.count > 3 else {
                return nil
            }

            return reasons.compactMap {
                entry -> IOBData in
                IOBData(
                    date: entry.date ?? Date(),
                    iob: (entry.iob ?? 0) as Decimal,
                    cob: (entry.cob ?? 0) as Decimal
                )
            }
        }

        func pumpTimeZone() -> TimeZone? {
            apsManager.pumpManager?.status.timeZone
        }

        func heartbeatNow() {
            apsManager.heartbeat(date: Date())
        }

        func filteredGlucose(hours: Int) -> [BloodGlucose] {
            glucoseStorage.recent().filter {
                $0.dateString.addingTimeInterval(hours.hours.timeInterval) > Date()
            }
        }

        func manualGlucose(hours: Int) -> [BloodGlucose] {
            glucoseStorage.recent().filter {
                $0.type == GlucoseType.manual.rawValue &&
                    $0.dateString.addingTimeInterval(hours.hours.timeInterval) > Date()
            }
        }

        func pumpHistory(hours: Int) -> [PumpHistoryEvent] {
            pumpHistoryStorage.recent().filter {
                $0.timestamp.addingTimeInterval(hours.hours.timeInterval) > Date()
            }
        }

        func tempTargets(hours: Int) -> [TempTarget] {
            tempTargetsStorage.recent().filter {
                $0.createdAt.addingTimeInterval(hours.hours.timeInterval) > Date()
            }
        }

        func tempTarget() -> TempTarget? {
            tempTargetsStorage.current()
        }

        func carbs(hours: Int) -> [CarbsEntry] {
            carbsStorage.recent().filter {
                $0.createdAt.addingTimeInterval(hours.hours.timeInterval) > Date() && $0.carbs > 0
            }
        }

        func announcement(_ hours: Int) -> [Announcement] {
            announcementStorage.validate().filter {
                $0.createdAt.addingTimeInterval(hours.hours.timeInterval) > Date()
            }
        }

        func pumpSettings() -> PumpSettings {
            storage.pumpSettings.retrieve()
        }

        func pumpBattery() -> Battery? {
            storage.battery.retrieveOpt()
        }

        func pumpReservoir() -> Decimal? {
            storage.reservoir.retrieveOpt()
        }

        func autotunedBasalProfile() -> [BasalProfileEntry] {
            storage.profile.retrieveOpt()?.basalProfile
                ?? storage.pumpProfile.retrieveOpt()?.basalProfile
                ?? [BasalProfileEntry(start: "00:00", minutes: 0, rate: 1)]
        }

        func basalProfile() -> [BasalProfileEntry] {
            storage.pumpProfile.retrieveOpt()?.basalProfile
                ?? [BasalProfileEntry(start: "00:00", minutes: 0, rate: 1)]
        }
    }
}
