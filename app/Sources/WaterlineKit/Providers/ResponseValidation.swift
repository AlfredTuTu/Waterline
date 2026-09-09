import Foundation

extension HTTPResponse {
    public func validateStatus(now: Date = Date()) throws {
        switch status {
        case 200..<300: return
        case 401: throw FetchError.unauthorized
        case 403: throw FetchError.permissionDenied
        case 429:
            let value = headers.first { $0.key.lowercased() == "retry-after" }?.value
            var delay = value.flatMap(Double.init).flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
            if delay == nil, let value {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                delay = formatter.date(from: value).map { max(0, $0.timeIntervalSince(now)) }
            }
            throw FetchError.rateLimited(retryAfter: delay)
        default: throw FetchError.transport(detail: "Service request failed")
        }
    }
}

func schemaError(_ error: any Error, prefix: String) -> FetchError {
    let path: [any CodingKey]
    switch error {
    case DecodingError.keyNotFound(let key, let context): path = context.codingPath + [key]
    case DecodingError.typeMismatch(_, let context), DecodingError.valueNotFound(_, let context),
        DecodingError.dataCorrupted(let context):
        path = context.codingPath
    default: return .schemaChanged(detail: prefix)
    }
    return .schemaChanged(detail: ([prefix] + path.map(\.stringValue)).joined(separator: "."))
}
