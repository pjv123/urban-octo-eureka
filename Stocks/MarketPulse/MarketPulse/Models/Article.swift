import Foundation
import SwiftData

@Model
final class Article {
    var headline: String
    var summary: String
    var publishedDate: Date
    var url: String
    var aiSentimentScore: Double
    var sentimentAnalysis: SentimentAnalysis?
    var ticker: Ticker?

    init(headline: String, summary: String, publishedDate: Date, url: String, aiSentimentScore: Double) {
        self.headline = headline
        self.summary = summary
        self.publishedDate = publishedDate
        self.url = url
        self.aiSentimentScore = aiSentimentScore
    }
}