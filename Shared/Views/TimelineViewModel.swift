// TimelineViewModel.swift
// ViewModel for Timeline view

import SwiftUI

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var feed: TimelineFeed?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var selectedItem: TimelineFeedItem?

    private let api = APIClient.shared

    // MARK: - Computed Properties

    var overdueItems: [TimelineFeedItem] {
        feed?.overdue ?? []
    }

    var activeItems: [TimelineFeedItem] {
        feed?.items.filter { $0.status == .active } ?? []
    }

    var upcomingItems: [TimelineFeedItem] {
        feed?.upcoming ?? []
    }

    var completedItems: [TimelineFeedItem] {
        feed?.completed ?? []
    }

    var isEmpty: Bool {
        overdueItems.isEmpty && activeItems.isEmpty && upcomingItems.isEmpty && completedItems.isEmpty
    }

    // MARK: - Actions

    func loadTimeline(expand: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            if expand {
                feed = try await api.getFullDayTimeline()
            } else {
                feed = try await api.getTimeline(hours: 4)
            }
        } catch {
            showError(error)
        }
    }

    func refresh() async {
        await loadTimeline()
    }

    func completeItem(_ item: TimelineFeedItem, notes: String? = nil, quality: Int? = nil) async {
        do {
            let response = try await api.completeItem(code: item.code, notes: notes, quality: quality)

            // Show success feedback
            if response.success {
                await refresh()
            }
        } catch {
            showError(error)
        }
    }

    func postponeItem(_ item: TimelineFeedItem, target: PostponeTarget, reason: String? = nil) async {
        do {
            let response = try await api.postponeItem(code: item.code, target: target, reason: reason)

            if response.success {
                await refresh()
            }
        } catch {
            showError(error)
        }
    }

    func skipItem(_ item: TimelineFeedItem, reason: String? = nil) async {
        do {
            try await api.skipItem(code: item.code, reason: reason)
            await refresh()
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
