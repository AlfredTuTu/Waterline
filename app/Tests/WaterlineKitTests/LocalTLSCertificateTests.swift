import Foundation
import Testing

@testable import WaterlineKit

struct LocalTLSCertificateTests {
    @Test(arguments: ["antigravity-cli-1.1.27", "antigravity-cli-2026-09-08"])
    func compatibilityRequiresExactReviewedCertificateAndExplicitScope(name: String) throws {
        let url = try #require(
            Bundle.module.url(
                forResource: name, withExtension: "der", subdirectory: "Fixtures/local-service"))
        let data = try Data(contentsOf: url)
        let date = Date(timeIntervalSince1970: 1_788_998_400)
        #expect(LocalTLSCertificate.trust(der: data, at: date) == nil)
        #expect(LocalTLSCertificate.trust(der: data, at: date, allowAntigravityCLIProfile: true) != nil)
        #expect(
            LocalTLSCertificate.trust(der: data, hostname: "example.com", at: date, allowAntigravityCLIProfile: true)
                == nil)
        #expect(LocalTLSCertificate.trust(der: data, at: .distantPast, allowAntigravityCLIProfile: true) == nil)
        #expect(LocalTLSCertificate.trust(der: data, at: .distantFuture, allowAntigravityCLIProfile: true) == nil)
        var changed = data
        changed[changed.count - 1] ^= 1
        #expect(LocalTLSCertificate.trust(der: changed, at: date, allowAntigravityCLIProfile: true) == nil)
    }

    @Test func syntheticCertificateRequiresLocalHostAndValidDates() throws {
        let url = try #require(
            Bundle.module.url(forResource: "localhost", withExtension: "der", subdirectory: "Fixtures/local-service"))
        let data = try Data(contentsOf: url)
        let validDate = try #require(ISO8601DateFormatter().date(from: "2026-09-08T12:00:00Z"))
        #expect(LocalTLSCertificate.trust(der: data, at: validDate) != nil)
        #expect(LocalTLSCertificate.trust(der: data, hostname: "example.com", at: validDate) == nil)
        #expect(LocalTLSCertificate.trust(der: data, at: .distantPast) == nil)
        #expect(LocalTLSCertificate.trust(der: data, at: .distantFuture) == nil)
        #expect(LocalTLSCertificate.trust(der: Data("invalid".utf8), at: validDate) == nil)
    }
}
