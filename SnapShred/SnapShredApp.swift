//
//  SnapShredApp.swift
//  SnapShred
//
//  Created by Rahul Dagar on 2026-10-01.
//

import SwiftUI

@main
struct SnapShredApp: App {
    @State private var authorization = LibraryAuthorization()
    @State private var session = SwipeSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if authorization.canBrowse {
                    DeckScreen()
                        .transition(.opacity)
                } else {
                    WelcomeView()
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.5), value: authorization.canBrowse)
            .preferredColorScheme(.dark)
            .environment(authorization)
            .environment(session)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: authorization.refresh()
            case .background: session.persist()
            default: break
            }
        }
    }
}
