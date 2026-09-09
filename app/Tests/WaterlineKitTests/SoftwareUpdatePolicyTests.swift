import Foundation
import Testing

@testable import WaterlineKit

struct SoftwareUpdatePolicyTests {
    @Test func missingOrWeakenedConfigurationCannotStartUpdater() {
        // Synthetic public-key bytes validate encoding only, not signing-key ownership.
        let valid: [String: Any] = [
            "SUFeedURL": SoftwareUpdatePolicy.feedURL,
            "SUPublicEDKey": Data(repeating: 7, count: 32).base64EncodedString(),
            "SURequireSignedFeed": true, "SUVerifyUpdateBeforeExtraction": true,
            "SUEnableAutomaticChecks": false, "SUAllowsAutomaticUpdates": false,
            "SUEnableSystemProfiling": false, "SUShowReleaseNotes": false,
        ]
        #expect(SoftwareUpdatePolicy.isConfigured(valid))
        #expect(!SoftwareUpdatePolicy.isConfigured([:]))
        for key in valid.keys {
            var missing = valid
            missing.removeValue(forKey: key)
            #expect(!SoftwareUpdatePolicy.isConfigured(missing))
            if let boolean = valid[key] as? Bool {
                var changed = valid
                changed[key] = !boolean
                #expect(!SoftwareUpdatePolicy.isConfigured(changed))
            }
        }
        for badKey in ["invalid", Data(repeating: 7, count: 31).base64EncodedString()] {
            var changed = valid
            changed["SUPublicEDKey"] = badKey
            #expect(!SoftwareUpdatePolicy.isConfigured(changed))
        }
    }

    @Test func updateArchiveMustBelongToVersionedProjectRelease() {
        let valid = "https://github.com/AlfredTuTu/Waterline/releases/download/v1.2.3/Waterline-1.2.3-arm64.dmg"
        #expect(SoftwareUpdatePolicy.permitsArchive(URL(string: valid)))
        #expect(!SoftwareUpdatePolicy.permitsArchive(nil))
        for invalid in [
            valid.replacingOccurrences(of: "https:", with: "http:"),
            valid.replacingOccurrences(of: "github.com", with: "github.com.attacker.test"),
            valid.replacingOccurrences(of: "github.com", with: "user@github.com"),
            valid.replacingOccurrences(of: "AlfredTuTu", with: "Other"),
            valid.replacingOccurrences(of: "/v1.2.3/", with: "/../"),
            valid.replacingOccurrences(of: "/v1.2.3/", with: "/%2e%2e/"),
            valid.replacingOccurrences(of: ".dmg", with: ".pkg"),
            valid + "?token=example", valid + "#fragment",
        ] {
            #expect(!SoftwareUpdatePolicy.permitsArchive(URL(string: invalid)))
        }
    }
}
