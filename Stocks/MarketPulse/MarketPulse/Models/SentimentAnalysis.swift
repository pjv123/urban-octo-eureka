import Foundation
import SwiftData

@Model
final class SentimentAnalysis {
    var score: Double
    var summary: String
    var analysisDate: Date
    var article: Article?

    init(score: Double, summary: String, analysisDate: Date) {
        self.score = score
        self.summary = summary
        self.analysisDate = analysisDate
    }
}