import SwiftUI
import SwiftData

/// Main dashboard view showing all tickers and their sentiment analysis
struct DashboardView: View {
    /// Environment object for navigation
    @Environment(\.modelContext) private var modelContext

    /// State for managing the analysis manager
    @State private var analysisManager: AnalysisManager?

    /// State for loading and error handling
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// State for refresh control
    @State private var lastRefresh = Date()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && tickers.isEmpty {
                    ProgressView("Loading data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(tickers) { ticker in
                            TickerRowView(ticker: ticker)
                                .onTapGesture {
                                    // Navigate to ticker detail view
                                    print("Navigate to \(ticker.symbol) detail view")
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Market Pulse AI")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Market Pulse AI")
                            .font(.headline)
                        Text("Last updated: \(lastRefresh, style: .time)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

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
                await refreshData()
            }
        }
    }

    /// Load the analysis manager
    private func loadAnalysisManager() async {
        analysisManager = AnalysisManager(container: modelContext.container)
    }

    /// Refresh all data
    private func refreshData() async {
        guard let analysisManager = analysisManager else { return }

        isLoading = true
        lastRefresh = Date()
        errorMessage = nil

        do {
            // Update stock prices and analyze news
            try await analysisManager.updateStocksAndAnalyze(symbols: ["AAPL", "MSFT", "GOOGL", "AMZN", "META"])

            // Analyze all existing articles
            try await analysisManager.analyzeAllTickers()

        } catch {
            errorMessage = error.localizedDescription
            print("Error refreshing data: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Fetch all tickers from the database
    private var tickers: [Ticker] {
        do {
            return try modelContext.fetch(FetchDescriptor<Ticker>())
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }
}

/// View for displaying a single ticker row with sentiment information
struct TickerRowView: View {
    let ticker: Ticker

    var body: some View {
        HStack(spacing: 16) {
            // Ticker symbol and name
            VStack(alignment: .leading, spacing: 4) {
                Text(ticker.symbol)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(ticker.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(format: "$%.2f", ticker.currentPrice))
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Spacer()

            // Sentiment sparkline (placeholder)
            SentimentSparklineView(score: ticker.averageSentimentScore)
                .frame(width: 100, height: 40)

            // Navigation indicator
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// View for displaying sentiment as a sparkline
struct SentimentSparklineView: View {
    let score: Double

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let centerY = height / 2

                // Draw baseline
                path.move(to: CGPoint(x: 0, y: centerY))
                path.addLine(to: CGPoint(x: width, y: centerY))
                path.stroke(style: StrokeStyle(lineWidth: 1, dash: [2]))

                // Draw sentiment line
                let x = width * 0.7
                let y = centerY - (score * height * 0.3)
                path.move(to: CGPoint(x: width * 0.3, y: centerY))
                path.addLine(to: CGPoint(x: x, y: y))

                // Draw sentiment dot
                path.addEllipse(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
            }
            .stroke(score >= 0 ? Color.green : Color.red, lineWidth: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DashboardView()
}