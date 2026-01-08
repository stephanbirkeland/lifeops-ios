// LifeOpsApp.swift
// Main entry point for Ma iOS app - Ma Design System
//
// Ma (間) - The space to breathe

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
        // Skip auth for now - backend auth not fully implemented yet
        MaMainTabView()
            .tint(MaColors.primaryLight)
    }
}

// MARK: - Ma Main Tab View

struct MaMainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MaFlowingTimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "leaf")
                }
                .tag(0)

            MaStatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(1)

            MaSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .tint(MaColors.primaryLight)
    }
}

// MARK: - Ma Stats View

struct MaStatsView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                MaGradients.sky
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: MaSpacing.xl) {
                        // Placeholder stats cards
                        MaStatsPlaceholder()
                    }
                    .padding(MaSpacing.md)
                }
            }
            .navigationTitle("Stats")
        }
    }
}

struct MaStatsPlaceholder: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: MaSpacing.lg) {
            // Coming soon card
            VStack(spacing: MaSpacing.md) {
                ZStack {
                    Circle()
                        .fill(MaColors.xpSoft)
                        .frame(width: 80, height: 80)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 36))
                        .foregroundStyle(MaColors.xp)
                }

                Text("Stats & Progress")
                    .font(MaTypography.titleLarge)
                    .foregroundStyle(MaColors.textPrimary)

                Text("Track your habits, streaks, and personal growth over time.")
                    .font(MaTypography.bodyMedium)
                    .foregroundStyle(MaColors.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Coming soon...")
                    .font(MaTypography.caption)
                    .foregroundStyle(MaColors.textTertiary)
                    .padding(.top, MaSpacing.xs)
            }
            .padding(MaSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: MaRadius.lg)
                    .fill(MaColors.backgroundSecondary)
                    .shadow(
                        color: colorScheme == .dark ? .clear : .black.opacity(0.04),
                        radius: 8,
                        y: 2
                    )
            )

            // Preview stat cards
            HStack(spacing: MaSpacing.md) {
                MaPreviewStatCard(
                    icon: "flame.fill",
                    value: "--",
                    label: "Current Streak",
                    color: MaColors.streak,
                    softColor: MaColors.secondarySoft
                )

                MaPreviewStatCard(
                    icon: "sparkles",
                    value: "--",
                    label: "Total XP",
                    color: MaColors.xp,
                    softColor: MaColors.xpSoft
                )
            }
        }
    }
}

struct MaPreviewStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let softColor: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: MaSpacing.sm) {
            ZStack {
                Circle()
                    .fill(softColor)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            Text(value)
                .font(MaTypography.statMedium)
                .foregroundStyle(MaColors.textPrimary)

            Text(label)
                .font(MaTypography.caption)
                .foregroundStyle(MaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(MaSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: MaRadius.lg)
                .fill(MaColors.backgroundSecondary)
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.04),
                    radius: 8,
                    y: 2
                )
        )
    }
}

// MARK: - Ma Settings View

struct MaSettingsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var apiURL = APIConfig.baseURL
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                MaColors.background
                    .ignoresSafeArea()

                Form {
                    Section {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(MaColors.primarySoft)
                                    .frame(width: 36, height: 36)

                                Image(systemName: "server.rack")
                                    .font(.body)
                                    .foregroundStyle(MaColors.primaryLight)
                            }

                            TextField("API URL", text: $apiURL)
                                .font(MaTypography.bodyMedium)
                                .textContentType(.URL)
                                .autocapitalization(.none)
                        }
                    } header: {
                        Text("Server")
                            .font(MaTypography.labelSmall)
                            .foregroundStyle(MaColors.textSecondary)
                    }
                    .listRowBackground(MaColors.backgroundSecondary)

                    Section {
                        Button(role: .destructive) {
                            apiClient.logout()
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(MaColors.overdueSoft)
                                        .frame(width: 36, height: 36)

                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.body)
                                        .foregroundStyle(MaColors.overdue)
                                }

                                Text("Logout")
                                    .font(MaTypography.bodyMedium)
                                    .foregroundStyle(MaColors.overdue)
                            }
                        }
                    } header: {
                        Text("Account")
                            .font(MaTypography.labelSmall)
                            .foregroundStyle(MaColors.textSecondary)
                    }
                    .listRowBackground(MaColors.backgroundSecondary)

                    Section {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(MaColors.completeSoft)
                                    .frame(width: 36, height: 36)

                                Image(systemName: "leaf")
                                    .font(.body)
                                    .foregroundStyle(MaColors.complete)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ma")
                                    .font(MaTypography.bodyMedium)
                                    .foregroundStyle(MaColors.textPrimary)
                                Text("The space to breathe")
                                    .font(MaTypography.caption)
                                    .foregroundStyle(MaColors.textTertiary)
                            }

                            Spacer()

                            Text("1.0.0")
                                .font(MaTypography.caption)
                                .foregroundStyle(MaColors.textSecondary)
                        }
                    } header: {
                        Text("About")
                            .font(MaTypography.labelSmall)
                            .foregroundStyle(MaColors.textSecondary)
                    }
                    .listRowBackground(MaColors.backgroundSecondary)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Ma Login View

struct MaLoginView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                MaGradients.sunrise
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: MaSpacing.xxl) {
                        // Logo and branding
                        VStack(spacing: MaSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(MaColors.primarySoft)
                                    .frame(width: 100, height: 100)

                                Image(systemName: "leaf")
                                    .font(.system(size: 48))
                                    .foregroundStyle(MaColors.primaryLight)
                            }

                            VStack(spacing: MaSpacing.xxs) {
                                Text("Ma")
                                    .font(MaTypography.displayLarge)
                                    .foregroundStyle(MaColors.textPrimary)

                                Text("The space to breathe")
                                    .font(MaTypography.bodyMedium)
                                    .foregroundStyle(MaColors.textSecondary)
                            }
                        }
                        .padding(.top, MaSpacing.xxxl)

                        // Login form
                        VStack(spacing: MaSpacing.md) {
                            // Username field
                            VStack(alignment: .leading, spacing: MaSpacing.xxs) {
                                Text("Username")
                                    .font(MaTypography.labelSmall)
                                    .foregroundStyle(MaColors.textSecondary)

                                TextField("Enter your username", text: $username)
                                    .font(MaTypography.bodyMedium)
                                    .textContentType(.username)
                                    .autocapitalization(.none)
                                    .padding(MaSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: MaRadius.sm)
                                            .fill(MaColors.backgroundSecondary)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: MaRadius.sm)
                                            .stroke(MaColors.border, lineWidth: 1)
                                    )
                            }

                            // Password field
                            VStack(alignment: .leading, spacing: MaSpacing.xxs) {
                                Text("Password")
                                    .font(MaTypography.labelSmall)
                                    .foregroundStyle(MaColors.textSecondary)

                                SecureField("Enter your password", text: $password)
                                    .font(MaTypography.bodyMedium)
                                    .textContentType(.password)
                                    .padding(MaSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: MaRadius.sm)
                                            .fill(MaColors.backgroundSecondary)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: MaRadius.sm)
                                            .stroke(MaColors.border, lineWidth: 1)
                                    )
                            }

                            // Login button
                            Button {
                                login()
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, MaSpacing.md)
                                } else {
                                    Text("Sign In")
                                        .font(MaTypography.labelLarge)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, MaSpacing.md)
                                }
                            }
                            .buttonStyle(MaPrimaryButtonStyle(color: MaColors.primaryLight))
                            .disabled(username.isEmpty || password.isEmpty || isLoading)
                            .padding(.top, MaSpacing.sm)
                        }
                        .padding(MaSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: MaRadius.lg)
                                .fill(MaColors.backgroundSecondary)
                                .shadow(
                                    color: colorScheme == .dark ? .clear : .black.opacity(0.06),
                                    radius: 12,
                                    y: 4
                                )
                        )
                        .padding(.horizontal, MaSpacing.lg)

                        Spacer()
                    }
                }
            }
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
