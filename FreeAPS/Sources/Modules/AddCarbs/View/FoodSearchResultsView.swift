import LoopKit
import SwiftUI

struct AIFoodItem: Identifiable {
    var id: String {
        "\(name)-\(brand ?? "")-\(calories)-\(carbs)"
    }

    let name: String
    let brand: String?
    let calories: Decimal
    let carbs: Decimal
    let protein: Decimal
    let fat: Decimal
    let imageURL: String?
    let source: FoodItemSource?

//    enum CodingKeys: String, CodingKey {
//        case name
//        case brand
//        case calories
//        case carbs
//        case protein
//        case fat
//        case imageURL
//    }
//
//    static func == (lhs: AIFoodItem, rhs: AIFoodItem) -> Bool {
//        lhs.id == rhs.id
//    }
}
