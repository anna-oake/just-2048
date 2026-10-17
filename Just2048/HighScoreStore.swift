import Foundation

final class HighScoreStore {
    private struct PlayerScore: Codable {
        var best = 0
        var submitted = 0
    }
    private struct State: Codable {
        var guestBest: Int
        var players: [String: PlayerScore] = [:]
        var lastPlayerID: String?
    }
    private let defaults: UserDefaults
    private let key = "gameCenter.highScores.v1"
    private var state: State

    init(legacyBest: Int, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(State.self, from: data) {
            state = saved
        } else {
            state = State(guestBest: max(0, legacyBest))
            persist()
        }
    }

    func best(for playerID: String?) -> Int {
        guard let playerID else { return state.guestBest }
        return state.players[playerID]?.best ?? 0
    }

    var lastSignedInBest: Int {
        state.lastPlayerID.flatMap { state.players[$0]?.best } ?? 0
    }

    func record(_ score: Int, for playerID: String?) {
        guard score > best(for: playerID) else { return }
        if let playerID {
            var player = state.players[playerID] ?? PlayerScore()
            player.best = score
            state.players[playerID] = player
        } else {
            state.guestBest = score
        }
        persist()
    }

    func claimGuestScore(for playerID: String) {
        record(state.guestBest, for: playerID)
        state.guestBest = 0
        state.lastPlayerID = playerID
        persist()
    }

    func pendingScore(for playerID: String) -> Int? {
        guard let player = state.players[playerID], player.best > player.submitted else { return nil }
        return player.best
    }

    func confirm(_ score: Int, for playerID: String) {
        var player = state.players[playerID] ?? PlayerScore()
        player.best = max(player.best, score)
        player.submitted = max(player.submitted, score)
        state.players[playerID] = player
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: key) }
    }
}
