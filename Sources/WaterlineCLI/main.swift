import Foundation
import WaterlineKit

let usage = """
    usage: waterline <command>

      snapshot [--json]   print the last snapshot written by the app or a refresh
      version             print the version
    """

func printSnapshot(json: Bool) throws {
    let store = SnapshotStore.default()
    guard let snapshot = try store.load() else {
        FileHandle.standardError.write(Data("no snapshot at \(store.url.path(percentEncoded: false))\n".utf8))
        exit(2)
    }
    if json {
        print(String(decoding: try SnapshotStore.encoder.encode(snapshot), as: UTF8.self))
        return
    }
    print("generated \(snapshot.generatedAt.formatted(.iso8601))")
    for entry in snapshot.accounts {
        print("\(entry.account.provider.displayName)  \(entry.account.id)  \(entry.state)")
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "snapshot":
    try printSnapshot(json: arguments.contains("--json"))
case "version":
    print("waterline \(WaterlineVersion.current)")
default:
    print(usage)
    exit(arguments.isEmpty ? 0 : 64)
}
