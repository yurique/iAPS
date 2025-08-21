import Foundation

protocol FileStorage {
    func rename(_ name: String, to newName: String)
    func transaction(_ exec: (FileStorage) -> Void)

    var bgTargets: EntityStorageWithFallback<BGTargets> { get }
    var pumpSettings: EntityStorageWithFallback<PumpSettings> { get }
    var pumpProfile: EntityStorage<Profile> { get }
    var profile: EntityStorage<Profile> { get }
    var autotune: EntityStorage<Profile> { get }
    var basalProfile: EntityStorageWithFallback<[BasalProfileEntry]> { get }
    var suggested: EntityStorage<Suggestion> { get }
    var enacted: EntityStorage<Suggestion> { get }
    var dynamicVariables: EntityStorage<DynamicVariables> { get }
    var battery: EntityStorage<Battery> { get }
    var calibrations: EntityStorageWithFallback<[Calibration]> { get }
    var carbRatios: EntityStorageWithFallback<CarbRatios> { get }
    var insulinSensitivities: EntityStorageWithFallback<InsulinSensitivities> { get }
    var autosens: EntityStorage<Autosens> { get }
    var contactPictureEntries: EntityStorageWithFallback<[ContactTrickEntry]> { get }
    var preferences: EntityStorageWithFallback<Preferences> { get }
    var reservoir: EntityStorage<Decimal> { get }
    var glucose: EntityStorageWithAppend<BloodGlucose> { get }
    var uploadedGlucose: EntityStorageWithFallback<[BloodGlucose]> { get }
    var tempBasal: EntityStorage<TempBasal> { get }
    var tempTargets: EntityStorageWithAppend<TempTarget> { get }
    var tempTargetPresets: EntityStorageWithAppend<TempTarget> { get }
    var uploadedTempTargets: EntityStorageWithFallback<[NigtscoutTreatment]> { get }
    var settings: EntityStorageWithFallback<FreeAPSSettings> { get }
    var cgmState: EntityStorageWithFallback<[NigtscoutTreatment]> { get }
    var uploadedPumpHistory: EntityStorageWithFallback<[NigtscoutTreatment]> { get }
    var pumpHistory: EntityStorageWithAppend<PumpHistoryEvent> { get }
    var statistics: EntityStorage<Statistics> { get }
    var pumpStatus: EntityStorage<PumpStatus> { get }
    var carbsHistory: EntityStorageWithAppend<CarbsEntry> { get }
    var uploadedCarbs: EntityStorageWithFallback<[NigtscoutTreatment]> { get }
    var announcements: EntityStorageWithAppend<Announcement> { get }
    var announcementsEnacted: EntityStorageWithAppend<Announcement> { get }
    var alertHistory: EntityStorageWithAppend<AlertEntry> { get }
    var iob: EntityStorageWithFallback<[IOBEntry]> { get }
    var nsStatus: EntityStorage<NightscoutStatus> { get }
    var uploadedOverridePresets: EntityStorage<OverrideDatabase> { get }
    var uploadedMealPresets: EntityStorage<MealDatabase> { get }
    var uploadedTempTargetsDatabase: EntityStorageWithFallback<[TempTarget]> { get }
    var uploadedPumpSettings: EntityStorage<PumpSettings> { get }
    var uploadedNsSettings: EntityStorage<NightscoutSettings> { get }
    var uploadedNsPreferences: EntityStorage<NightscoutPreferences> { get }
    var uploadedPodAge: EntityStorage<[NigtscoutTreatment]> { get }
    var podAge: EntityStorage<Date> { get }
    var uploadedProfile: EntityStorage<NightscoutProfileStore> { get }
    var uploadedPreferences: EntityStorage<Preferences> { get }
    var uploadedSettings: EntityStorage<FreeAPSSettings> { get }
    var notUploadedOverrides: EntityStorageWithAppend<NigtscoutExercise> { get }
    var uploadedManualGlucose: EntityStorage<[NigtscoutTreatment]> { get }
    var uploadedCGMState: EntityStorage<[NigtscoutTreatment]> { get }
    var meal: EntityStorage<RecentCarbs> { get }
    var model: EntityStorageWithFallback<String> { get }
    var middleware: EntityStorage<String> { get }

    // TODO: these two share the same file 🤔
    var uploadedProfileToDatabase: EntityStorage<DatabaseProfileStore> { get }
    var uploadedProfileToDatabaseNs: EntityStorage<NightscoutProfileStore> { get }
}

final class BaseFileStorage: FileStorage, Injectable {
    private let processQueue = DispatchQueue.markedQueue(
        label: "BaseFileStorage.processQueue",
        qos: .utility
    )

    let bgTargets = EntityStorageWithFallback<BGTargets>(
        file: OpenAPS.Settings.bgTargets,
        codec: EntityCodecs.json(),
        readDefaults: true,
        fallbackValue: BGTargets.defaultValue()
    )

    let pumpSettings = EntityStorageWithFallback<PumpSettings>(
        file: OpenAPS.Settings.pumpSettings,
        codec: EntityCodecs.json(),
        readDefaults: true,
        fallbackValue: PumpSettings.defaultValue()
    )

    let pumpProfile = EntityStorage<Profile>(
        file: OpenAPS.Settings.pumpProfile,
        codec: EntityCodecs.json(),
        readDefaults: false,
    )

    let profile = EntityStorage<Profile>(
        file: OpenAPS.Settings.profile,
        codec: EntityCodecs.json(),
        readDefaults: false,
    )

    let autotune = EntityStorage<Profile>(
        file: OpenAPS.Settings.autotune,
        codec: EntityCodecs.json(),
        readDefaults: false,
    )

    let basalProfile = EntityStorageWithFallback<[BasalProfileEntry]>(
        file: OpenAPS.Settings.basalProfile,
        codec: EntityCodecs.json(),
        readDefaults: true,
        fallbackValue: []
    )

    let suggested = EntityStorage<Suggestion>(
        file: OpenAPS.Enact.suggested,
        codec: EntityCodecs.json(),
    )

    let enacted = EntityStorage<Suggestion>(
        file: OpenAPS.Enact.enacted,
        codec: EntityCodecs.json(),
    )

    let dynamicVariables = EntityStorage<DynamicVariables>(
        file: OpenAPS.Monitor.dynamicVariables,
        codec: EntityCodecs.json(),
    )

    let battery = EntityStorage<Battery>(
        file: OpenAPS.Monitor.battery,
        codec: EntityCodecs.json(),
    )

    let calibrations = EntityStorageWithFallback<[Calibration]>(
        file: OpenAPS.FreeAPS.calibrations,
        codec: EntityCodecs.json(),
        fallbackValue: []
    )

    let carbRatios = EntityStorageWithFallback<CarbRatios>(
        file: OpenAPS.Settings.carbRatios,
        codec: EntityCodecs.json(),
        readDefaults: true,
        fallbackValue: CarbRatios.defaultValue()
    )

    let insulinSensitivities = EntityStorageWithFallback<InsulinSensitivities>(
        file: OpenAPS.Settings.insulinSensitivities,
        codec: EntityCodecs.json(),
        readDefaults: true,
        fallbackValue: InsulinSensitivities.defaultValue()
    )

    let autosens = EntityStorage<Autosens>(
        file: OpenAPS.Settings.autosense,
        codec: EntityCodecs.json(),
        readDefaults: true,
    )

    let contactPictureEntries = EntityStorageWithFallback<[ContactTrickEntry]>(
        file: OpenAPS.Settings.contactTrick,
        codec: EntityCodecs.json(),
        readDefaults: true,
        fallbackValue: []
    )

    let preferences = EntityStorageWithFallback<Preferences>(
        file: OpenAPS.Settings.preferences,
        codec: EntityCodecs.json(),
        readDefaults: true,
        fallbackValue: Preferences()
    )

    let reservoir = EntityStorage<Decimal>(
        file: OpenAPS.Monitor.reservoir,
        codec: EntityCodecs.decimal,
    )

    let glucose = EntityStorageWithAppend<BloodGlucose>(
        file: OpenAPS.Monitor.glucose,
    )

    let uploadedGlucose = EntityStorageWithFallback<[BloodGlucose]>(
        file: OpenAPS.Nightscout.uploadedGlucose,
        codec: EntityCodecs.json(),
        fallbackValue: []
    )

    let tempBasal = EntityStorage<TempBasal>(
        file: OpenAPS.Monitor.tempBasal,
        codec: EntityCodecs.json(),
    )

    let tempTargets = EntityStorageWithAppend<TempTarget>(
        file: OpenAPS.Settings.tempTargets,
    )

    let tempTargetPresets = EntityStorageWithAppend<TempTarget>(
        file: OpenAPS.FreeAPS.tempTargetsPresets,
    )

    let uploadedTempTargets = EntityStorageWithFallback<[NigtscoutTreatment]>(
        file: OpenAPS.Nightscout.uploadedTempTargets,
        codec: EntityCodecs.json(),
        fallbackValue: []
    )

    let uploadedTempTargetsDatabase = EntityStorageWithFallback<[TempTarget]>(
        file: OpenAPS.Nightscout.uploadedTempTargetsDatabase,
        codec: EntityCodecs.json(),
        fallbackValue: []
    )

    let settings = EntityStorageWithFallback<FreeAPSSettings>(
        file: OpenAPS.FreeAPS.settings,
        codec: EntityCodecs.json(),
        readDefaults: true,
        fallbackValue: FreeAPSSettings()
    )

    let cgmState = EntityStorageWithFallback<[NigtscoutTreatment]>(
        file: OpenAPS.Monitor.cgmState,
        codec: EntityCodecs.json(),
        fallbackValue: []
    )

    let uploadedPumpHistory = EntityStorageWithFallback<[NigtscoutTreatment]>(
        file: OpenAPS.Nightscout.uploadedPumphistory,
        codec: EntityCodecs.json(),
        fallbackValue: []
    )

    let pumpHistory = EntityStorageWithAppend<PumpHistoryEvent>(
        file: OpenAPS.Monitor.pumpHistory,
    )

    let statistics = EntityStorage<Statistics>(
        file: OpenAPS.Monitor.statistics,
        codec: EntityCodecs.json(),
    )

    let pumpStatus = EntityStorage<PumpStatus>(
        file: OpenAPS.Monitor.status,
        codec: EntityCodecs.json(),
    )

    let carbsHistory = EntityStorageWithAppend<CarbsEntry>(
        file: OpenAPS.Monitor.carbHistory,
    )

    let uploadedCarbs = EntityStorageWithFallback<[NigtscoutTreatment]>(
        file: OpenAPS.Nightscout.uploadedCarbs,
        codec: EntityCodecs.json(),
        fallbackValue: []
    )

    let announcements = EntityStorageWithAppend<Announcement>(
        file: OpenAPS.FreeAPS.announcements,
    )

    let announcementsEnacted = EntityStorageWithAppend<Announcement>(
        file: OpenAPS.FreeAPS.announcementsEnacted,
    )

    let alertHistory = EntityStorageWithAppend<AlertEntry>(
        file: OpenAPS.Monitor.alertHistory,
    )

    let iob = EntityStorageWithFallback<[IOBEntry]>(
        file: OpenAPS.Monitor.iob,
        codec: EntityCodecs.json(),
        fallbackValue: []
    )

    let nsStatus = EntityStorage<NightscoutStatus>(
        file: OpenAPS.Upload.nsStatus,
        codec: EntityCodecs.json(),
    )

    let uploadedOverridePresets = EntityStorage<OverrideDatabase>(
        file: OpenAPS.Nightscout.uploadedOverridePresets,
        codec: EntityCodecs.json(),
    )

    let uploadedMealPresets = EntityStorage<MealDatabase>(
        file: OpenAPS.Nightscout.uploadedMealPresets,
        codec: EntityCodecs.json(),
    )

    let uploadedPumpSettings = EntityStorage<PumpSettings>(
        file: OpenAPS.Nightscout.uploadedPumpSettings,
        codec: EntityCodecs.json(),
    )

    let uploadedNsSettings = EntityStorage<NightscoutSettings>(
        file: OpenAPS.Nightscout.uploadedSettings,
        codec: EntityCodecs.json(),
    )

    let uploadedNsPreferences = EntityStorage<NightscoutPreferences>(
        file: OpenAPS.Nightscout.uploadedPreferences,
        codec: EntityCodecs.json(),
    )

    let uploadedPodAge = EntityStorage<[NigtscoutTreatment]>(
        file: OpenAPS.Nightscout.uploadedPodAge,
        codec: EntityCodecs.json(),
    )

    let podAge = EntityStorage<Date>(
        file: OpenAPS.Monitor.podAge,
        codec: EntityCodecs.date,
    )

    let uploadedProfile = EntityStorage<NightscoutProfileStore>(
        file: OpenAPS.Nightscout.uploadedProfile,
        codec: EntityCodecs.json(),
    )

    let uploadedProfileToDatabase = EntityStorage<DatabaseProfileStore>(
        file: OpenAPS.Nightscout.uploadedProfileToDatabase,
        codec: EntityCodecs.json(),
    )

    let uploadedProfileToDatabaseNs = EntityStorage<NightscoutProfileStore>(
        file: OpenAPS.Nightscout.uploadedProfileToDatabase,
        codec: EntityCodecs.json(),
    )

    let uploadedPreferences = EntityStorage<Preferences>(
        file: OpenAPS.Nightscout.uploadedPreferences,
        codec: EntityCodecs.json(),
    )

    let uploadedSettings = EntityStorage<FreeAPSSettings>(
        file: OpenAPS.Nightscout.uploadedSettings,
        codec: EntityCodecs.json(),
    )

    let notUploadedOverrides = EntityStorageWithAppend<NigtscoutExercise>(
        file: OpenAPS.Nightscout.notUploadedOverrides,
    )

    let uploadedManualGlucose = EntityStorage<[NigtscoutTreatment]>(
        file: OpenAPS.Nightscout.uploadedManualGlucose,
        codec: EntityCodecs.json(),
    )

    let uploadedCGMState = EntityStorage<[NigtscoutTreatment]>(
        file: OpenAPS.Nightscout.uploadedCGMState,
        codec: EntityCodecs.json(),
    )

    let meal = EntityStorage<RecentCarbs>(
        file: OpenAPS.Monitor.meal,
        codec: EntityCodecs.json(),
    )

    let model = EntityStorageWithFallback<String>(
        file: OpenAPS.Settings.model,
        codec: EntityCodecs.json(),
        readDefaults: true,
        fallbackValue: "722"
    )

    let middleware = EntityStorage<String>(
        file: OpenAPS.Middleware.determineBasal,
        codec: EntityCodecs.string,
        readDefaults: true,
    )

    func rename(_ name: String, to newName: String) {
        processQueue.sync {
            try? Disk.rename(name, in: .documents, to: newName)
        }
    }

    func transaction(_ exec: (FileStorage) -> Void) {
        processQueue.safeSync {
            exec(self)
        }
    }
}
