//
//  AnalyticsDataService.swift
//  Dayflow
//

import Foundation

// MARK: - Data Models

struct AnalyticsSummary {
    let totalTrackedSeconds: Double
    let productiveSeconds: Double       // Work + Personal categories
    let distractedSeconds: Double       // Distraction category
    let idleSeconds: Double             // Idle/System categories
    let focusScore: Double              // productive / (productive + distracted), 0-1
    let previousPeriodFocusScore: Double? // for delta comparison
}

struct CategoryBreakdown: Identifiable {
    let id = UUID()
    let category: String
    let totalSeconds: Double
    let percentage: Double
}

struct DailyFocusPoint: Identifiable {
    let id = UUID()
    let day: String                     // yyyy-MM-dd
    let focusScore: Double
    let totalTrackedSeconds: Double
}

struct HourlyDistraction: Identifiable {
    let id = UUID()
    let hour: Int                       // 0-23
    let distractionSeconds: Double
}

struct DistractionSource: Identifiable {
    let id = UUID()
    let name: String
    let totalSeconds: Double
}

struct StreakInfo {
    let currentStreak: Int              // consecutive days with 4+ hrs productive
    let bestStreak: Int
    let weeklyConsistencyScore: Double  // days this week meeting threshold / 7
}

// MARK: - AnalyticsDataService

final class AnalyticsDataService {
    static let shared = AnalyticsDataService()
    private let store = StorageManager.shared

    private let productiveCategories: Set<String> = ["Work", "Personal"]
    private let distractionCategory = "Distraction"
    private let productiveThresholdSeconds: Double = 4 * 60 * 60 // 4 hours

    // MARK: - Summary

    func fetchSummaryWithDelta(from startDate: Date, to endDate: Date) -> AnalyticsSummary {
        let duration = endDate.timeIntervalSince(startDate)
        let prevStart = startDate.addingTimeInterval(-duration)
        let prevEnd = startDate

        let cards = store.fetchTimelineCardsByTimeRange(from: startDate, to: endDate)
        let prevCards = store.fetchTimelineCardsByTimeRange(from: prevStart, to: prevEnd)
        return computeSummary(cards: cards, previousCards: prevCards)
    }

    private func computeSummary(cards: [TimelineCard], previousCards: [TimelineCard]?) -> AnalyticsSummary {
        var productive: Double = 0
        var distracted: Double = 0
        var idle: Double = 0
        var total: Double = 0

        for card in cards {
            let duration = cardDuration(card)
            total += duration
            if productiveCategories.contains(card.category) {
                productive += duration
            } else if card.category == distractionCategory {
                distracted += duration
            } else {
                idle += duration
            }
        }

        let focus = (productive + distracted) > 0 ? productive / (productive + distracted) : 0

        var prevFocus: Double? = nil
        if let prevCards = previousCards {
            var prevProd: Double = 0
            var prevDist: Double = 0
            for card in prevCards {
                let d = cardDuration(card)
                if productiveCategories.contains(card.category) { prevProd += d }
                else if card.category == distractionCategory { prevDist += d }
            }
            prevFocus = (prevProd + prevDist) > 0 ? prevProd / (prevProd + prevDist) : 0
        }

        return AnalyticsSummary(
            totalTrackedSeconds: total,
            productiveSeconds: productive,
            distractedSeconds: distracted,
            idleSeconds: idle,
            focusScore: focus,
            previousPeriodFocusScore: prevFocus
        )
    }

    // MARK: - Category Breakdown

    func fetchCategoryBreakdown(from startDate: Date, to endDate: Date) -> [CategoryBreakdown] {
        let cards = store.fetchTimelineCardsByTimeRange(from: startDate, to: endDate)
        var buckets: [String: Double] = [:]
        var total: Double = 0

        for card in cards {
            let d = cardDuration(card)
            buckets[card.category, default: 0] += d
            total += d
        }

        return buckets.map { category, seconds in
            CategoryBreakdown(
                category: category,
                totalSeconds: seconds,
                percentage: total > 0 ? seconds / total : 0
            )
        }
        .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    // MARK: - Focus Trend

    func fetchDailyFocusTrend(from startDate: Date, to endDate: Date) -> [DailyFocusPoint] {
        let calendar = Calendar.current
        var points: [DailyFocusPoint] = []
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"

        var cursor = startDate
        while cursor < endDate {
            let dayString = dayFormatter.string(from: cursor)
            let cards = store.fetchTimelineCards(forDay: dayString)

            var productive: Double = 0
            var distracted: Double = 0
            var total: Double = 0

            for card in cards {
                let d = cardDuration(card)
                total += d
                if productiveCategories.contains(card.category) { productive += d }
                else if card.category == distractionCategory { distracted += d }
            }

            let focus = (productive + distracted) > 0 ? productive / (productive + distracted) : 0
            points.append(DailyFocusPoint(day: dayString, focusScore: focus, totalTrackedSeconds: total))

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return points
    }

    // MARK: - Distraction Patterns

    func fetchHourlyDistractions(from startDate: Date, to endDate: Date) -> [HourlyDistraction] {
        let cards = store.fetchTimelineCardsByTimeRange(from: startDate, to: endDate)
        var hourBuckets = [Int: Double](uniqueKeysWithValues: (0..<24).map { ($0, 0.0) })

        for card in cards where card.category == distractionCategory {
            guard let startMinutes = parseTimeHMMA(timeString: card.startTimestamp) else { continue }
            let hour = startMinutes / 60
            hourBuckets[hour, default: 0] += cardDuration(card)
        }

        return (0..<24).map { hour in
            HourlyDistraction(hour: hour, distractionSeconds: hourBuckets[hour] ?? 0)
        }
    }

    func fetchTopDistractionSources(from startDate: Date, to endDate: Date, limit: Int = 10) -> [DistractionSource] {
        let cards = store.fetchTimelineCardsByTimeRange(from: startDate, to: endDate)
        var sources: [String: Double] = [:]

        for card in cards where card.category == distractionCategory {
            if let primary = card.appSites?.primary, !primary.isEmpty {
                sources[primary, default: 0] += cardDuration(card)
            } else if !card.subcategory.isEmpty {
                sources[card.subcategory, default: 0] += cardDuration(card)
            }
        }

        return sources
            .map { DistractionSource(name: $0.key, totalSeconds: $0.value) }
            .sorted { $0.totalSeconds > $1.totalSeconds }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Streaks

    func fetchStreakInfo(asOf date: Date) -> StreakInfo {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"

        // Look back up to 365 days
        var currentStreak = 0
        var bestStreak = 0
        var runningStreak = 0
        var streakBroken = false

        var weekDaysMeetingThreshold = 0
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!

        for dayOffset in 0..<365 {
            guard let checkDate = calendar.date(byAdding: .day, value: -dayOffset, to: date) else { break }
            let dayString = dayFormatter.string(from: checkDate)
            let cards = store.fetchTimelineCards(forDay: dayString)

            var productiveSecs: Double = 0
            for card in cards where productiveCategories.contains(card.category) {
                productiveSecs += cardDuration(card)
            }

            let meetsThreshold = productiveSecs >= productiveThresholdSeconds

            if meetsThreshold {
                runningStreak += 1
                bestStreak = max(bestStreak, runningStreak)
                if !streakBroken { currentStreak = runningStreak }
            } else {
                if !streakBroken { streakBroken = true }
                runningStreak = 0
            }

            // Count days this week meeting threshold
            if checkDate >= weekStart && meetsThreshold {
                weekDaysMeetingThreshold += 1
            }
        }

        let daysInWeekSoFar = max(1, calendar.dateComponents([.day], from: weekStart, to: date).day ?? 1)
        let consistency = Double(weekDaysMeetingThreshold) / Double(min(7, daysInWeekSoFar))

        return StreakInfo(
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            weeklyConsistencyScore: consistency
        )
    }

    // MARK: - Helpers

    private func cardDuration(_ card: TimelineCard) -> Double {
        guard let startMinutes = parseTimeHMMA(timeString: card.startTimestamp),
              let endMinutes = parseTimeHMMA(timeString: card.endTimestamp) else {
            // Fallback: try ISO8601
            if let start = parseISO8601(card.startTimestamp),
               let end = parseISO8601(card.endTimestamp) {
                return max(0, end - start)
            }
            return 0
        }
        var diff = endMinutes - startMinutes
        if diff < 0 { diff += 24 * 60 } // handle midnight crossing
        return Double(diff) * 60 // convert minutes to seconds
    }

    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseISO8601(_ ts: String) -> TimeInterval? {
        if let date = iso8601Formatter.date(from: ts) {
            return date.timeIntervalSince1970
        }
        if let date = iso8601FallbackFormatter.date(from: ts) {
            return date.timeIntervalSince1970
        }
        return nil
    }
}
