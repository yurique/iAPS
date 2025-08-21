import Foundation

struct BGTargets: JSON {
    let units: GlucoseUnits
    let userPrefferedUnits: GlucoseUnits
    let targets: [BGTargetEntry]
}

extension BGTargets {
    private enum CodingKeys: String, CodingKey {
        case units
        case userPrefferedUnits = "user_preferred_units"
        case targets
    }

    static func defaultValue() -> BGTargets {
        BGTargets(units: .mmolL, userPrefferedUnits: .mmolL, targets: [])
    }
}

struct BGTargetEntry: JSON {
    let low: Decimal
    let high: Decimal
    let start: String
    let offset: Int
}
