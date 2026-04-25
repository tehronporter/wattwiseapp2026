import Foundation

// MARK: - Node Progress Record

private struct NodeProgressRecord: Codable {
    var nodeId: String
    var bestScore: Double
    var attemptCount: Int
    var lastAttemptAt: Date
}

// MARK: - PathProgressStore

final class PathProgressStore {
    static let shared = PathProgressStore()

    private let storageKey = "ww_path_progress_v1"
    private var records: [String: NodeProgressRecord] = [:]

    private init() { load() }

    // MARK: - Write

    func save(nodeId: String, score: Double) {
        var record = records[nodeId] ?? NodeProgressRecord(
            nodeId: nodeId, bestScore: 0, attemptCount: 0, lastAttemptAt: Date()
        )
        record.bestScore = max(record.bestScore, score)
        record.attemptCount += 1
        record.lastAttemptAt = Date()
        records[nodeId] = record
        persist()
    }

    // MARK: - Read + Apply Progress

    /// Returns a new PracticePath with statuses set from stored records and sequential unlock logic.
    func applyProgress(to path: PracticePath) -> PracticePath {
        var updatedUnits: [PracticeUnit] = []

        for (unitIndex, unit) in path.units.enumerated() {
            var updatedNodes: [PracticeNode] = []

            for (nodeIndex, node) in unit.nodes.enumerated() {
                var updatedNode = node

                if let record = records[node.id] {
                    // Have a prior attempt — set score-based status
                    updatedNode.status = record.bestScore >= 0.7
                        ? .completed(bestScore: record.bestScore)
                        : .masteryNeeded(bestScore: record.bestScore)
                } else if unitIndex == 0 && nodeIndex == 0 {
                    // First node of entire path is always available
                    updatedNode.status = .available
                } else if nodeIndex > 0 {
                    // Subsequent node within same unit — unlock after previous node passes
                    let prevNode = updatedNodes[nodeIndex - 1]
                    updatedNode.status = prevNode.status.isPassed ? .available : .locked
                } else {
                    // First node of a later unit — unlock if previous unit has any passed node
                    let prevUnitHasPassed = updatedUnits.last?.nodes.contains { $0.status.isPassed } ?? false
                    updatedNode.status = prevUnitHasPassed ? .available : .locked
                }

                updatedNodes.append(updatedNode)
            }

            updatedUnits.append(PracticeUnit(id: unit.id, title: unit.title, nodes: updatedNodes))
        }

        return PracticePath(examType: path.examType, units: updatedUnits)
    }

    // MARK: - Reset

    func reset() {
        records = [:]
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: NodeProgressRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
