import Foundation

/// Service for fetching stock market data from Yahoo Finance API
/// Provides current stock prices and basic market information
class StockDataService {
    /// Base URL for Yahoo Finance API
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart"

    /// Default timeout for network requests
    private let timeoutInterval: TimeInterval = 30.0

    /// Fetch current stock price for a given ticker symbol
    /// - Parameter symbol: The stock ticker symbol (e.g., "AAPL", "MSFT")
    /// - Returns: Dictionary containing stock price information
    /// - Throws: Network errors or JSON parsing errors
    func getCurrentPrice(for symbol: String) async throws -> [String: Any] {
        let endpoint = "\(baseURL)/\(symbol)"

        // Create URL with query parameters
        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "1d")
        ]

        guard let url = components?.url else {
            throw StockDataError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutInterval

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockDataError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw StockDataError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse JSON response
        do {
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = jsonResponse["chart"] as? [String: Any],
                  let result = chart["result"] as? [Any],
                  let firstResult = result.first as? [String: Any] else {
                throw StockDataError.invalidJSON
            }

            // Extract price information
            guard let meta = firstResult["meta"] as? [String: Any],
                  let regularMarketPrice = meta["regularMarketPrice"] as? Double,
                  let currency = meta["currency"] as? String,
                  let symbol = meta["symbol"] as? String else {
                throw StockDataError.missingPriceData
            }

            let priceData: [String: Any] = [
                "symbol": symbol,
                "price": regularMarketPrice,
                "currency": currency,
                "timestamp": Date().timeIntervalSince1970
            ]

            return priceData
        } catch {
            throw StockDataError.parsingError(error)
        }
    }

    /// Fetch multiple stock prices at once
    /// - Parameter symbols: Array of stock ticker symbols
    /// - Returns: Array of dictionaries containing stock price information
    /// - Throws: Network errors or JSON parsing errors
    func getCurrentPrices(for symbols: [String]) async throws -> [[String: Any]] {
        var results = [[String: Any]]()

        for symbol in symbols {
            do {
                let priceData = try await getCurrentPrice(for: symbol)
                results.append(priceData)
            } catch {
                // Continue with next symbol if one fails
                print("Error fetching price for \(symbol): \(error.localizedDescription)")
                continue
            }
        }

        return results
    }

    /// Search for stocks by name or symbol
    /// - Parameter query: Search query (company name or ticker symbol)
    /// - Returns: Array of dictionaries containing search results
    /// - Throws: Network errors or JSON parsing errors
    func searchStocks(query: String) async throws -> [[String: Any]] {
        let searchURL = "https://query1.finance.yahoo.com/v1/finance/search"

        guard let url = URL(string: "\(searchURL)?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            throw StockDataError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StockDataError.serverError(statusCode: 0, message: "Search failed")
        }

        do {
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = jsonResponse["quotes"] as? [[String: Any]] else {
                throw StockDataError.invalidJSON
            }

            return results
        } catch {
            throw StockDataError.parsingError(error)
        }
    }
}

/// Errors that can occur when using StockDataService
enum StockDataError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidJSON
    case serverError(statusCode: Int, message: String)
    case parsingError(Error)
    case missingPriceData
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for stock data API"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidJSON:
            return "Invalid JSON in response"
        case .serverError(let statusCode, let message):
            return "Server error \(statusCode): \(message)"
        case .parsingError(let error):
            return "Parsing error: \(error.localizedDescription)"
        case .missingPriceData:
            return "Missing price data in API response"
        case .timeout:
            return "Request timed out"
        }
    }
}