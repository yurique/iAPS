import Foundation
import SwiftDate
import Swinject

protocol AnnouncementsStorage {
    func storeAnnouncements(_ announcements: [Announcement], enacted: Bool)
    func syncDate() -> Date
    func recent() -> Announcement?
    func validate() -> [Announcement]
    func recentEnacted() -> Announcement?
}

final class BaseAnnouncementsStorage: AnnouncementsStorage, Injectable {
    enum Config {
        static let recentInterval = 10.minutes.timeInterval
    }

    private let processQueue = DispatchQueue(label: "BaseAnnouncementsStorage.processQueue")
    @Injected() private var storage: FileStorage!

    init(resolver: Resolver) {
        injectServices(resolver)
    }

    func storeAnnouncements(_ announcements: [Announcement], enacted: Bool) {
        processQueue.sync {
            let announcementStorage = enacted ? self.storage.announcementsEnacted : self.storage.announcements
            self.storage.transaction { _ in
                let uniqEvents = announcementStorage.append(announcements, uniqBy: \.createdAt)
                    .filter { $0.createdAt.addingTimeInterval(1.days.timeInterval) > Date() }
                    .sorted { $0.createdAt > $1.createdAt }
                announcementStorage.save(Array(uniqEvents))
            }
        }
    }

    func syncDate() -> Date {
        guard let events = storage.announcementsEnacted.retrieveOpt(),
              let recentEnacted = events.filter({ $0.enteredBy == Announcement.remote }).first
        else {
            return Date().addingTimeInterval(-Config.recentInterval)
        }
        return recentEnacted.createdAt.addingTimeInterval(Config.recentInterval)
    }

    func recent() -> Announcement? {
        guard let events = storage.announcements.retrieveOpt()
        else {
            return nil
        }
        guard let recent = events
            .filter({
                $0.enteredBy == Announcement.remote && $0.createdAt.addingTimeInterval(Config.recentInterval) > Date()
            })
            .first
        else {
            return nil
        }
        guard let enactedEvents = storage.announcementsEnacted.retrieveOpt()
        else {
            return recent
        }

        guard enactedEvents.first(where: { $0.createdAt == recent.createdAt }) == nil
        else {
            return nil
        }
        return recent
    }

    func recentEnacted() -> Announcement? {
        guard let enactedEvents = storage.announcementsEnacted.retrieveOpt()
        else {
            return nil
        }
        let enactedEventsLast = enactedEvents.first

        if -1 * (enactedEventsLast?.createdAt ?? .distantPast).timeIntervalSinceNow.minutes <= 10 {
            return enactedEventsLast
        }
        return nil
    }

    func validate() -> [Announcement] {
        guard let enactedEvents = storage.announcementsEnacted.retrieveOpt()?.reversed()
        else {
            return []
        }
        let validate = enactedEvents
            .filter({ $0.enteredBy == Announcement.remote })
        return validate
    }
}
