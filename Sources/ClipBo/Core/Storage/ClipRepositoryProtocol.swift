import Foundation

/// Defines the repository contract for clipboard history persistence.
public protocol ClipRepositoryProtocol: Sendable {
    /// Inserts a new clip into persistence.
    func insert(_ clip: Clip) async throws
    
    /// Fetches the most recent clips ordered by creation date descending.
    func fetchRecent(limit: Int) async throws -> [Clip]
    
    /// Fetches a specific clip by its unique identifier.
    func fetch(byId id: UUID) async throws -> Clip?
    
    /// Updates an existing clip in persistence.
    func update(_ clip: Clip) async throws
    
    /// Deletes a clip by its unique identifier.
    func delete(byId id: UUID) async throws
    
    /// Clears all clips from the repository.
    func clearAll() async throws
    
    /// Returns the total count of stored clips.
    func count() async throws -> Int
}
