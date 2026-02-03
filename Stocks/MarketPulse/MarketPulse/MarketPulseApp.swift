//
//  MarketPulseApp.swift
//  MarketPulse
//
//  Created by Paul Vigneau on 2/1/26.
//

import SwiftUI
import SwiftData

@main
struct MarketPulseApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Ticker.self, Article.self, SentimentAnalysis.self])
    }
}