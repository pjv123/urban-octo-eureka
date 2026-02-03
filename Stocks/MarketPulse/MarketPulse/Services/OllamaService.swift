import Foundation

/// Service for communicating with the Ollama API running locally
/// Handles sending prompts and receiving JSON responses
class OllamaService {
    /// Base URL for Ollama API
    private let baseURL = "http://localhost:11434"

    /// Default timeout for network requests
    private let timeoutInterval: TimeInterval = 30.0

    /// Default model to use if none is specified
    private let defaultModel = "llama3"

    /// Send a prompt to Ollama and receive a JSON response
    /// - Parameters:
    ///   - prompt: The text prompt to send to the LLM
    ///   - model: The specific model to use (e.g., "llama3", "mistral")
    ///   - responseFormat: The format for the response (default: "json")
    /// - Returns: Dictionary containing the JSON response from Ollama
    /// - Throws: Network errors or JSON parsing errors
    func sendPrompt(
        _ prompt: String,
        model: String = "llama3",
        responseFormat: String = "json"
    ) async throws -> [String: Any] {
        let endpoint = "\(baseURL)/api/generate"

        // Prepare the request body
        let requestBody: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "format": responseFormat,
            "stream": false
        ]

        // Create URL
        guard let url = URL(string: endpoint) else {
            throw OllamaError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval

        // Set request body
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
        } catch {
            throw OllamaError.serializationError(error)
        }

        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OllamaError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse JSON response
        do {
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw OllamaError.invalidJSON
            }
            return jsonResponse
        } catch {
            throw OllamaError.parsingError(error)
        }
    }

    /// Send a prompt specifically for sentiment analysis
    /// - Parameters:
    ///   - articleText: The article text to analyze
    ///   - model: The specific model to use
    /// - Returns: Sentiment analysis result as a dictionary
    /// - Throws: Network errors or JSON parsing errors
    func analyzeSentiment(
        for articleText: String,
        model: String = "llama3"
    ) async throws -> [String: Any] {
        let prompt = """
        Analyze the following article text and determine the sentiment.
        Return a JSON object with:
        - "score": A sentiment score between -1 and 1 (negative to positive)
        - "summary": A brief explanation of why this sentiment was assigned

        Article text: \(articleText)

        Sentiment analysis:
        """

        let response = try await sendPrompt(prompt, model: model)

        // Extract the response text from the Ollama API response
        guard let responseText = response["response"] as? String else {
            throw OllamaError.missingResponseText
        }

        // Parse the JSON from the response text
        guard let sentimentData = try? JSONSerialization.jsonObject(with: responseText.data(using: .utf8)!) as? [String: Any] else {
            // Fallback: Try to parse directly from the response
            guard let sentimentData = response["sentiment"] as? [String: Any] else {
                throw OllamaError.invalidSentimentFormat
            }
            return sentimentData
        }

        return sentimentData
    }

    /// Get available models from Ollama
    /// - Returns: Array of available model names
    /// - Throws: Network errors or JSON parsing errors
    func getAvailableModels() async throws -> [String] {
        let endpoint = "\(baseURL)/api/tags"

        guard let url = URL(string: endpoint) else {
            throw OllamaError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OllamaError.serverError(statusCode: 0, message: "Failed to fetch models")
        }

        do {
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = jsonResponse["models"] as? [[String: Any]] else {
                throw OllamaError.invalidJSON
            }

            return models.compactMap { $0["name"] as? String }
        } catch {
            throw OllamaError.parsingError(error)
        }
    }
}

/// Errors that can occur when using OllamaService
enum OllamaError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidJSON
    case invalidSentimentFormat
    case serverError(statusCode: Int, message: String)
    case serializationError(Error)
    case parsingError(Error)
    case missingResponseText
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for Ollama API"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidJSON:
            return "Invalid JSON in response"
        case .invalidSentimentFormat:
            return "Invalid sentiment analysis format"
        case .serverError(let statusCode, let message):
            return "Server error \(statusCode): \(message)"
        case .serializationError(let error):
            return "Serialization error: \(error.localizedDescription)"
        case .parsingError(let error):
            return "Parsing error: \(error.localizedDescription)"
        case .missingResponseText:
            return "Missing response text in Ollama API response"
        case .timeout:
            return "Request timed out"
        }
    }
}