import Darwin
import Foundation
import Security

extension LocalProcessIdentity {
    /// This requirement matches the reviewed official CLI, not merely its executable filename.
    func isAntigravityCLI(expectedExecutable: URL) -> Bool {
        guard isCurrent(expectedExecutable: expectedExecutable, userID: getuid()) else { return false }
        var code: SecCode?
        let attributes = [kSecGuestAttributePid: pid] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &code) == errSecSuccess, let code else {
            return false
        }
        var requirement: SecRequirement?
        let rule = #"anchor apple generic and identifier "cli" and certificate leaf[subject.OU] = "EQHXZ8M8AV""#
        guard SecRequirementCreateWithString(rule as CFString, SecCSFlags(), &requirement) == errSecSuccess,
            let requirement,
            SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess
        else { return false }
        return isCurrent(expectedExecutable: expectedExecutable, userID: getuid())
    }
}
