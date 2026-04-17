//
// ExportFileBaseName
// VideoEditor
//

import Foundation

/// Safe single path-component base name for export files (no extension).
enum ExportFileBaseName {

    /// Removes characters unsafe for a single path component; empty input becomes `Export`.
    static func sanitized(from projectName: String) -> String {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Export" }

        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let parts = trimmed.components(separatedBy: invalid).filter { !$0.isEmpty }
        let joined = parts.joined(separator: "-")
        let base = joined.isEmpty ? "Export" : joined
        return String(base.prefix(80))
    }
}
