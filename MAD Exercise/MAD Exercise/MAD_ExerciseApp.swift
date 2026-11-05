//
//  MAD_ExerciseApp.swift
//  MAD Exercise
//
//  Created by Gustavo Podzuweit on 28.09.26.
//

import SwiftUI

@main
struct MAD_ExerciseApp: App {
    // The single Networking (and thus URLSession) instance for the whole app.
    @State private var networking = Networking()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                LoginView()
            }
            .environment(networking)
        }
    }
}
