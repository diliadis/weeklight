import Foundation
import Testing
@testable import Weeklight

@Suite("Focus metadata")
struct FocusMetadataTests {
    @Test("Tags are cleaned and deduplicated without losing display casing")
    func cleansTags() {
        #expect(
            FocusMetadata.uniqueCleanTags([
                " #Deep Work ",
                "deep   work",
                "GitHub"
            ]) == ["Deep Work", "GitHub"]
        )
    }

    @Test("Only safe web links are extracted")
    func safeLinks() {
        let links = FocusMetadata.safeLinks(
            in: "https://example.com and javascript:alert(1)"
        )
        #expect(links.map(\.absoluteString) == ["https://example.com"])
    }

    @Test("GitHub work references receive compact labels")
    func githubReferences() throws {
        let url = try #require(
            URL(string: "https://github.com/acme/weeklight/commit/abcdef123456")
        )
        let reference = try #require(FocusMetadata.githubReference(for: url))
        #expect(reference.kind == .commit)
        #expect(reference.repository == "acme/weeklight")
        #expect(reference.compactTitle == "acme/weeklight · commit abcdef1")
    }
}
