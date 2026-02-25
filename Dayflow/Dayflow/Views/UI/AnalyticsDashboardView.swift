//
//  AnalyticsDashboardView.swift
//  Dayflow
//

import SwiftUI
import Charts

struct AnalyticsDashboardView: View {
    @StateObject private var viewModel = AnalyticsDashboardViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header (matches Timeline/Dashboard positioning)
            Text("Analytics")
                .font(.custom("InstrumentSerif-Regular", size: 42))
                .foregroundColor(Color(hex: "1F1C17"))
                .padding(.leading, 10)

            if viewModel.isLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        dateRangeSelector
                        timeBreakdownBar
                        summaryBar
                        categoryBreakdownSection
                        focusTrendSection
                        distractionPatternsSection
                        streaksSection
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 32)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { viewModel.refresh() }
        .onChange(of: viewModel.selectedRange) { _ in viewModel.refresh() }
        .onChange(of: viewModel.customStartDate) { _ in
            if viewModel.selectedRange == .custom { viewModel.refresh() }
        }
        .onChange(of: viewModel.customEndDate) { _ in
            if viewModel.selectedRange == .custom { viewModel.refresh() }
        }
    }

    // MARK: - Date Range Selector

    private var dateRangeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(AnalyticsDateRange.allCases) { range in
                    Button {
                        viewModel.selectedRange = range
                    } label: {
                        Text(range.rawValue)
                            .font(.custom("Nunito-SemiBold", size: 13))
                            .foregroundColor(
                                viewModel.selectedRange == range
                                    ? .white
                                    : Color(hex: "1F1C17")
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        viewModel.selectedRange == range
                                            ? Color(hex: "F96E00")
                                            : Color.white.opacity(0.85)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        viewModel.selectedRange == range
                                            ? Color.clear
                                            : Color(hex: "FFE0A5"),
                                        lineWidth: 1
                                    )
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
                        .labelsHidden()
                    Text("to")
                        .font(.custom("Nunito", size: 13))
                        .foregroundColor(Color(hex: "1F1C17").opacity(0.6))
                    DatePicker("To", selection: $viewModel.customEndDate, displayedComponents: .date)
                        .font(.custom("Nunito", size: 13))
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: - Time Breakdown Bar

    private var timeBreakdownBar: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Tracked",
                value: formatDuration(viewModel.timeBreakdown?.trackedSeconds ?? 0),
                color: Color(hex: "22C55E")
            )
            summaryCard(
                title: "Not Tracked",
                value: formatDuration(viewModel.timeBreakdown?.notTrackedSeconds ?? 0),
                color: Color(hex: "F96E00")
            )
            summaryCard(
                title: "Machine Off",
                value: formatDuration(viewModel.timeBreakdown?.machineOffSeconds ?? 0),
                color: Color(hex: "A0AEC0")
            )
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Productive",
                value: formatDuration(viewModel.summary?.productiveSeconds ?? 0),
                color: Color(hex: "22C55E")
            )
            summaryCard(
                title: "Distracted",
                value: formatDuration(viewModel.summary?.distractedSeconds ?? 0),
                color: Color(hex: "FF5950")
            )
            summaryCard(
                title: "Idle",
                value: formatDuration(viewModel.summary?.idleSeconds ?? 0),
                color: Color(hex: "A0AEC0")
            )
            focusScoreCard
        }
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(Color(hex: "1F1C17").opacity(0.6))
            Text(value)
                .font(.custom("Nunito-Bold", size: 22))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "FFE0A5"), lineWidth: 1)
        )
    }

    private var focusScoreCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Focus Score")
                .font(.custom("Nunito", size: 12))
                .foregroundColor(Color(hex: "1F1C17").opacity(0.6))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(focusScoreText)
                    .font(.custom("Nunito-Bold", size: 22))
                    .foregroundColor(Color(hex: "F96E00"))
                if let delta = focusDeltaText {
                    Text(delta.text)
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundColor(delta.isPositive ? Color(hex: "22C55E") : Color(hex: "FF5950"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "FFE0A5"), lineWidth: 1)
        )
    }

    private var focusScoreText: String {
        guard let s = viewModel.summary else { return "--" }
        return "\(Int(s.focusScore * 100))%"
    }

    private var focusDeltaText: (text: String, isPositive: Bool)? {
        guard let s = viewModel.summary, let prev = s.previousPeriodFocusScore else { return nil }
        let delta = (s.focusScore - prev) * 100
        if abs(delta) < 0.5 { return nil }
        let sign = delta > 0 ? "+" : ""
        return ("\(sign)\(Int(delta))%", delta > 0)
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(Color(hex: "1F1C17"))

            HStack(alignment: .top, spacing: 20) {
                // Donut chart
                if !viewModel.categoryBreakdown.isEmpty {
                    Chart(viewModel.categoryBreakdown) { item in
                        SectorMark(
                            angle: .value("Time", item.totalSeconds),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(colorForCategory(item.category))
                        .cornerRadius(4)
                    }
                    .frame(width: 160, height: 160)
                }

                // Legend list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.categoryBreakdown) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(colorForCategory(item.category))
                                .frame(width: 10, height: 10)
                            Text(item.category)
                                .font(.custom("Nunito-SemiBold", size: 13))
                                .foregroundColor(Color(hex: "1F1C17"))
                            Spacer()
                            Text(formatDuration(item.totalSeconds))
                                .font(.custom("Nunito", size: 13))
                                .foregroundColor(Color(hex: "1F1C17").opacity(0.7))
                            Text("(\(Int(item.percentage * 100))%)")
                                .font(.custom("Nunito", size: 12))
                                .foregroundColor(Color(hex: "1F1C17").opacity(0.5))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "FFE0A5"), lineWidth: 1)
            )
        }
    }

    // MARK: - Focus Trend

    private var focusTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Trend")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(Color(hex: "1F1C17"))

            if viewModel.focusTrend.isEmpty {
                Text("No data for this period")
                    .font(.custom("Nunito", size: 13))
                    .foregroundColor(Color(hex: "1F1C17").opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(viewModel.focusTrend) { point in
                    BarMark(
                        x: .value("Day", formatTrendDay(point.day)),
                        y: .value("Focus", point.focusScore * 100)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "F96E00"), Color(hex: "FFB764")],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)%")
                                    .font(.custom("Nunito", size: 11))
                                    .foregroundColor(Color(hex: "1F1C17").opacity(0.5))
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color(hex: "FFE0A5"))
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(String.self) {
                                Text(v)
                                    .font(.custom("Nunito", size: 11))
                                    .foregroundColor(Color(hex: "1F1C17").opacity(0.5))
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "FFE0A5"), lineWidth: 1)
        )
    }

    // MARK: - Distraction Patterns

    private var distractionPatternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distraction Patterns")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(Color(hex: "1F1C17"))

            // Hourly chart
            Chart(viewModel.hourlyDistractions) { item in
                BarMark(
                    x: .value("Hour", formatHour(item.hour)),
                    y: .value("Minutes", item.distractionSeconds / 60)
                )
                .foregroundStyle(Color(hex: "FF5950").opacity(0.75))
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)m")
                                .font(.custom("Nunito", size: 11))
                                .foregroundColor(Color(hex: "1F1C17").opacity(0.5))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color(hex: "FFE0A5"))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 3)) { value in
                    AxisValueLabel {
                        if let v = value.as(String.self) {
                            Text(v)
                                .font(.custom("Nunito", size: 10))
                                .foregroundColor(Color(hex: "1F1C17").opacity(0.5))
                        }
                    }
                }
            }
            .frame(height: 160)

            // Top distraction sources
            if !viewModel.topDistractionSources.isEmpty {
                Divider()
                    .foregroundColor(Color(hex: "FFE0A5"))

                Text("Top Sources")
                    .font(.custom("Nunito-SemiBold", size: 14))
                    .foregroundColor(Color(hex: "1F1C17"))

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.topDistractionSources.prefix(5)) { source in
                        HStack {
                            Text(source.name)
                                .font(.custom("Nunito", size: 13))
                                .foregroundColor(Color(hex: "1F1C17"))
                                .lineLimit(1)
                            Spacer()
                            Text(formatDuration(source.totalSeconds))
                                .font(.custom("Nunito-SemiBold", size: 13))
                                .foregroundColor(Color(hex: "FF5950"))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "FFE0A5"), lineWidth: 1)
        )
    }

    // MARK: - Streaks

    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streaks")
                .font(.custom("InstrumentSerif-Regular", size: 24))
                .foregroundColor(Color(hex: "1F1C17"))

            HStack(spacing: 12) {
                streakCard(
                    title: "Current Streak",
                    value: "\(viewModel.streakInfo?.currentStreak ?? 0)",
                    unit: "days",
                    color: Color(hex: "F96E00")
                )
                streakCard(
                    title: "Best Streak",
                    value: "\(viewModel.streakInfo?.bestStreak ?? 0)",
                    unit: "days",
                    color: Color(hex: "22C55E")
                )
                streakCard(
                    title: "Weekly Consistency",
                    value: "\(Int((viewModel.streakInfo?.weeklyConsistencyScore ?? 0) * 100))%",
                    unit: nil,
                    color: Color(hex: "F96E00")
                )
            }
        }
    }

    private func streakCard(title: String, value: String, unit: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(Color(hex: "1F1C17").opacity(0.6))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.custom("Nunito-Bold", size: 28))
                    .foregroundColor(color)
                if let unit {
                    Text(unit)
                        .font(.custom("Nunito", size: 13))
                        .foregroundColor(Color(hex: "1F1C17").opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "FFE0A5"), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatTrendDay(_ dayString: String) -> String {
        // dayString is yyyy-MM-dd, show as "Mon 2" style
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dayString) else { return dayString }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Work":         return Color(hex: "F96E00")
        case "Personal":     return Color(hex: "FFB764")
        case "Distraction":  return Color(hex: "FF5950")
        default:             return Color(hex: "B0A899")  // Idle / System / other
        }
    }
}
