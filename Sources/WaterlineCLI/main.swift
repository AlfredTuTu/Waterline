import Foundation
import WaterlineKit

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["hook-claude-v1"] {
    do {
        guard isatty(STDIN_FILENO) == 0 else { throw HookActivityError.invalidInput }
        let now = Date()
        var data = Data()
        while let chunk = try FileHandle.standardInput.read(upToCount: 8192), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= 1_048_576 else { throw HookActivityError.invalidInput }
        }
        let event = try HookActivityEvent.parse(data, now: now)
        let encoded = try JSONEncoder().encode(event)
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(HookActivityEvent.notificationName), object: nil,
            userInfo: ["event": encoded], deliverImmediately: true)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("Waterline could not read the activity event.\n".utf8))
        exit(1)
    }
}

if arguments.first == "connect" {
    FileHandle.standardError.write(
        Data("Connect reads the selected tool’s saved login. macOS may request access.\n".utf8))
}
var inputSecret: Secret?
if arguments.first == "account", arguments.count > 1, ["add", "key"].contains(arguments[1]),
    arguments.contains("--stdin")
{
    guard isatty(STDIN_FILENO) == 0 else {
        FileHandle.standardError.write(
            Data("Use piped stdin for a key; interactive terminal input is not accepted.\n".utf8))
        exit(64)
    }
    do {
        var data = Data()
        while let chunk = try FileHandle.standardInput.read(upToCount: 1024), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= 8193 else { throw ManualKeyError.invalidKey }
        }
        guard let text = String(data: data, encoding: .utf8) else { throw ManualKeyError.invalidKey }
        inputSecret = Secret(text.trimmingCharacters(in: .newlines))
    } catch {
        FileHandle.standardError.write(Data("Could not read a valid key from stdin.\n".utf8))
        exit(64)
    }
}
let result = await WaterlineCLI.run(arguments, inputSecret: inputSecret)
if !result.output.isEmpty { FileHandle.standardOutput.write(Data(result.output.utf8)) }
if !result.error.isEmpty { FileHandle.standardError.write(Data(result.error.utf8)) }
exit(result.exitCode)
