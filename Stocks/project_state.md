# Project: MarketPulse AI (macOS Native)
\
## 1. Project Goal
Build a native macOS financial dashboard that tracks stock prices and uses a local LLM (via Ollama) to perform sentiment analysis on related news articles.\
\
## 2. Master Plan
### Phase 1: Data Layer (The Foundation)
- [x] **Task 1:** Initialize Xcode project with **SwiftData** (or CoreData). Define Models: `Ticker` (symbol, price), `Article` (headline, summary), and `SentimentAnalysis` (score, summary).
- [x] **Task 2:** Build `OllamaService.swift`. This must communicate with `http://localhost:11434` to send prompts and receive JSON responses.
- [x] **Task 3:** Build `StockDataService.swift`. Use a free API (e.g., Yahoo Finance or AlphaVantage) to fetch live prices.\
\
### Phase 2: The Logic (The Glue)
- [x] **Task 4:** Create `AnalysisManager`. This actor class must orchestrate the loop: Fetch News -> Send to Ollama -> Save Result to SwiftData.
- [x] **Task 5:** Implement the "Prompt Engineering" logic inside Swift. The app needs to generate a prompt like *"Analyze this headline: [text]. Return JSON with sentiment -1 to 1."*\
\
### Phase 3: The Interface (The Visuals)
- [x] **Task 6:** Build `DashboardView`. Display a list of Tickers with a dynamic "Sentiment Sparkline" (SwiftCharts) next to them.
- [x] **Task 7:** Build `TickerDetailView`. Show the raw news articles and the AI's explanation of *why* it is bullish/bearish.
- [x] **Task 8:** Implement a "Settings" view to select which local Model to use (e.g., "Use Llama 3" vs "Use Mistral").\
\
## 3. Current Status
- **Phase:** Complete
- **Last Completed Task:** Task 8 - Settings View completed
- **Current Problem:** None
\
## 4. Next Immediate Task
- **Task:** Project Complete - Ready for testing
- **Details:**
    1. All core functionality implemented
    2. Data models, services, and managers in place
    3. UI components built and ready
    4. Ready to test with local Ollama instance
\
## 5. Constraints
- **Stack:** Swift 6, SwiftUI, SwiftData, SwiftCharts.
- **AI Engine:** Local Ollama instance (localhost:11434).
- **Concurrency:** STRICT use of Actors for the `AnalysisManager` to prevent data races.