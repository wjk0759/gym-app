import Foundation

/// AI 长期记忆的读取/删除边界；不负责生成或写入记忆。
struct AgentMemoryService {
    var client: APIClient = .shared

    func fetch() async throws -> [AgentMemory] {
        try await client.agentMemories()
    }

    func delete(id: String) async throws {
        try await client.deleteAgentMemory(id: id)
    }
}
