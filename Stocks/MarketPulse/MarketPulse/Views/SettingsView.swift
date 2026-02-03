import SwiftUI
import SwiftData

/// Settings view for configuring the app preferences
struct SettingsView: View {
    /// Environment object for navigation
    @Environment(\.modelContext) private var modelContext

    /// State for managing the analysis manager
    @State private var analysisManager: AnalysisManager?

    /// State for available models
    @State private var availableModels: [String] = []

    /// State for loading and error handling
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// State for showing model selection
    @State private var selectedModel: String = "llama3"

    var body: some View {
        Form {
            Section(header: Text("AI Model Settings")) {
                Picker("Model", selection: $selectedModel) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)

                Button(action: {
                    Task {
                        await applyModelSettings()
                    }
                }) {
                    Label("Apply Settings", systemImage: "checkmark.circle.fill")
                }
                .disabled(selectedModel.isEmpty)
            }

            Section(header: Text("About")) {
                Text("Market Pulse AI")
                    .font(.headline)
                Text("Version 1.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Uses local Ollama instance for sentiment analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task {
                        await refreshAvailableModels()
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
            await refreshAvailableModels()
        }
    }

    /// Load the analysis manager
    private func loadAnalysisManager() async {
        analysisManager = AnalysisManager(container: modelContext.container)
    }

    /// Refresh the list of available models from Ollama
    private func refreshAvailableModels() async {
        guard let analysisManager = analysisManager else { return }

        isLoading = true
        errorMessage = nil

        do {
            availableModels = try await analysisManager.getAvailableModels()

            // Set default if available
            if !availableModels.isEmpty && !availableModels.contains(selectedModel) {
                selectedModel = availableModels.first ?? "llama3"
            }

        } catch {
            errorMessage = error.localizedDescription
            print("Error fetching available models: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Apply the selected model settings
    private func applyModelSettings() async {
        guard let analysisManager = analysisManager else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Set the default model in AnalysisManager
            await analysisManager.setDefaultModel(selectedModel)

        } catch {
            errorMessage = error.localizedDescription
            print("Error applying settings: \(error.localizedDescription)")
        }

        isLoading = false
    }
}