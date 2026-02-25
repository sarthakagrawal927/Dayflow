//
//  AnalyticsDashboardViewModel.swift
//  Dayflow
//

import Foundation
import Combine

// MARK: - Date Range

enum AnalyticsDateRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case custom = "Custom"

    var id: String { rawValue }
}

// MARK: - ViewModel

@MainActor
final class AnalyticsDashboardViewModel: ObservableObject {

    // MARK: Published State

    @Published var selectedRange: AnalyticsDateRange = .today
    @Published var customStartDate: Date = Date()
    @Published var customEndDate: Date = Date()

    @Published var summary: AnalyticsSummary?
    @Published var timeBreakdown: TimeBreakdown?
    @Published var categoryBreakdown: [CategoryBreakdown] = []
    @Published var focusTrend: [DailyFocusPoint] = []
    @Published var hourlyDistractions: [HourlyDistraction] = []
    @Published var topDistractionSources: [DistractionSource] = []
    @Published var streakInfo: StreakInfo?
    @Published var isLoading: Bool = false

    // MARK: Private

    private let service = AnalyticsDataService.shared

    // MARK: - Date Range Computation (4 AM boundary)

    /// Returns (start, end) for the selected range, respecting the 4 AM day boundary.
    private func computeDateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        // The display date accounts for the 4 AM boundary
        let displayDate = timelineDisplayDate(from: now, now: now)

        switch selectedRange {
        case .today:
            // Day starts at 4 AM of displayDate, ends at 4 AM next day
            let dayStart = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: displayDate)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            return (dayStart, min(dayEnd, now))

        case .thisWeek:
            // Find start of the week (Sunday or Monday depending on locale) containing displayDate
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: displayDate))!
            let weekStartAt4AM = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: weekStart)!
            return (weekStartAt4AM, now)

        case .thisMonth:
            let monthComponents = calendar.dateComponents([.year, .month], from: displayDate)
            let monthStart = calendar.date(from: monthComponents)!
            let monthStartAt4AM = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: monthStart)!
            return (monthStartAt4AM, now)

        case .custom:
            let start = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: customStartDate)!
            let endPlusOne = calendar.date(byAdding: .day, value: 1, to: customEndDate)!
            let end = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: endPlusOne)!
            return (start, min(end, now))
        }
    }

    // MARK: - Refresh

    func refresh() {
        isLoading = true
        let (start, end) = computeDateRange()
        let svc = service

        Task.detached { [weak self] in
            let summary = svc.fetchSummaryWithDelta(from: start, to: end)
            let timeBreakdown = svc.fetchTimeBreakdown(from: start, to: end)
            let breakdown = svc.fetchCategoryBreakdown(from: start, to: end)
            let trend = svc.fetchDailyFocusTrend(from: start, to: end)
            let hourly = svc.fetchHourlyDistractions(from: start, to: end)
            let sources = svc.fetchTopDistractionSources(from: start, to: end)
            let streak = svc.fetchStreakInfo(asOf: end)

            await MainActor.run {
                guard let self else { return }
                self.summary = summary
                self.timeBreakdown = timeBreakdown
                self.categoryBreakdown = breakdown
                self.focusTrend = trend
                self.hourlyDistractions = hourly
                self.topDistractionSources = sources
                self.streakInfo = streak
                self.isLoading = false
            }
        }
    }
}
