//
//  MusicPlayerApp.swift
//  MusicPlayer
//
//  Created by Louis Melchiorre on 3/17/26.
//
import SwiftUI

// MARK: - Navy Bordered Button Style
struct NavyBorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color.navyBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.navyBlue, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Directory Button Style (active = filled, inactive = bordered)
struct DirectoryButtonStyle: ButtonStyle {
    let isActive: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isActive ? .white : Color.navyBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.navyBlue : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.navyBlue, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

extension Color {
    /// Accent — MET dark teal #114B5F (matches MileageTracker893)
    static let navyBlue = Color(red: 17/255, green: 75/255, blue: 95/255)

    /// Background — MET ice blue #EEF8FA (matches MileageTracker893)
    static let appBackground = Color(red: 238/255, green: 248/255, blue: 250/255)
}

@main
struct MusicPlayerApp: App {
    init() {
        let navy = UIColor(Color.navyBlue)
        let bg   = UIColor(Color.appBackground)

        // List / TableView backgrounds
        UITableView.appearance().backgroundColor     = bg
        UITableViewCell.appearance().backgroundColor = bg
        UITableView.appearance().separatorColor      = UIColor(Color.navyBlue.opacity(0.2))

        // All text navy
        UILabel.appearance().textColor = navy
        UINavigationBar.appearance().titleTextAttributes      = [.foregroundColor: navy]
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: navy]
        UITextField.appearance().textColor = navy

        // Nav bar background
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor                    = bg
        navBarAppearance.titleTextAttributes                = [.foregroundColor: navy]
        navBarAppearance.largeTitleTextAttributes           = [.foregroundColor: navy]
        navBarAppearance.shadowColor                        = .clear
        UINavigationBar.appearance().standardAppearance    = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance  = navBarAppearance
        UINavigationBar.appearance().compactAppearance     = navBarAppearance
        UINavigationBar.appearance().tintColor             = navy
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
