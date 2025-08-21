import Foundation
import SwiftUI
import Swinject

extension Restore {
    final class StateModel: BaseStateModel<Provider> {
        let coreData = CoreDataStorage()

        func saveFile<T>(_ file: T, _ storage: (FileStorage) -> EntityStorage<T>) {
            let s = BaseFileStorage()
            storage(s).save(file)
            coreData.saveOnbarding()
        }
    }
}
