import Foundation

extension Notiz {
    /// Angehängte Dokumente, neueste zuerst.
    var sortedDokumente: [Dokument] {
        let set = (dokumente as? Set<Dokument>) ?? []
        return set.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }
}
