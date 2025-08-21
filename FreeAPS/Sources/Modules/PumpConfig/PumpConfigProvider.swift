import Combine
import LoopKitUI
import RileyLinkBLEKit

extension PumpConfig {
    final class Provider: BaseProvider, PumpConfigProvider {
        @Injected() var apsManager: APSManager!

        func setPumpManager(_ manager: PumpManagerUI) {
            apsManager.pumpManager = manager
        }

        var pumpDisplayState: AnyPublisher<PumpDisplayState?, Never> {
            apsManager.pumpDisplayState.eraseToAnyPublisher()
        }

        func basalProfile() -> [BasalProfileEntry] {
            storage.pumpProfile.retrieveOpt()?.basalProfile
                ?? [BasalProfileEntry(start: "00:00", minutes: 0, rate: 1)]
        }

        func pumpSettings() -> PumpSettings {
            storage.pumpSettings.retrieve()
        }

        var alertNotAck: AnyPublisher<Bool, Never> {
            deviceManager.alertHistoryStorage.alertNotAck.eraseToAnyPublisher()
        }

        func initialAlertNotAck() -> Bool {
            deviceManager.alertHistoryStorage.recentNotAck().isNotEmpty
        }
    }
}
