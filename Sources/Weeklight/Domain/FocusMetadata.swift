import Foundation

struct GitHubReference: Equatable, Sendable {
    enum Kind: String, Sendable {
        case commit
        case pullRequest = "pull request"
        case issue
    }

    let url: URL
    let repository: String
    let kind: Kind
    let identifier: String

    var compactTitle: String {
        let value = kind == .commit ? String(identifier.prefix(7)) : "#\(identifier)"
        return "\(repository) · \(kind.rawValue) \(value)"
    }
}

enum FocusMetadata {
    static let maximumNoteLength = 20_000
    static let maximumTagCount = 5
    static let maximumTagLength = 24

    static func cleanNote(_ note: String) -> String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanTag(_ tag: String) -> String {
        var value = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix("#") {
            value.removeFirst()
            value = value.trimmingCharacters(in: .whitespaces)
        }
        return value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func normalizedTag(_ tag: String) -> String {
        cleanTag(tag)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
    }

    static func uniqueCleanTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { rawTag in
            let cleaned = cleanTag(rawTag)
            let normalized = normalizedTag(cleaned)
            guard !cleaned.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            return cleaned
        }
    }

    static func summary(from markdown: String, limit: Int = 140) -> String {
        guard var line = markdown
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .first(where: { !$0.isEmpty }) else {
            return ""
        }

        line = line.replacingOccurrences(
            of: #"^(#{1,6}|>|[-+*]|\d+\.)\s+"#,
            with: "",
            options: .regularExpression
        )
        line = line.replacingOccurrences(
            of: #"^\[[ xX]\]\s+"#,
            with: "",
            options: .regularExpression
        )
        line = line.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^\)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        line = line.replacingOccurrences(
            of: #"[*_`~]"#,
            with: "",
            options: .regularExpression
        )

        guard line.count > limit else { return line }
        return String(line.prefix(max(1, limit - 1))).trimmingCharacters(in: .whitespaces) + "…"
    }

    static func safeLinks(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return [] }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var seen = Set<String>()
        return detector.matches(in: text, options: [], range: range).compactMap {
            guard let url = $0.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else {
                return nil
            }
            let key = url.absoluteString
            return seen.insert(key).inserted ? url : nil
        }
    }

    static func githubReference(for url: URL) -> GitHubReference? {
        guard let host = url.host?.lowercased(),
              host == "github.com" || host == "www.github.com" else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 4 else { return nil }
        let repository = "\(components[0])/\(components[1])"
        let identifier = components[3]
        guard !identifier.isEmpty else { return nil }

        let kind: GitHubReference.Kind
        switch components[2].lowercased() {
        case "commit":
            kind = .commit
        case "pull":
            kind = .pullRequest
        case "issues":
            kind = .issue
        default:
            return nil
        }
        return GitHubReference(
            url: url,
            repository: repository,
            kind: kind,
            identifier: identifier
        )
    }
}
