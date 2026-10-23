import UIKit
@preconcurrency import GameKit

@MainActor
final class GameCenter: NSObject, @MainActor GKGameCenterControllerDelegate {
    static let leaderboardID = "sh.anya.2048.highscore"
    var onBestScoreChanged: ((Int) -> Void)?
    private let scores: HighScoreStore
    private weak var presenter: UIViewController?
    private var started = false
    private var requestedDashboard = false
    private var authenticationController: UIViewController?
    private var playerID: String?
    private var submittingFor: String?
    private var retry: DispatchWorkItem?

    var best: Int {
        if let playerID { return scores.best(for: playerID) }
        return max(scores.best(for: nil), scores.lastSignedInBest)
    }

    init(legacyBest: Int) {
        scores = HighScoreStore(legacyBest: legacyBest)
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(becameActive(_:)),
                                               name: UIScene.didActivateNotification, object: nil)
    }

    func start(presenting controller: UIViewController) {
        presenter = controller
        guard !started else { return }
        started = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            Task { @MainActor in self?.authenticated(controller: controller, error: error) }
        }
    }

    func record(score: Int) {
        let currentID = GKLocalPlayer.local.isAuthenticated && GKLocalPlayer.local.gamePlayerID == playerID ? playerID : nil
        scores.record(score, for: currentID)
        onBestScoreChanged?(best)
        submitPendingScore()
    }

    func showDashboard(from controller: UIViewController) {
        presenter = controller
        guard !GKLocalPlayer.local.isAuthenticated else {
            submitPendingScore()
            let dashboard = GKGameCenterViewController(leaderboardID: Self.leaderboardID,
                                                       playerScope: .friendsOnly, timeScope: .allTime)
            dashboard.gameCenterDelegate = self
            controller.present(dashboard, animated: true)
            return
        }
        requestedDashboard = true
        if let authenticationController {
            controller.present(authenticationController, animated: true)
        } else if !started {
            start(presenting: controller)
        } else {
            requestedDashboard = false
            showError("Sign in to Game Center in Settings to see your leaderboard.")
        }
    }

    private func authenticated(controller: UIViewController?, error: Error?) {
        authenticationController = controller
        if let controller {
            if presenter?.presentedViewController == nil { presenter?.present(controller, animated: true) }
            return
        }
        retry?.cancel()
        retry = nil
        playerID = GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.gamePlayerID : nil
        if let playerID {
            scores.claimGuestScore(for: playerID)
            refreshBestScore(for: playerID)
            submitPendingScore()
        }
        onBestScoreChanged?(best)
        if requestedDashboard {
            requestedDashboard = false
            if playerID != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self, let presenter = self.presenter, presenter.presentedViewController == nil else { return }
                    self.showDashboard(from: presenter)
                }
            } else {
                showError(error?.localizedDescription ?? "Sign in to Game Center in Settings to see your leaderboard.")
            }
        }
        if let error { NSLog("Game Center authentication: %@", error.localizedDescription) }
    }

    @objc private func becameActive(_ notification: Notification) {
        guard notification.object as? UIScene === presenter?.view.window?.windowScene else { return }
        guard let playerID, GKLocalPlayer.local.isAuthenticated,
              playerID == GKLocalPlayer.local.gamePlayerID else { return }
        retry?.cancel()
        retry = nil
        refreshBestScore(for: playerID)
        submitPendingScore()
    }

    private func refreshBestScore(for id: String) {
        Task { [weak self] in
            do {
                let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [Self.leaderboardID])
                guard let self, self.playerID == id, GKLocalPlayer.local.isAuthenticated,
                      GKLocalPlayer.local.gamePlayerID == id, let leaderboard = leaderboards.first else { return }
                let (local, _) = try await leaderboard.loadEntries(for: [GKLocalPlayer.local], timeScope: .allTime)
                guard self.playerID == id, GKLocalPlayer.local.isAuthenticated,
                      GKLocalPlayer.local.gamePlayerID == id else { return }
                if let local { self.scores.confirm(local.score, for: id) }
                self.onBestScoreChanged?(self.best)
            } catch {
                NSLog("Game Center best score: %@", error.localizedDescription)
            }
        }
    }

    private func submitPendingScore() {
        guard submittingFor == nil, retry == nil, let id = playerID,
              GKLocalPlayer.local.isAuthenticated, GKLocalPlayer.local.gamePlayerID == id,
              let score = scores.pendingScore(for: id) else { return }
        submittingFor = id
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [Self.leaderboardID]) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.submittingFor = nil
                if let error {
                    NSLog("Game Center score submission: %@", error.localizedDescription)
                    let retry = DispatchWorkItem { [weak self] in
                        self?.retry = nil
                        guard let self, self.presenter?.view.window?.windowScene?.activationState == .foregroundActive else { return }
                        self.submitPendingScore()
                    }
                    self.retry = retry
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: retry)
                } else {
                    self.scores.confirm(score, for: id)
                    self.submitPendingScore()
                }
            }
        }
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
        if let playerID { refreshBestScore(for: playerID) }
        submitPendingScore()
    }

    private func showError(_ message: String) {
        guard let presenter, presenter.presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Game Center unavailable", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}
