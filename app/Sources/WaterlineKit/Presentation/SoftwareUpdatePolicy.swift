import Foundation

/// Release update configuration is independent of provider credentials and routing.
public enum SoftwareUpdatePolicy {
    public static let feedURL = "https://github.com/AlfredTuTu/Waterline/releases/latest/download/appcast.xml"

    public static func isConfigured(_ info: [String: Any]) -> Bool {
        guard info["SUFeedURL"] as? String == feedURL,
            let key = info["SUPublicEDKey"] as? String, Data(base64Encoded: key)?.count == 32
        else { return false }
        let required = [
            "SURequireSignedFeed": true, "SUVerifyUpdateBeforeExtraction": true,
            "SUEnableAutomaticChecks": false, "SUAllowsAutomaticUpdates": false,
            "SUEnableSystemProfiling": false, "SUShowReleaseNotes": false,
        ]
        return required.allSatisfy { info[$0.key] as? Bool == $0.value }
    }

    public static func permitsArchive(_ url: URL?) -> Bool {
        guard let url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
            parts.scheme == "https", parts.host == "github.com", parts.port == nil,
            parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
            parts.percentEncodedPath == parts.path
        else { return false }
        let components = parts.path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 7,
            components[0...4].map(String.init) == ["", "AlfredTuTu", "Waterline", "releases", "download"],
            components[5].hasPrefix("v"), components[5].count > 1,
            components[6].hasPrefix("Waterline-"), components[6].hasSuffix(".dmg")
        else { return false }
        return !components.contains(".") && !components.contains("..")
    }
}
