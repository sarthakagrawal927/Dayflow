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
            return BatchingConfig(targetDuration: 15 * 60, maxGap: 2 * 60, cardLookbackDuration: 45 * 60)
        case .frequent:
            return BatchingConfig(targetDuration: 5 * 60, maxGap: 1 * 60, cardLookbackDuration: 15 * 60)
        case .realtime:
            return BatchingConfig(targetDuration: 2 * 60, maxGap: 30, cardLookbackDuration: 6 * 60)
        }
    }

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
