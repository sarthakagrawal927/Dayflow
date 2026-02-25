# Analytics Dashboard + Analysis Frequency Presets

## Goal

Add configurable analysis frequency (presets) and a personal usage analytics dashboard to Dayflow. All changes should live in new files where possible to minimize rebase conflicts with upstream.

## Feature 1: Analysis Frequency Presets

### Presets

| Preset    | Check Interval | Batch Duration | Max Gap | Lookback |
|-----------|---------------|----------------|---------|----------|
| Relaxed   | 60s           | 15 min         | 2 min   | 45 min   |
| Frequent  | 30s           | 5 min          | 1 min   | 15 min   |
| Real-time | 15s           | 2 min          | 30s     | 6 min    |

### Files

- **NEW** `Core/Analysis/AnalysisFrequencyPreset.swift` — Preset enum, BatchingConfig factory, UserDefaults persistence
- **EDIT** `Core/Analysis/AnalysisManager.swift` — Read checkInterval from preset (~2 lines)
- **EDIT** `Core/AI/LLMTypes.swift` — BatchingConfig.standard reads from preset (~1 line)
- **EDIT** `Views/UI/Settings/SettingsOtherTabView.swift` — Add preset picker (~15 lines)
- **EDIT** `Views/UI/Settings/OtherSettingsViewModel.swift` — Add @Published var frequencyPreset (~5 lines)

## Feature 2: Analytics Dashboard

### New Files

- `Core/Analysis/AnalyticsDataService.swift` — GRDB queries against timeline_cards, aggregation logic
- `Views/UI/AnalyticsDashboardView.swift` — Main analytics SwiftUI view
- `Views/UI/AnalyticsDashboardViewModel.swift` — View model, computed metrics, trend calculations

### Wiring (existing file edits)

- `Views/UI/MainView/SidebarView.swift` — Add Analytics tab entry (~5 lines)

### Dashboard Sections

1. **Summary Bar** — Total tracked time, productive time, distracted time, focus score. Delta vs previous period.
2. **Category Breakdown** — Donut chart + table (category, time, % of total).
3. **Focus Trend** — Daily focus score line/bar chart over selected range (SwiftUI Charts).
4. **Distraction Patterns** — Bar chart by hour of day. Top distraction apps/sites from appSites + distractions fields.
5. **Streaks & Consistency** — Current streak (days with 4+ hrs productive), best streak, weekly consistency.
6. **Date Controls** — Quick filters (Today, This Week, This Month) + custom date range picker.

### Data Flow

```
timeline_cards (SQLite) -> AnalyticsDataService (GRDB) -> ViewModel (metrics) -> View (Charts)
```

### Data Sources

- `timeline_cards` table: category, subcategory, start_ts, end_ts, day, distractions (JSON), appSites
- `observations` table: for granular time tracking
- All queries go through AnalyticsDataService, no direct DB access from views

## Out of Scope

- Export/sharing
- Goals/targets system
- Distraction notifications
- Cross-user comparison
- LLM performance analytics (cost/latency tracking)
