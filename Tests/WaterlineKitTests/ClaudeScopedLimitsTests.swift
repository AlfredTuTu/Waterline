import Foundation
import Testing

@testable import WaterlineKit

struct ClaudeScopedLimitsTests {
    private func limit(_ id: String, name: String, percent: Any) -> [String: Any] {
        [
            "kind": "weekly_scoped", "group": "weekly", "percent": percent,
            "is_active": false, "scope": ["model": ["id": id, "display_name": name]],
        ]
    }

    private func parse(_ limits: [Any], plan: String? = "max") throws -> Usage {
        let value: [String: Any] = [
            "five_hour": ["utilization": 10], "seven_day": ["utilization": 90], "limits": limits,
        ]
        return try ClaudeCodeAdapter.parse(JSONSerialization.data(withJSONObject: value), plan: plan)
    }

    @Test func modelScopesAreReportedNotInferredFromTier() throws {
        for plan in ["pro", "max", "future-tier"] {
            let empty = try parse([], plan: plan)
            #expect(empty.quotaWindows.count == 2)
            let usage = try parse(
                [limit("fable", name: "Fable", percent: 42), limit("new-model", name: "New Model", percent: 0)],
                plan: plan)
            #expect(usage.quotaWindows.count == 4)
            let fable = try #require(usage.quotaWindows.first { $0.label == "Fable · 7d" })
            #expect(fable.usedFraction == 0.42)
            #expect(fable.durationSeconds == 604800)
            #expect(Dashboard.overviewWindows(usage).map(\.label) == ["5h", "7d"])
        }
    }

    @Test func scopeIdentitySurvivesOrderAndMissingAmountsStayMissing() throws {
        let fable = limit("fable", name: "Fable", percent: NSNull())
        let future = limit("future", name: "Future", percent: 20)
        let first = try parse([fable, future])
        let reversed = try parse([future, fable])
        #expect(Set(first.quotaWindows.compactMap(\.id)) == Set(reversed.quotaWindows.compactMap(\.id)))
        let empty = try #require(first.quotaWindows.first { $0.label == "Fable · 7d" })
        #expect(empty.usedFraction == nil && empty.resetsAt == nil)
    }

    @Test func conflictingOrInvalidScopeDoesNotDiscardIndependentQuotas() throws {
        let usage = try parse([
            limit("fable", name: "Fable", percent: 10), limit("fable", name: "Fable", percent: 30),
            limit("valid", name: "Valid", percent: 0), limit("bad", name: "Bad", percent: true),
            limit("all-models", name: "All Models", percent: 90),
            ["kind": "future_kind", "group": "monthly", "percent": "unreviewed"],
        ])
        #expect(usage.quotaWindows.map(\.label) == ["5h", "7d", "Valid · 7d"])
        #expect(usage.componentFailures.count == 2)
    }

    @Test func malformedIdentityFieldsAreNotTreatedAsMissing() throws {
        for field in ["id", "display_name"] {
            var malformed = limit("fable", name: "Fable", percent: 42)
            var model: [String: Any] = ["id": "fable", "display_name": "Fable"]
            model[field] = 123
            malformed["scope"] = ["model": model]
            let usage = try parse([malformed, limit("valid", name: "Valid", percent: 20)])
            #expect(usage.quotaWindows.map(\.label) == ["5h", "7d", "Valid · 7d"])
            #expect(usage.componentFailures.count == 1)
            #expect(
                usage.componentFailures.first?.error
                    == .schemaChanged(detail: "limits.0.scope.model.\(field)"))
        }
    }

    @Test func absentIdentityFieldsUseTheReportedFallback() throws {
        var named = limit("fable", name: "Fable", percent: 42)
        named["scope"] = ["model": ["id": NSNull(), "display_name": "Fable"]]
        var identified = limit("future", name: "Future", percent: 20)
        identified["scope"] = ["model": ["id": "future"]]
        let usage = try parse([named, identified])
        #expect(usage.componentFailures.isEmpty)
        #expect(usage.quotaWindows.map(\.label) == ["5h", "7d", "Fable · 7d", "future · 7d"])
    }

    @Test func duplicateRecordsAndInvalidResetsAreIsolated() throws {
        var valid = limit("fable", name: "Fable", percent: 100)
        valid["resets_at"] = "2026-09-08T12:00:00.123Z"
        var invalid = limit("bad", name: "Bad", percent: 10)
        invalid["resets_at"] = "not-a-date"
        let usage = try parse([valid, valid, invalid])
        #expect(usage.quotaWindows.map(\.label) == ["5h", "7d", "Fable · 7d"])
        #expect(usage.quotaWindows.last?.usedFraction == 1)
        #expect(usage.quotaWindows.last?.resetsAt != nil)
        #expect(usage.componentFailures.count == 1)
        #expect(usage.componentFailures.first?.error == .schemaChanged(detail: "limits.2.resets_at"))
    }
}
