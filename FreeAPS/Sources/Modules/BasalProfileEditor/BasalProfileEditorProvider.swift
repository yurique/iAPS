import Combine
import Foundation
import LoopKit

extension BasalProfileEditor {
    final class Provider: BaseProvider, BasalProfileEditorProvider {
        private let processQueue = DispatchQueue(label: "BasalProfileEditorProvider.processQueue")

        var profile: [BasalProfileEntry] {
            storage.basalProfile.retrieveOpt() ?? []
        }

        var supportedBasalRates: [Decimal]? {
            deviceManager.pumpManager?.supportedBasalRates.map { Decimal($0) }
        }

        var concentration: Double {
            CoreDataStorage().insulinConcentration().concentration
        }

        func saveProfile(_ profile: [BasalProfileEntry]) -> AnyPublisher<Void, Error> {
            guard let pump = deviceManager?.pumpManager else {
                storage.basalProfile.save(profile)
                return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
            }

            let syncValues = profile.map {
                RepeatingScheduleValue(
                    startTime: TimeInterval($0.minutes * 60),
                    value: Double($0.rate) / concentration
                )
            }

            return Future { promise in
                pump.syncBasalRateSchedule(items: syncValues) { result in
                    switch result {
                    case .success:
                        self.storage.basalProfile.save(profile)
                        promise(.success(()))
                    case let .failure(error):
                        promise(.failure(error))
                    }
                }
            }.eraseToAnyPublisher()
        }
    }
}
