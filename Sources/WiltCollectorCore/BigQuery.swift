import Foundation

import BigQuerySwift

struct BigQuerySchema: Encodable {
    let primary_artist: String
    let artists: [String]
    let name: String
    let date: TimeInterval
    let track_id: String
    let user_id: String
}

struct DateResult: Codable, Equatable {
    let date: TimeInterval

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestampString = try container.decode(String.self, forKey: .date)
        if let date = TimeInterval(timestampString) {
            self.date = date
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "Invalid date timestamp entry."
            )
        }
    }
}

public class BigQueryInterface {
    private let bigQuery: BigQueryClient<BigQuerySchema>

    public init(projectID: String) throws {
        let s = DispatchSemaphore(value: 0)
        var response: AuthResponse?
        let provider = BigQueryAuthProvider()
        try provider.getAuthenticationToken { r in
            response = r
            s.signal()
        }
        s.wait()
        guard let r = response else {
            fatalError("Unexpected empty response")
        }
        switch r {
        case .token(let token):
            self.bigQuery = BigQueryClient(
                authenticationToken: token,
                projectID: projectID,
                datasetID: "wilt_play_history",
                tableName: "play_history"
            )
        case .error(let e):
            throw e
        }
    }

    enum WiltQueryError: Error {
        case errors([BigQueryError])
        case noRows
    }

    enum WiltInsertError: Error {
        case errors([InsertError])
    }

    /// Get the time of the last play for the specified user
    ///
    /// - Parameter user: The user to query
    /// - Returns: Time interval since 1970 of the last play of the user
    /// - Throws: If the database query fails
    public func getTimeOfLastUpdate(user: User) throws -> TimeInterval {
        let s = DispatchSemaphore(value: 0)
        let query = "SELECT date FROM wilt_play_history.play_history WHERE user_id = '\(user.id)' ORDER BY date DESC LIMIT 1"
        var response: QueryCallResponse<DateResult>?
        try bigQuery.query(query) { (r: QueryCallResponse<DateResult>) in
            response = r
            s.signal()
        }
        s.wait()
        guard let r = response else {
            fatalError("Unexpected empty query response")
        }
        switch r {
        case .error(let e):
            throw e
        case .queryResponse(let result):
            guard let rtn = result.rows?.first?.date else {
                guard let errors = result.errors else {
                    throw WiltQueryError.noRows
                }
                throw WiltQueryError.errors(errors)
            }
            return rtn
        }
    }

    /// Insert records for user
    ///
    /// - Parameters:
    ///   - items: The tracks that were played
    ///   - user: The user that played the tracks
    /// - Throws: If the insert fails
    public func insert(items: [PlayRecord], user: User) throws {
        let s = DispatchSemaphore(value: 0)
        let schema = items.map { (item: PlayRecord) -> BigQuerySchema in
            let track = item.track
            let artists = track.artists.map { $0.name }
            guard artists.count > 0 else {
                fatalError("Unexpected empty artist list")
            }
            let playedAt = item.playedAt.timeIntervalSince1970
            return BigQuerySchema(
                primary_artist: artists.first!,
                artists: artists,
                name: track.name,
                date: playedAt,
                track_id: track.id,
                user_id: user.id
            )
        }
        var response: Result<InsertHTTPResponse, Error>?
        try bigQuery.insert(rows:  schema) { r in
            response = r
            s.signal()
        }
        s.wait()
        guard let r = response else {
            fatalError("Unexpected empty insert response")
        }
        switch r {
        case .failure(let e):
            throw e
        case .success(let insertResponse):
            if let errors = insertResponse.insertErrors {
                throw WiltInsertError.errors(errors)
            }
        }
    }
}
