import Foundation
import SwiftData

/// Actor class that orchestrates the sentiment analysis workflow
/// Handles the loop: Fetch News -> Send to Ollama -> Save Result to SwiftData
@ModelActor
actor AnalysisManager {
    /// Service for communicating with Ollama API
    private lazy var ollamaService: OllamaService = OllamaService()

    /// Service for fetching stock data
    private lazy var stockDataService: StockDataService = StockDataService()

    /// Default model to use for sentiment analysis
    private var defaultModel = "llama3"

    /// Initialize the AnalysisManager
    /// - Parameters:
    ///   - container: SwiftData ModelContainer for persistence
    init(container: ModelContainer) {
        self.modelContainer = container
        self.modelExecutor = MainActor.assumeIsolated {
            container.mainContext
        } as! any ModelExecutor
    }

    /// Analyze sentiment for all articles associated with a ticker
    /// - Parameter ticker: The ticker to analyze articles for
    /// - Throws: Errors during analysis process
    func analyzeArticles(for ticker: Ticker) async throws {
        // Fetch all articles and filter in memory
        let allArticles = try modelContext.fetch(FetchDescriptor<Article>())
        let articles = allArticles.filter { $0.ticker?.id == ticker.id }

        // Analyze each article
        for article in articles {
            try await analyzeArticle(article)
        }
    }

    /// Analyze sentiment for a single article
    /// - Parameter article: The article to analyze
    /// - Throws: Errors during analysis process
    func analyzeArticle(_ article: Article) async throws {
        // Skip if already analyzed
        if article.sentimentAnalysis != nil {
            return
        }

        // Create refined prompt for sentiment analysis
        // Using structured prompt engineering for better results
        let prompt = """
        You are a financial news analyst. Analyze the following article and determine the sentiment.
        Consider factors like:
        - Positive indicators: growth, earnings, innovation, partnerships, positive guidance
        - Negative indicators: losses, layoffs, lawsuits, negative guidance, regulatory issues

        Return ONLY a valid JSON object with:
        - "score": A sentiment score between -1 and 1 (negative to positive, with -1 being very negative and 1 being very positive)
        - "summary": A concise explanation (1-2 sentences) of why this sentiment was assigned

        Article:
        Headline: \(article.headline)
        Summary: \(article.summary)

        Sentiment Analysis (JSON only):
        """

        do {
            // Send to Ollama for analysis
            let sentimentData = try await ollamaService.analyzeSentiment(
                for: prompt,
                model: defaultModel
            )

            // Extract score and summary from response
            guard let score = sentimentData["score"] as? Double,
                  let summary = sentimentData["summary"] as? String else {
                throw AnalysisError.invalidSentimentResponse
            }

            // Validate score range
            let clampedScore = max(-1.0, min(1.0, score))

            // Create sentiment analysis object
            let analysis = SentimentAnalysis(
                score: clampedScore,
                summary: summary,
                analysisDate: Date()
            )

            // Save to SwiftData
            article.sentimentAnalysis = analysis
            article.aiSentimentScore = clampedScore

            try modelContext.insert(analysis)
            try modelContext.save()

        } catch {
            throw AnalysisError.analysisFailed(error)
        }
    }

    /// Fetch news articles for a ticker and analyze their sentiment
    /// - Parameter ticker: The ticker to fetch news for
    /// - Throws: Errors during fetch or analysis
    func fetchAndAnalyzeNews(for ticker: Ticker) async throws {
        // In a real implementation, this would fetch news from an API
        // For now, we'll simulate fetching news articles

        // This is a placeholder - in a real app, you would:
        // 1. Fetch news articles from a financial news API
        // 2. Create Article objects
        // 3. Save them to SwiftData
        // 4. Call analyzeArticles(for:)

        print("Fetching news for \(ticker.symbol)...")
        // Simulate fetching news
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // In a real implementation, you would have actual news data here
        // For demonstration, we'll just print a message
        print("News fetched for \(ticker.symbol). Ready for sentiment analysis.")
    }

    /// Analyze all tickers in the database
    /// - Throws: Errors during analysis process
    func analyzeAllTickers() async throws {
        // Fetch all tickers
        let tickers = try modelContext.fetch(FetchDescriptor<Ticker>())

        // Analyze each ticker's articles
        for ticker in tickers {
            try await analyzeArticles(for: ticker)
        }
    }

    /// Update stock prices and analyze related news
    /// - Parameter symbols: Array of ticker symbols to update
    /// - Throws: Errors during update or analysis
    func updateStocksAndAnalyze(symbols: [String]) async throws {
        // Fetch current prices
        let prices = try await stockDataService.getCurrentPrices(for: symbols)

        // Update tickers in database
        for priceData in prices {
            guard let symbol = priceData["symbol"] as? String,
                  let price = priceData["price"] as? Double else {
                continue
            }

            let predicate = #Predicate<Ticker> { $0.symbol == symbol }
            let descriptor = FetchDescriptor<Ticker>(predicate: predicate)

            if let ticker = try modelContext.fetch(descriptor).first {
                ticker.currentPrice = price
                try modelContext.save()

                // Fetch and analyze news for this ticker
                try await fetchAndAnalyzeNews(for: ticker)
            }
        }
    }

    /// Get available models from Ollama
    /// - Returns: Array of available model names
    /// - Throws: Errors from OllamaService
    func getAvailableModels() async throws -> [String] {
        return try await ollamaService.getAvailableModels()
    }

    /// Set the default model for sentiment analysis
    /// - Parameter model: The model name (e.g., "llama3", "mistral")
    func setDefaultModel(_ model: String) {
        self.defaultModel = model
    }

    /// Get the current default model
    /// - Returns: The current default model name
    func getDefaultModel() -> String {
        return defaultModel
    }
}

/// Errors that can occur during analysis
enum AnalysisError: Error, LocalizedError {
    case invalidSentimentResponse
    case analysisFailed(Error)
    case databaseError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidSentimentResponse:
            return "Invalid sentiment analysis response from Ollama"
        case .analysisFailed(let error):
            return "Sentiment analysis failed: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}