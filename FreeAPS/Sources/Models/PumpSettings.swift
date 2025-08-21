import Foundation

struct PumpSettings: JSON {
    let insulinActionCurve: Decimal
    let maxBolus: Decimal
    let maxBasal: Decimal
}

extension PumpSettings {
    private enum CodingKeys: String, CodingKey {
        case insulinActionCurve = "insulin_action_curve"
        case maxBolus
        case maxBasal
    }
    
    static func defaultValue() -> PumpSettings {
        PumpSettings(insulinActionCurve: 6, maxBolus: 10, maxBasal: 2)
    }
    
}
