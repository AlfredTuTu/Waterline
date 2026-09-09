import CryptoKit
import Foundation
import ImageIO
import Testing
import WaterlineKit

struct ProviderLogoResourceTests {
    private struct Manifest: Decodable {
        let license: String
        let files: [Asset]
        struct Asset: Decodable {
            let provider: String
            let sha256: String
        }
    }

    @Test func everyProviderHasAnIntactDecodableLogoAndLicense() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "Resources/ProviderLogos")
        let manifest = try JSONDecoder().decode(
            Manifest.self, from: Data(contentsOf: directory.appending(path: "provenance.json")))
        #expect(Set(manifest.files.map(\.provider)) == Set(Provider.allCases.map(\.rawValue)))
        #expect(manifest.files.count == Provider.allCases.count)
        #expect(manifest.license == "MIT")
        let license = try String(contentsOf: directory.appending(path: "LICENSE.txt"), encoding: .utf8)
        #expect(license.contains("MIT License") && license.contains("Permission is hereby granted"))
        for asset in manifest.files {
            let data = try Data(contentsOf: directory.appending(path: "Provider-\(asset.provider).png"))
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            #expect(digest == asset.sha256, "Changed logo needs provenance review: \(asset.provider)")
            let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width > 0 && image.height > 0)
        }
    }
}
