import Foundation

struct AgentMemoryService {
    var client: APIClient = .shared

    func fetch() async throws -> [AgentMemory] {
        try await client.agentMemories()
    }

    func delete(id: String) async throws {
        try await client.deleteAgentMemory(id: id)
    }
}
