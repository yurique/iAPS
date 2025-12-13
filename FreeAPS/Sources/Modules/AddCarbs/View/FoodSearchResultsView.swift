import LoopKit
import SwiftUI

// MARK: - AI Food Search Result Row

private struct AIFoodSearchResultRow: View {
    let product: AIFoodItem
    let onSelected: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundColor(.purple)
                )

            // Product details
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let brand = product.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // Nutrition info
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1fg carbs per 100g", product.carbs))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)

                    // Additional nutrition
                    HStack(spacing: 8) {
                        Text(String(format: "%.1fg protein", product.protein))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(String(format: "%.1fg fat", product.fat))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(String(format: "%.0f kcal", product.calories))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelected()
            }

            // Selection indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AIFoodItem: Identifiable, Codable, Equatable {
    var id: String {
        "\(name)-\(brand ?? "")-\(calories)-\(carbs)"
    }

    let name: String
    let brand: String?
    let calories: Double
    let carbs: Double
    let protein: Double
    let fat: Double
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case calories
        case carbs
        case protein
        case fat
        case imageURL
    }

    static func == (lhs: AIFoodItem, rhs: AIFoodItem) -> Bool {
        lhs.id == rhs.id
    }
}
