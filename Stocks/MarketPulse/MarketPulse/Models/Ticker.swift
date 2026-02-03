import Foundation
import SwiftData

@Model
final class Ticker {
    var symbol: String
    var name: String
    var currentPrice: Double
    var articles: [Article] = []

    init(symbol: String, name: String, currentPrice: Double) {
        self.symbol = symbol
        self.name = name
        self.currentPrice = currentPrice
    }
}