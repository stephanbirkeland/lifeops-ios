// LifeOpsApp.swift
// Main entry point for LifeOps iOS app

import SwiftUI

@main
struct LifeOpsApp: App {
    @StateObject private var apiClient = APIClient.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(apiClient)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var apiClient: APIClient

    var body: some View {
        if apiClient.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    var body: some View {
        TabView {
            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "list.bullet.clipboard")
                }

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// MARK: - Placeholder Views

struct StatsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Stats & Progress")
                    .font(.largeTitle)
                Text("Coming soon...")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Stats")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var apiURL = APIConfig.baseURL

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("API URL", text: $apiURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                }

                Section("Account") {
                    Button("Logout", role: .destructive) {
                        apiClient.logout()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                Section {
                    Button {
                        login()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Login")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty || isLoading)
                }
            }
            .navigationTitle("LifeOps")
            .alert("Login Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func login() {
        isLoading = true
        Task {
            do {
                try await apiClient.login(username: username, password: password)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(APIClient.shared)
}
