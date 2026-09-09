import Foundation
import Testing

@testable import WaterlineKit

struct CodexAdapterTests {
    @Test func fiveHourTakesPriorityEvenWhenWeeklyUsageIsHigher() throws {
        for plan in ["plus", "pro", "future-plan"] {
            let payload: [String: Any] = [
                "plan_type": plan,
                "rate_limit": [
                    "primary_window": ["used_percent": 90, "limit_window_seconds": 604800],
                    "secondary_window": ["used_percent": 6, "limit_window_seconds": 18000],
                ],
            ]
            let usage = try CodexAdapter.parse(JSONSerialization.data(withJSONObject: payload))
            let displayed = Dashboard.overviewWindows(usage)
            #expect(displayed.map(\.label) == ["5h", "7d"])
            #expect(displayed.map(\.usedFraction) == [0.06, 0.9])
            #expect(displayed.map(\.durationSeconds) == [18000, 604800])
        }
    }
    @Test func plusAndOtherPlansUseTheirOwnReportedWindows() throws {
        // Synthetic account-specific shapes. Plan names do not infer the available windows.
        let plus = try CodexAdapter.parse(
            Data(
                #"{"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":46,"limit_window_seconds":18000,"reset_at":1800000000},"secondary_window":{"used_percent":18,"limit_window_seconds":604800,"reset_at":1800500000}}}"#
                    .utf8))
        let other = try CodexAdapter.parse(
            Data(
                #"{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":37,"limit_window_seconds":604800,"reset_at":1800500000}}}"#
                    .utf8))
        #expect(plus.planLabel == "plus")
        #expect(Dashboard.overviewWindows(plus).map(\.label) == ["5h", "7d"])
        #expect(Dashboard.overviewWindows(plus).map(\.usedFraction) == [0.46, 0.18])
        #expect(other.planLabel == "pro")
        #expect(Dashboard.overviewWindows(other).map(\.label) == ["7d"])
    }

    @Test func planNameNeverInventsAnAbsentFiveHourWindow() throws {
        let plus = try CodexAdapter.parse(
            Data(
                #"{"plan_type":"plus","rate_limit":{"secondary_window":{"used_percent":18,"limit_window_seconds":604800}}}"#
                    .utf8))
        #expect(plus.quotaWindows.map(\.label) == ["7d"])
        #expect(plus.quotaWindows.first?.resetsAt == nil)
    }

    @Test func zeroMissingResetAndAdditionalBuckets() throws {
        let data = Data(
            #"{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":0}},"additional_rate_limits":[{"metered_feature":"other","rate_limit":{"secondary_window":{"used_percent":73,"reset_at":1800000000}}}],"future_field":true}"#
                .utf8)
        let result = try CodexAdapter.parse(data)
        guard case .metrics(let windows, _, let plan, let failures) = result else {
            Issue.record("Expected metrics"); return
        }
        #expect(windows.count == 2)
        #expect(windows[0].usedFraction == 0)
        #expect(windows[0].resetsAt == nil)
        #expect(windows[1].usedFraction == 0.73)
        #expect(plan == "pro")
        #expect(failures.isEmpty)
    }

    @Test func malformedComponentKeepsIndependentWindow() throws {
        let result = try CodexAdapter.parse(
            Data(
                #"{"rate_limit":{"primary_window":{"used_percent":"broken"},"secondary_window":{"used_percent":20}}}"#
                    .utf8))
        guard case .metrics(let windows, _, _, let failures) = result else {
            Issue.record("Expected metrics"); return
        }
        #expect(windows.count == 1)
        #expect(windows[0].usedFraction == 0.2)
        #expect(failures.first?.error == .schemaChanged(detail: "rate_limit.primary_window.used_percent"))
    }

    @Test func noAllowanceStaysMissing() throws {
        let result = try CodexAdapter.parse(Data(#"{"rate_limit":null}"#.utf8))
        guard case .metrics(let windows, let balances, _, _) = result else { Issue.record("Expected metrics"); return }
        #expect(windows.isEmpty)
        #expect(balances.isEmpty)
    }

    @Test(arguments: [401, 429, 503]) func responseErrors(_ status: Int) {
        #expect(throws: FetchError.self) {
            try HTTPResponse(status: status, headers: [:], body: Data()).validateStatus()
        }
    }
}
