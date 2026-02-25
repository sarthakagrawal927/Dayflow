# Analytics Dashboard + Frequency Presets Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add configurable analysis frequency presets and a personal usage analytics dashboard to Dayflow, keeping changes in separate files for clean upstream rebasing.

**Architecture:** New files handle all logic (preset config, data queries, view + viewmodel). Existing files get minimal wiring edits (~5 lines each). Analytics queries run against the existing `timeline_cards` SQLite table via GRDB.

**Tech Stack:** Swift, SwiftUI, GRDB, SwiftUI Charts (macOS 13+), UserDefaults

---

## Task 1: Analysis Frequency Preset — New File

**Files:**
- Create: `Dayflow/Dayflow/Dayflow/Core/Analysis/AnalysisFrequencyPreset.swift`

**Step 1: Create the preset enum and config factory**

```swift
//
//  AnalysisFrequencyPreset.swift
//  Dayflow
//

import Foundation

enum AnalysisFrequencyPreset: String, CaseIterable, Codable {
    case relaxed
    case frequent
    case realtime

    var displayName: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .frequent: return "Frequent"
        case .realtime: return "Real-time"
        }
    }

    var description: String {
        switch self {
        case .relaxed: return "15-min batches, checks every minute"
        case .frequent: return "5-min batches, checks every 30s"
        case .realtime: return "2-min batches, checks every 15s"
        }
    }

    var checkInterval: TimeInterval {
        switch self {
        case .relaxed: return 60
        case .frequent: return 30
        case .realtime: return 15
        }
    }

    var batchingConfig: BatchingConfig {
        switch self {
        case .relaxed:
            return BatchingConfig(
                targetDuration: 15 * 60,
                maxGap: 2 * 60,
                cardLookbackDuration: 45 * 60
            )
        case .frequent:
            return BatchingConfig(
                targetDuration: 5 * 60,
                maxGap: 1 * 60,
                cardLookbackDuration: 15 * 60
            )
        case .realtime:
            return BatchingConfig(
                targetDuration: 2 * 60,
                maxGap: 30,
                cardLookbackDuration: 6 * 60
            )
        }
    }

    // MARK: - Persistence

    private static let defaultsKey = "analysisFrequencyPreset"

    static func load(from defaults: UserDefaults = .standard) -> AnalysisFrequencyPreset {
        guard let raw = defaults.string(forKey: defaultsKey),
              let preset = AnalysisFrequencyPreset(rawValue: raw) else {
            return .relaxed
        }
        return preset
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild build -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Dayflow/Dayflow/Dayflow/Core/Analysis/AnalysisFrequencyPreset.swift
git commit -m "feat: add AnalysisFrequencyPreset enum with persistence"
```

---

## Task 2: Wire Preset into AnalysisManager + LLMTypes

**Files:**
- Modify: `Dayflow/Dayflow/Dayflow/Core/Analysis/AnalysisManager.swift:38`
- Modify: `Dayflow/Dayflow/Dayflow/Core/AI/LLMTypes.swift:184-188`

**Step 1: Update AnalysisManager.swift**

Replace line 38:
```swift
private let checkInterval: TimeInterval = 60          // every minute
```
With:
```swift
private let checkInterval: TimeInterval = AnalysisFrequencyPreset.load().checkInterval
```

**Step 2: Update LLMTypes.swift**

Replace lines 184-188:
```swift
    static let standard = BatchingConfig(
        targetDuration: 15 * 60,      // 15-minute analysis batches
        maxGap: 2 * 60,               // Split batches if gap exceeds 2 minutes
        cardLookbackDuration: 45 * 60 // Build cards with a 45-minute lookback window
    )
```
With:
```swift
    static var standard: BatchingConfig {
        AnalysisFrequencyPreset.load().batchingConfig
    }
```

**Step 3: Verify it compiles**

Run: `xcodebuild build -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Dayflow/Dayflow/Dayflow/Core/Analysis/AnalysisManager.swift Dayflow/Dayflow/Dayflow/Core/AI/LLMTypes.swift
git commit -m "feat: wire frequency preset into AnalysisManager and BatchingConfig"
```

---

## Task 3: Add Preset Picker to Settings UI

**Files:**
- Modify: `Dayflow/Dayflow/Dayflow/Views/UI/Settings/OtherSettingsViewModel.swift:7-13`
- Modify: `Dayflow/Dayflow/Dayflow/Views/UI/Settings/SettingsOtherTabView.swift:16-17`

**Step 1: Add preset property to OtherSettingsViewModel**

After line 27 (`@Published var outputLanguageOverride: String`), add:
```swift
    @Published var frequencyPreset: AnalysisFrequencyPreset {
        didSet {
            guard frequencyPreset != oldValue else { return }
            frequencyPreset.save()
        }
    }
```

In `init()` (line 36-43), add after the `outputLanguageOverride` line:
```swift
        frequencyPreset = AnalysisFrequencyPreset.load()
```

**Step 2: Add preset picker to SettingsOtherTabView**

In `body` (line 16), add a new card before the "App preferences" card. Insert before line 19 (`SettingsCard(title: "App preferences"...`):

```swift
            SettingsCard(title: "Analysis frequency", subtitle: "How often Dayflow analyzes your screen") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(AnalysisFrequencyPreset.allCases, id: \.self) { preset in
                        HStack(spacing: 12) {
                            Image(systemName: viewModel.frequencyPreset == preset ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundColor(viewModel.frequencyPreset == preset ? Color(hex: "F96E00") : .black.opacity(0.3))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.displayName)
                                    .font(.custom("Nunito", size: 13))
                                    .foregroundColor(.black.opacity(0.7))
                                Text(preset.description)
                                    .font(.custom("Nunito", size: 11.5))
                                    .foregroundColor(.black.opacity(0.5))
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .pointingHandCursor()
                        .onTapGesture { viewModel.frequencyPreset = preset }
                    }

                    Text("Restart Dayflow after changing for the new interval to take effect.")
                        .font(.custom("Nunito", size: 11.5))
                        .foregroundColor(.black.opacity(0.5))
                }
            }
```

**Step 3: Verify it compiles**

Run: `xcodebuild build -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Dayflow/Dayflow/Dayflow/Views/UI/Settings/OtherSettingsViewModel.swift Dayflow/Dayflow/Dayflow/Views/UI/Settings/SettingsOtherTabView.swift
git commit -m "feat: add analysis frequency preset picker to settings"
```

---

## Task 4: Analytics Data Service — New File

**Files:**
- Create: `Dayflow/Dayflow/Dayflow/Core/Analysis/AnalyticsDataService.swift`

**Step 1: Create the data service**

This file queries the existing `timeline_cards` table via `StorageManager.shared` and provides aggregated analytics data. All SQL queries use the same 4AM day boundary pattern as existing code.

```swift
//
//  AnalyticsDataService.swift
//  Dayflow
//

import Foundation
import GRDB

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

final class AnalyticsDataService {
    static let shared = AnalyticsDataService()
    private let store = StorageManager.shared

    private let productiveCategories: Set<String> = ["Work", "Personal"]
    private let distractionCategory = "Distraction"
    private let systemCategories: Set<String> = ["System", "Idle"]
    private let productiveThresholdSeconds: Double = 4 * 60 * 60 // 4 hours

    // MARK: - Summary

    func fetchSummary(from startDate: Date, to endDate: Date) -> AnalyticsSummary {
        let cards = store.fetchTimelineCardsByTimeRange(from: startDate, to: endDate)
        return computeSummary(cards: cards, previousCards: nil)
    }

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

        let calendar = Calendar.current
        for card in cards where card.category == distractionCategory {
            guard let startTs = cardStartTs(card) else { continue }
            let hour = calendar.component(.hour, from: Date(timeIntervalSince1970: startTs))
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
            } else {
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
        guard let start = cardStartTs(card), let end = cardEndTs(card) else { return 0 }
        return max(0, end - start)
    }

    private func cardStartTs(_ card: TimelineCard) -> TimeInterval? {
        // TimelineCard stores startTimestamp as String like "2025-01-15T10:30:00"
        // but the DB has start_ts as unix int. We parse from the string timestamps.
        return parseTimestamp(card.startTimestamp)
    }

    private func cardEndTs(_ card: TimelineCard) -> TimeInterval? {
        return parseTimestamp(card.endTimestamp)
    }

    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let fallbackFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func parseTimestamp(_ ts: String) -> TimeInterval? {
        if let date = iso8601Formatter.date(from: ts) {
            return date.timeIntervalSince1970
        }
        if let date = fallbackFormatter.date(from: ts) {
            return date.timeIntervalSince1970
        }
        return nil
    }
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild build -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Dayflow/Dayflow/Dayflow/Core/Analysis/AnalyticsDataService.swift
git commit -m "feat: add AnalyticsDataService with summary, trends, streaks queries"
```

---

## Task 5: Analytics Dashboard ViewModel — New File

**Files:**
- Create: `Dayflow/Dayflow/Dayflow/Views/UI/AnalyticsDashboardViewModel.swift`

**Step 1: Create the view model**

```swift
//
//  AnalyticsDashboardViewModel.swift
//  Dayflow
//

import Foundation
import Combine

enum AnalyticsTimeRange: String, CaseIterable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case custom = "Custom"
}

@MainActor
final class AnalyticsDashboardViewModel: ObservableObject {
    @Published var selectedRange: AnalyticsTimeRange = .today
    @Published var customStartDate: Date = timelineDisplayDate(from: Date())
    @Published var customEndDate: Date = timelineDisplayDate(from: Date())

    @Published var summary: AnalyticsSummary?
    @Published var categoryBreakdown: [CategoryBreakdown] = []
    @Published var focusTrend: [DailyFocusPoint] = []
    @Published var hourlyDistractions: [HourlyDistraction] = []
    @Published var topDistractionSources: [DistractionSource] = []
    @Published var streakInfo: StreakInfo?
    @Published var isLoading = false

    private let dataService = AnalyticsDataService.shared

    func refresh() {
        let (start, end) = dateRange(for: selectedRange)
        isLoading = true

        Task.detached(priority: .userInitiated) { [dataService, start, end] in
            let summary = dataService.fetchSummaryWithDelta(from: start, to: end)
            let categories = dataService.fetchCategoryBreakdown(from: start, to: end)
            let trend = dataService.fetchDailyFocusTrend(from: start, to: end)
            let hourly = dataService.fetchHourlyDistractions(from: start, to: end)
            let sources = dataService.fetchTopDistractionSources(from: start, to: end)
            let streaks = dataService.fetchStreakInfo(asOf: end)

            await MainActor.run { [self] in
                self.summary = summary
                self.categoryBreakdown = categories
                self.focusTrend = trend
                self.hourlyDistractions = hourly
                self.topDistractionSources = sources
                self.streakInfo = streaks
                self.isLoading = false
            }
        }
    }

    private func dateRange(for range: AnalyticsTimeRange) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()

        switch range {
        case .today:
            let dayStart = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: now) ?? now
            let start = now < dayStart
                ? calendar.date(byAdding: .day, value: -1, to: dayStart)!
                : dayStart
            return (start, now)

        case .thisWeek:
            var weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            weekStart = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: weekStart) ?? weekStart
            if now < weekStart {
                weekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
            }
            return (weekStart, now)

        case .thisMonth:
            var monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            monthStart = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: monthStart) ?? monthStart
            return (monthStart, now)

        case .custom:
            let start = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: customStartDate) ?? customStartDate
            let endNextDay = calendar.date(byAdding: .day, value: 1, to: customEndDate) ?? customEndDate
            let end = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: endNextDay) ?? endNextDay
            return (start, end)
        }
    }
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild build -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Dayflow/Dayflow/Dayflow/Views/UI/AnalyticsDashboardViewModel.swift
git commit -m "feat: add AnalyticsDashboardViewModel with date range logic"
```

---

## Task 6: Analytics Dashboard View — New File

**Files:**
- Create: `Dayflow/Dayflow/Dayflow/Views/UI/AnalyticsDashboardView.swift`

**Step 1: Create the view**

This is a SwiftUI view using Charts framework. It follows the existing app style (Nunito font, warm color palette, SettingsCard-like containers).

```swift
//
//  AnalyticsDashboardView.swift
//  Dayflow
//

import SwiftUI
import Charts

struct AnalyticsDashboardView: View {
    @StateObject private var viewModel = AnalyticsDashboardViewModel()

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                dateControls
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    summaryBar
                    categoryBreakdownSection
                    focusTrendSection
                    distractionPatternsSection
                    streaksSection
                }
            }
            .padding(15)
        }
        .onAppear { viewModel.refresh() }
        .onChange(of: viewModel.selectedRange) { _, _ in viewModel.refresh() }
        .onChange(of: viewModel.customStartDate) { _, _ in
            if viewModel.selectedRange == .custom { viewModel.refresh() }
        }
        .onChange(of: viewModel.customEndDate) { _, _ in
            if viewModel.selectedRange == .custom { viewModel.refresh() }
        }
    }

    // MARK: - Date Controls

    private var dateControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics")
                .font(.custom("InstrumentSerif-Regular", size: 32))
                .foregroundColor(.black.opacity(0.85))

            HStack(spacing: 8) {
                ForEach(AnalyticsTimeRange.allCases, id: \.self) { range in
                    Button {
                        viewModel.selectedRange = range
                    } label: {
                        Text(range.rawValue)
                            .font(.custom("Nunito", size: 13).weight(.semibold))
                            .foregroundColor(viewModel.selectedRange == range ? .white : .black.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(viewModel.selectedRange == range ? Color(hex: "F96E00") : Color.white.opacity(0.7))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "FFE0A5"), lineWidth: viewModel.selectedRange == range ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .pointingHandCursor()
                }
            }

            if viewModel.selectedRange == .custom {
                HStack(spacing: 12) {
                    DatePicker("From", selection: $viewModel.customStartDate, displayedComponents: .date)
                        .font(.custom("Nunito", size: 13))
                    DatePicker("To", selection: $viewModel.customEndDate, displayedComponents: .date)
                        .font(.custom("Nunito", size: 13))
                }
                .frame(maxWidth: 400)
            }
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: 16) {
            summaryCard(title: "Tracked", value: formatDuration(viewModel.summary?.totalTrackedSeconds ?? 0), color: .black.opacity(0.7))
            summaryCard(title: "Productive", value: formatDuration(viewModel.summary?.productiveSeconds ?? 0), color: Color(hex: "22C55E"))
            summaryCard(title: "Distracted", value: formatDuration(viewModel.summary?.distractedSeconds ?? 0), color: Color(hex: "FF5950"))
            focusScoreCard
        }
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.5))
            Text(value)
                .font(.custom("Nunito", size: 22).weight(.bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "FFE0A5"), lineWidth: 1))
        )
    }

    private var focusScoreCard: some View {
        let score = viewModel.summary?.focusScore ?? 0
        let prev = viewModel.summary?.previousPeriodFocusScore
        let delta = prev.map { score - $0 }

        return VStack(alignment: .leading, spacing: 6) {
            Text("Focus Score")
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.5))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(score * 100))%")
                    .font(.custom("Nunito", size: 22).weight(.bold))
                    .foregroundColor(Color(hex: "F96E00"))
                if let delta {
                    let sign = delta >= 0 ? "+" : ""
                    Text("\(sign)\(Int(delta * 100))%")
                        .font(.custom("Nunito", size: 12).weight(.semibold))
                        .foregroundColor(delta >= 0 ? Color(hex: "22C55E") : Color(hex: "FF5950"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "FFE0A5"), lineWidth: 1))
        )
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.custom("Nunito", size: 16).weight(.semibold))
                .foregroundColor(.black.opacity(0.7))

            if !viewModel.categoryBreakdown.isEmpty {
                Chart(viewModel.categoryBreakdown) { item in
                    SectorMark(
                        angle: .value("Time", item.totalSeconds),
                        innerRadius: .ratio(0.6)
                    )
                    .foregroundStyle(by: .value("Category", item.category))
                }
                .frame(height: 200)

                ForEach(viewModel.categoryBreakdown) { item in
                    HStack {
                        Text(item.category)
                            .font(.custom("Nunito", size: 13))
                            .foregroundColor(.black.opacity(0.7))
                        Spacer()
                        Text(formatDuration(item.totalSeconds))
                            .font(.custom("Nunito", size: 13).weight(.semibold))
                            .foregroundColor(.black.opacity(0.6))
                        Text("(\(Int(item.percentage * 100))%)")
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(.black.opacity(0.4))
                    }
                }
            } else {
                Text("No data for this period.")
                    .font(.custom("Nunito", size: 13))
                    .foregroundColor(.black.opacity(0.4))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "FFE0A5"), lineWidth: 1))
        )
    }

    // MARK: - Focus Trend

    private var focusTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Trend")
                .font(.custom("Nunito", size: 16).weight(.semibold))
                .foregroundColor(.black.opacity(0.7))

            if viewModel.focusTrend.count > 1 {
                Chart(viewModel.focusTrend) { point in
                    BarMark(
                        x: .value("Day", point.day),
                        y: .value("Focus", point.focusScore * 100)
                    )
                    .foregroundStyle(Color(hex: "F96E00").opacity(0.75))
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)%")
                                .font(.custom("Nunito", size: 10))
                        }
                    }
                }
                .frame(height: 200)
            } else {
                Text("Need multiple days of data for trend.")
                    .font(.custom("Nunito", size: 13))
                    .foregroundColor(.black.opacity(0.4))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "FFE0A5"), lineWidth: 1))
        )
    }

    // MARK: - Distraction Patterns

    private var distractionPatternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distraction Patterns")
                .font(.custom("Nunito", size: 16).weight(.semibold))
                .foregroundColor(.black.opacity(0.7))

            Text("By hour of day")
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.4))

            Chart(viewModel.hourlyDistractions) { item in
                BarMark(
                    x: .value("Hour", "\(item.hour):00"),
                    y: .value("Minutes", item.distractionSeconds / 60)
                )
                .foregroundStyle(Color(hex: "FF5950").opacity(0.7))
                .cornerRadius(3)
            }
            .frame(height: 150)

            if !viewModel.topDistractionSources.isEmpty {
                Text("Top sources")
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.4))
                    .padding(.top, 8)

                ForEach(viewModel.topDistractionSources) { source in
                    HStack {
                        Text(source.name)
                            .font(.custom("Nunito", size: 13))
                            .foregroundColor(.black.opacity(0.7))
                            .lineLimit(1)
                        Spacer()
                        Text(formatDuration(source.totalSeconds))
                            .font(.custom("Nunito", size: 13).weight(.semibold))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "FFE0A5"), lineWidth: 1))
        )
    }

    // MARK: - Streaks

    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streaks & Consistency")
                .font(.custom("Nunito", size: 16).weight(.semibold))
                .foregroundColor(.black.opacity(0.7))

            if let info = viewModel.streakInfo {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(info.currentStreak)")
                            .font(.custom("Nunito", size: 28).weight(.bold))
                            .foregroundColor(Color(hex: "F96E00"))
                        Text("Current streak")
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(.black.opacity(0.5))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(info.bestStreak)")
                            .font(.custom("Nunito", size: 28).weight(.bold))
                            .foregroundColor(.black.opacity(0.7))
                        Text("Best streak")
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(.black.opacity(0.5))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(info.weeklyConsistencyScore * 100))%")
                            .font(.custom("Nunito", size: 28).weight(.bold))
                            .foregroundColor(.black.opacity(0.7))
                        Text("Weekly consistency")
                            .font(.custom("Nunito", size: 12))
                            .foregroundColor(.black.opacity(0.5))
                    }

                    Spacer()
                }

                Text("Streak = consecutive days with 4+ hrs productive work")
                    .font(.custom("Nunito", size: 11.5))
                    .foregroundColor(.black.opacity(0.4))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "FFE0A5"), lineWidth: 1))
        )
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
```

**Step 2: Verify it compiles**

Run: `xcodebuild build -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Dayflow/Dayflow/Dayflow/Views/UI/AnalyticsDashboardView.swift
git commit -m "feat: add AnalyticsDashboardView with charts and all sections"
```

---

## Task 7: Wire Analytics Tab into Sidebar + Layout

**Files:**
- Modify: `Dayflow/Dayflow/Dayflow/Views/UI/MainView/SidebarView.swift:3-8`
- Modify: `Dayflow/Dayflow/Dayflow/Views/UI/MainView/Layout.swift:274-291`

**Step 1: Add analytics case to SidebarIcon enum**

In `SidebarView.swift`, add `case analytics` to the enum after `case journal` (line 6). Then add corresponding entries to each switch:

At line 3-8, change:
```swift
enum SidebarIcon: CaseIterable {
    case timeline
    case dashboard
    case journal
    case bug
    case settings
```
To:
```swift
enum SidebarIcon: CaseIterable {
    case timeline
    case dashboard
    case journal
    case analytics
    case bug
    case settings
```

In `assetName` (line 10-17), add after the journal case:
```swift
        case .analytics: return nil
```

In `systemNameFallback` (line 20-25), add:
```swift
        case .analytics: return "chart.bar.xaxis"
```

In `displayName` (line 28-36), add:
```swift
        case .analytics: return "Analytics"
```

**Step 2: Add routing in Layout.swift**

At line 287 (before `case .timeline:`), add:
```swift
            case .analytics:
                AnalyticsDashboardView()
                    .padding(15)
```

Also in the analytics tracking switch in Layout.swift (around line 99-103), add:
```swift
                case .analytics: tabName = "analytics"
```

**Step 3: Verify it compiles**

Run: `xcodebuild build -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Dayflow/Dayflow/Dayflow/Views/UI/MainView/SidebarView.swift Dayflow/Dayflow/Dayflow/Views/UI/MainView/Layout.swift
git commit -m "feat: wire analytics tab into sidebar and layout routing"
```

---

## Task 8: Build and Smoke Test

**Step 1: Full build**

```bash
cd /Users/sarthakagrawal/Desktop/Dayflow/Dayflow
xcodebuild build -project Dayflow.xcodeproj -scheme Dayflow -destination 'platform=macOS' 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED

**Step 2: Manual verification**

Open the app in Xcode, run it. Verify:
- [ ] Analytics tab appears in sidebar between Journal and Report
- [ ] Clicking Analytics shows the dashboard view
- [ ] Date range buttons (Today/This Week/This Month/Custom) switch properly
- [ ] Settings > Other shows frequency preset picker
- [ ] Changing preset persists after relaunching settings

**Step 3: Final commit if any fixups needed**

---

Plan complete and saved to `docs/plans/2026-02-25-implementation-plan.md`. Two execution options:

**1. Subagent-Driven (this session)** — I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** — Open new session with executing-plans, batch execution with checkpoints

Which approach?
