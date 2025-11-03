//
//  AppRoot.swift
//  AppWatcher
//
//  Created by D K on 08.10.2025.
//

import SwiftUI

struct AppRoot: View {
    @Environment(\.scenePhase) private var scenePhase
        
        private let updateManager = UpdateManager()
    
    var body: some View {
        ContentView()
            
    }
}

#Preview {
    AppRoot()
}
