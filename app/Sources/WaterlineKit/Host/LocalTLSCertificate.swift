import CryptoKit
import Foundation
import Security

/// Request-local trust only. The compatibility profile is permitted solely after live CLI code validation.
enum LocalTLSCertificate {
    static func trust(
        der: Data, hostname: String = "127.0.0.1", at date: Date = Date(),
        allowAntigravityCLIProfile: Bool = false
    ) -> SecTrust? {
        guard hostname == "127.0.0.1", let certificate = SecCertificateCreateWithData(nil, der as CFData) else {
            return nil
        }
        if let trust = evaluate(certificate, policy: SecPolicyCreateSSL(true, hostname as CFString), at: date) {
            return trust
        }
        // Exact DER pin: reviewed SAN 127.0.0.1, RSA-2048/SHA-256 self-signature and validity.
        // This CLI-bundled certificate lacks serverAuth EKU. No other certificate inherits the exception.
        let digest = SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined()
        guard allowAntigravityCLIProfile,
            digest == "b1366941e98e584cad699a9aecfff2fdd3576c731d380cccbf31c4854c07657c",
            date >= Date(timeIntervalSince1970: 1_776_471_489),
            date < Date(timeIntervalSince1970: 1_793_665_089)
        else { return nil }
        return evaluate(certificate, policy: SecPolicyCreateBasicX509(), at: date)
    }

    private static func evaluate(_ certificate: SecCertificate, policy: SecPolicy, at date: Date) -> SecTrust? {
        var trust: SecTrust?
        guard SecTrustCreateWithCertificates(certificate, policy, &trust) == errSecSuccess, let trust,
            SecTrustSetAnchorCertificates(trust, [certificate] as CFArray) == errSecSuccess,
            SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess,
            SecTrustSetNetworkFetchAllowed(trust, false) == errSecSuccess,
            SecTrustSetVerifyDate(trust, date as CFDate) == errSecSuccess,
            SecTrustEvaluateWithError(trust, nil)
        else { return nil }
        return trust
    }
}
