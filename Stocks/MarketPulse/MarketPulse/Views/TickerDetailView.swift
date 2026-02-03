import SwiftUI
import SwiftData

/// Detail view for a specific ticker showing all related news articles and sentiment analysis
struct TickerDetailView: View {
    /// The ticker being displayed
    let ticker: Ticker

    /// Environment object for navigation
    @Environment(\.modelContext) private var modelContext

    /// State for managing the analysis manager
    @State private var analysisManager: AnalysisManager?

    /// State for loading and error handling
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            // Ticker header section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(ticker.symbol)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Spacer()

                        Text(String(format: "$%.2f", ticker.currentPrice))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }

                    Text(ticker.name)
                        .font(.title2)

                    // Average sentiment indicator
                    HStack {
                        Text("Average Sentiment")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        SentimentIndicatorView(score: ticker.averageSentimentScore)
                            .frame(width: 100, height: 20)
                    }
                }
                .padding(.vertical)
            }

            // News articles section
            Section("News Articles") {
                if ticker.articles.isEmpty {
                    Text("No news articles available")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                } else {
                    ForEach(ticker.articles) { article in
                        ArticleRowView(article: article)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteArticle(article)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            // Actions section
            Section {
                Button(action: {
                    Task {
                        await analyzeAllArticles()
                    }
                }) {
                    Label("Analyze All Articles", systemImage: "brain")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(ticker.symbol)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task {
                        await refreshData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .task {
            await loadAnalysisManager()
        }
    }

    /// Load the analysis manager
    private func loadAnalysisManager() async {
        analysisManager = AnalysisManager(container: modelContext.container)
    }

    /// Analyze all articles for this ticker
    private func analyzeAllArticles() async {
        guard let analysisManager = analysisManager else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await analysisManager.analyzeArticles(for: ticker)
        } catch {
            errorMessage = error.localizedDescription
            print("Error analyzing articles: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Refresh data for this ticker
    private func refreshData() async {
        guard let analysisManager = analysisManager else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await analysisManager.updateStocksAndAnalyze(symbols: [ticker.symbol])
        } catch {
            errorMessage = error.localizedDescription
            print("Error refreshing data: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Delete an article
    private func deleteArticle(_ article: Article) {
        modelContext.delete(article)

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// View for displaying a single article with sentiment information
struct ArticleRowView: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.headline)
                .font(.headline)
                .lineLimit(2)

            Text(article.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack {
                Text(article.publishedDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let sentiment = article.sentimentAnalysis {
                    SentimentIndicatorView(score: sentiment.score)
                        .frame(width: 80, height: 20)
                } else {
                    ProgressView()
                        .frame(width: 80, height: 20)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

/// View for displaying sentiment as a colored indicator
struct SentimentIndicatorView: View {
    let score: Double

    var body: some View {
        HStack(spacing: 4) {
            // Sentiment score
            Text(String(format: "%.2f", score))
                .font(.caption)
                .fontWeight(.bold)

            // Sentiment color indicator
            Circle()
                .frame(width: 8, height: 8)
                .foregroundStyle(getSentimentColor())
        }
    }

    /// Get the appropriate color for the sentiment score
    private func getSentimentColor() -> Color {
        if score > 0.5 {
            return .green
        } else if score > 0 {
            return .yellow
        } else if score > -0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

extension Ticker {
    /// Calculate the average sentiment score for all articles
    var averageSentimentScore: Double {
        guard !articles.isEmpty else { return 0 }

        let total = articles.reduce(0) { $0 + $1.aiSentimentScore }
        return total / Double(articles.count)
    }
}