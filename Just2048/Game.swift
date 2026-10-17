import Foundation

enum Direction: CaseIterable { case up, right, down, left }

struct Tile: Codable, Equatable, Identifiable {
    let id: UUID
    var value: Int
    var cell: Int
    init(value: Int, cell: Int) { self.id = UUID(); self.value = value; self.cell = cell }
}

struct Motion { let id: UUID; let destination: Int }
struct Turn {
    var motions: [Motion] = []
    var merged: Set<UUID> = []
    var spawned: UUID?
    var gained = 0
    var highestMerge = 0
    var mergeFeedback: MergeFeedback? { highestMerge >= 4 ? MergeFeedback(value: highestMerge) : nil }
}

struct Game: Codable, Equatable {
    var tiles: [Tile] = []
    var score = 0
    var best = 0
    var won = false
    var continued = false

    var needsWinPrompt: Bool { won && !continued }
    var isOver: Bool {
        guard tiles.count == 16 else { return false }
        let board = values
        for cell in 0..<16 {
            if cell % 4 < 3 && board[cell] == board[cell + 1] { return false }
            if cell / 4 < 3 && board[cell] == board[cell + 4] { return false }
        }
        return true
    }
    var values: [Int] {
        var result = Array(repeating: 0, count: 16)
        for tile in tiles { result[tile.cell] = tile.value }
        return result
    }
    var isValid: Bool {
        score >= 0 && best >= score && tiles.count >= 2 && tiles.count <= 16 &&
        Set(tiles.map(\.cell)).count == tiles.count && Set(tiles.map(\.id)).count == tiles.count &&
        tiles.allSatisfy { (0..<16).contains($0.cell) && $0.value >= 2 && ($0.value & ($0.value - 1)) == 0 }
    }

    init(best: Int = 0) {
        self.best = best
        _ = spawn(); _ = spawn()
    }

    @discardableResult mutating func spawn() -> UUID? {
        let occupied = Set(tiles.map(\.cell))
        guard let cell = (0..<16).filter({ !occupied.contains($0) }).randomElement() else { return nil }
        let tile = Tile(value: Int.random(in: 0..<10) < 9 ? 2 : 4, cell: cell)
        tiles.append(tile)
        return tile.id
    }

    mutating func move(_ direction: Direction, spawnTile: Bool = true) -> Turn? {
        guard !needsWinPrompt && !isOver else { return nil }
        var turn = Turn()
        var next: [Tile] = []
        for line in 0..<4 {
            let cells = (0..<4).map { offset -> Int in
                switch direction {
                case .left: return line * 4 + offset
                case .right: return line * 4 + 3 - offset
                case .up: return offset * 4 + line
                case .down: return (3 - offset) * 4 + line
                }
            }
            let sources = cells.compactMap { cell in tiles.first { $0.cell == cell } }
            var i = 0
            var output = 0
            while i < sources.count {
                var tile = sources[i]
                let target = cells[output]
                turn.motions.append(Motion(id: tile.id, destination: target))
                if i + 1 < sources.count && sources[i + 1].value == tile.value {
                    turn.motions.append(Motion(id: sources[i + 1].id, destination: target))
                    tile.value *= 2
                    turn.gained += tile.value
                    turn.highestMerge = max(turn.highestMerge, tile.value)
                    turn.merged.insert(tile.id)
                    i += 2
                } else { i += 1 }
                tile.cell = target
                next.append(tile)
                output += 1
            }
        }
        guard next.sorted(by: { $0.cell < $1.cell }) != tiles.sorted(by: { $0.cell < $1.cell }) else { return nil }
        tiles = next
        score += turn.gained
        best = max(best, score)
        won = won || tiles.contains { $0.value >= 2048 }
        if spawnTile { turn.spawned = spawn() }
        return turn
    }
}

final class GameStore {
    private let url: URL
    private let defaults: UserDefaults
    init(url: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.url = url ?? directory.appendingPathComponent("game-v1.json")
    }
    func load() -> Game {
        let best = defaults.integer(forKey: "bestScore")
        if let data = try? Data(contentsOf: url), var game = try? JSONDecoder().decode(Game.self, from: data), game.isValid {
            game.best = max(best, game.best)
            return game
        }
        return Game(best: best)
    }
    @discardableResult func save(_ game: Game) -> Bool {
        defaults.set(max(defaults.integer(forKey: "bestScore"), game.best), forKey: "bestScore")
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(game).write(to: url, options: .atomic)
            return true
        } catch { return false }
    }
}

struct DragIntent {
    let threshold: Double
    private(set) var distance = 0.0
    private(set) var furthest = 0.0
    private(set) var hasCrossedThreshold = false
    private(set) var hasReversed = false
    private var feedbackReady = true

    init(threshold: Double) { self.threshold = threshold }

    mutating func update(distance: Double) -> Bool {
        self.distance = max(0, distance)
        furthest = max(furthest, self.distance)
        if furthest - self.distance >= 8 { hasReversed = true }
        if self.distance < threshold - 6 { feedbackReady = true }
        guard self.distance >= threshold else { return false }
        hasCrossedThreshold = true
        guard feedbackReady else { return false }
        feedbackReady = false
        return true
    }
    func shouldCommit(velocity: Double) -> Bool {
        if distance >= threshold { return true }
        return !hasCrossedThreshold && !hasReversed && distance >= 7 && velocity >= 560
    }
}

struct MagneticMergeGeometry {
    let side: Double
    let separation: Double
    let movement: Double
    let attraction: Double
    let pull: Double
    let smoothing: Double
    var halfSide: Double { side / 2 }

    init(side: Double, separation: Double, movement: Double) {
        self.side = side
        self.separation = separation
        self.movement = movement
        func smooth(_ x: Double) -> Double {
            let t = min(1, max(0, x))
            return t * t * (3 - 2 * t)
        }
        let proximity = 1 - smooth(max(0, separation - side) / (side * 0.45))
        let activation = smooth(movement / (side * 0.15))
        let release = smooth(separation / (side * 0.75))
        attraction = proximity * activation * release
        pull = side * 0.10 * attraction
        smoothing = side * 0.12 * attraction
    }
    private func smooth(_ x: Double) -> Double {
        let t = min(1, max(0, x))
        return t * t * (3 - 2 * t)
    }
    var fusion: Double {
        min(1, max(0, (side + 2 * pull + smoothing * 0.5 - separation) / (side * 0.9)))
    }

    func signedDistance(x: Double, y: Double) -> Double {
        let normalY = y / halfSide
        let base = max(0, 1 - normalY * normalY)
        let profile = base * base * base
        func tile(center: Double, facing: Double) -> Double {
            let dx = x - center
            let facingInfluence = smooth(dx * facing / halfSide)
            let deformedX = dx - facing * pull * profile * facingInfluence
            let radius = side * 0.24
            let qx = abs(deformedX) - (halfSide - radius)
            let qy = abs(y) - (halfSide - radius)
            let x = max(qx, 0), y = max(qy, 0)
            let outside = sqrt(sqrt(x * x * x * x + y * y * y * y))
            return outside + min(max(qx, qy), 0) - radius
        }
        let a = tile(center: -separation / 2, facing: 1)
        let b = tile(center: separation / 2, facing: -1)
        let localSmoothing = smoothing * profile
        guard localSmoothing > 0.000001 else { return min(a, b) }
        let overlap = max(localSmoothing - abs(a - b), 0) / localSmoothing
        return min(a, b) - overlap * overlap * localSmoothing * 0.25
    }

    func halfHeight(at x: Double) -> Double? {
        guard signedDistance(x: x, y: 0) <= 0.000001 else { return nil }
        if signedDistance(x: x, y: halfSide) <= 0.000001 { return halfSide }
        var low = 0.0, high = halfSide
        for _ in 0..<9 {
            let middle = (low + high) / 2
            if signedDistance(x: x, y: middle) <= 0 { low = middle } else { high = middle }
        }
        return (low + high) / 2
    }
}


struct MergeFeedback: Equatable {
    let value: Int
    var tier: Int { max(0, Int(log2(Double(value))) - 2) }
    var intensity: Float { Float(0.28 + 0.72 * (1 - exp(-Double(tier) / 6))) }
    var sharpness: Float { Float(0.12 + 0.73 * (1 - exp(-Double(tier) / 8))) }
}

enum CutoffCue: Equatable { case entered, exited }

struct CutoffFeedbackState {
    private(set) var isOn = false

    mutating func update(distance: Double, threshold: Double, speed: Double, elapsed: Double, allowEntry: Bool = true) -> CutoffCue? {
        if distance < threshold {
            guard isOn else { return nil }
            isOn = false
            return .exited
        }
        guard !isOn, allowEntry, elapsed >= 0.08, abs(speed) <= 420 else { return nil }
        isOn = true
        return .entered
    }
}
