//
//  AniKatouApp.swift
//  AniKatou
//
//  Created by Bshar Esfky on 6/1/25.
//

import SwiftUI

@main
struct AniKatouApp: App {
    @AppStorage(APIConfig.apiConfigKey) private var apiBaseURL: String?
    
    var body: some Scene {
        WindowGroup {
            if apiBaseURL == nil {
                NavigationView {
                    APIConfigView(isInitialSetup: true)
                }
            } else {
            ContentView()
            }
        }
    }
}
