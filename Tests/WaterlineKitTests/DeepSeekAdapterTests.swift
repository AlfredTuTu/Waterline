import Foundation
import Testing

@testable import WaterlineKit

struct DeepSeekAdapterTests {
    @Test func independentCurrenciesAndZeroArePreserved() throws {
        let usage = try DeepSeekAdapter.parse(
            Data(
                #"{"is_available":false,"balance_infos":[{"currency":"CNY","total_balance":"110.01","granted_balance":"10.00","topped_up_balance":"100.01"},{"currency":"USD","total_balance":"0.00"}],"future":42}"#
                    .utf8))
        #expect(usage.balances.map(\.currency) == ["CNY", "USD"])
        #expect(usage.balances[0].amount == Decimal(string: "110.01"))
        #expect(usage.balances[1].amount == 0)
        #expect(usage.componentFailures.isEmpty)
    }

    @Test func malformedCurrencyComponentDoesNotEraseOtherBalance() throws {
        let usage = try DeepSeekAdapter.parse(
            Data(
                #"{"balance_infos":[{"currency":"CNY","total_balance":"12oops"},{"currency":"USD","total_balance":"9"}]}"#
                    .utf8))
        #expect(usage.balances.map(\.currency) == ["USD"])
        #expect(usage.componentFailures.first?.id == "balance.CNY")
        #expect(usage.componentFailures.first?.error == .schemaChanged(detail: "balance_infos.0.total_balance"))
    }

    @Test func duplicateCurrenciesAreNotSummedOrChosenArbitrarily() throws {
        let usage = try DeepSeekAdapter.parse(
            Data(
                #"{"balance_infos":[{"currency":"CNY","total_balance":"12"},{"currency":"CNY","total_balance":"13"}]}"#
                    .utf8))
        #expect(usage.balances.isEmpty)
        #expect(usage.componentFailures.count == 1)
    }

    @Test func invalidGiftKeepsReportedTotal() throws {
        let usage = try DeepSeekAdapter.parse(
            Data(#"{"balance_infos":[{"currency":"CNY","total_balance":"12","granted_balance":"bad"}]}"#.utf8))
        #expect(usage.balances.first?.amount == 12)
        #expect(usage.balances.first?.gift == nil)
        #expect(usage.componentFailures.first?.id == "balance.CNY.gift")
    }
}
