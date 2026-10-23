import UIKit
import CoreHaptics

private enum Squircle {
    static func path(in rect: CGRect, radius: CGFloat) -> UIBezierPath {
        let r = min(radius, min(rect.width, rect.height) / 2)
        let path = UIBezierPath()
        let centers = [CGPoint(x: rect.maxX - r, y: rect.minY + r),
                       CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                       CGPoint(x: rect.minX + r, y: rect.maxY - r),
                       CGPoint(x: rect.minX + r, y: rect.minY + r)]
        for (corner, center) in centers.enumerated() {
            for step in 0...32 {
                let angle = -Double.pi / 2 + Double(corner) * Double.pi / 2 + Double(step) * Double.pi / 64
                func component(_ x: Double) -> CGFloat { CGFloat((x < 0 ? -1 : 1) * sqrt(abs(x))) }
                let point = CGPoint(x: center.x + r * component(cos(angle)), y: center.y + r * component(sin(angle)))
                if corner == 0 && step == 0 { path.move(to: point) }
                else { path.addLine(to: point) }
            }
        }
        path.close()
        return path
    }

    static func apply(to view: UIView, radius: CGFloat) {
        view.layer.cornerRadius = 0
        let mask = (view.layer.mask as? CAShapeLayer) ?? CAShapeLayer()
        mask.frame = view.bounds
        mask.path = path(in: view.bounds, radius: radius).cgPath
        view.layer.mask = mask
    }
}

private struct GameLayout {
    let content: CGRect
    let title: CGRect
    let scores: CGRect
    let board: CGRect
    let privacy: CGRect
    let restart: CGRect
    let appearance: CGRect
    let verticalScores: Bool

    init(in safeArea: CGRect, verticalControls: Bool, controlsOnLeadingEdge: Bool, edgeToEdge: Bool = false, largeControls: Bool = false, horizontalCenter: CGFloat? = nil, compactLandscape: Bool = false) {
        let available = safeArea.insetBy(dx: edgeToEdge ? 8 : min(24, safeArea.width * 0.06), dy: edgeToEdge ? 8 : 12)
        let buttonSide: CGFloat = compactLandscape ? 56 : (largeControls ? 64 : 50)
        if available.width > available.height {
            let columnWidth = compactLandscape ? 96 : min(120, max(96, available.width - available.height - buttonSide - 32))
            let gap: CGFloat = compactLandscape ? 28 : 16
            let railWidth = buttonSide + gap
            let preferredCenter = horizontalCenter ?? available.midX
            let center = preferredCenter > available.minX && preferredCenter < available.maxX ? preferredCenter : available.midX
            let side = max(0, min(available.height,
                                  2 * (center - available.minX - columnWidth - gap),
                                  2 * (available.maxX - center - railWidth)))
            content = CGRect(x: available.minX, y: available.midY - side / 2, width: available.width, height: side)
            board = CGRect(x: center - available.minX - side / 2, y: 0, width: side, height: side)
            let headerY = compactLandscape ? max(0, (side - 208) / 2) : 0
            let columnX = board.minX - gap - columnWidth
            title = CGRect(x: columnX, y: headerY, width: columnWidth, height: 64)
            scores = CGRect(x: columnX, y: headerY + 80, width: columnWidth, height: 128)
            let x = board.maxX + gap
            let spacing = min(buttonSide + gap, (side - buttonSide) / 2)
            let controlsY = compactLandscape ? side / 2 - spacing - buttonSide / 2 : 0
            privacy = CGRect(x: x, y: controlsY, width: buttonSide, height: buttonSide)
            restart = CGRect(x: x, y: controlsY + spacing, width: buttonSide, height: buttonSide)
            appearance = CGRect(x: x, y: controlsY + spacing * 2, width: buttonSide, height: buttonSide)
            verticalScores = true
            return
        }
        verticalScores = false
        let rail = !edgeToEdge && ((verticalControls && available.width >= 230) || available.width > available.height || min(available.width, available.height - 172) < 150)
        let railWidth: CGFloat = rail ? buttonSide + 28 : 0
        let headerHeight: CGFloat = edgeToEdge ? 78 : (largeControls ? 102 : 86)
        let buttonGap: CGFloat = largeControls ? 40 : 28
        let footerHeight: CGFloat = rail ? 0 : buttonSide + buttonGap + (edgeToEdge ? 0 : 8)
        let side = max(0, min(largeControls ? 576 : 600, available.width - railWidth, available.height - headerHeight - footerHeight))
        let width = side + railWidth
        let height = side + headerHeight + footerHeight
        let originY = max(available.minY, min(available.maxY - height, safeArea.midY - height / 2 - 18))
        content = CGRect(x: available.midX - width / 2, y: originY, width: width, height: height)
        let boardX: CGFloat = rail && controlsOnLeadingEdge ? railWidth : 0
        board = CGRect(x: boardX, y: headerHeight, width: side, height: side)
        let scoresWidth = side * 0.51
        title = CGRect(x: boardX, y: 0, width: max(0, side - scoresWidth - 12), height: edgeToEdge ? 50 : 64)
        scores = CGRect(x: board.maxX - scoresWidth, y: edgeToEdge ? 0 : 3, width: scoresWidth, height: edgeToEdge ? 52 : 58)
        if rail {
            let x: CGFloat = controlsOnLeadingEdge ? 0 : board.maxX + 28
            let spacing = min(buttonSide + 28, (height - buttonSide) / 2)
            let centerY = max(spacing + buttonSide / 2, min(board.midY, height - spacing - buttonSide / 2))
            privacy = CGRect(x: x, y: centerY - spacing - buttonSide / 2, width: buttonSide, height: buttonSide)
            restart = CGRect(x: x, y: centerY - buttonSide / 2, width: buttonSide, height: buttonSide)
            appearance = CGRect(x: x, y: centerY + spacing - buttonSide / 2, width: buttonSide, height: buttonSide)
        } else {
            let y = board.maxY + buttonGap
            privacy = CGRect(x: board.minX, y: y, width: buttonSide, height: buttonSide)
            restart = CGRect(x: board.midX - buttonSide / 2, y: y, width: buttonSide, height: buttonSide)
            appearance = CGRect(x: board.maxX - buttonSide, y: y, width: buttonSide, height: buttonSide)
        }
    }

    static func excluding(_ obstruction: CGRect, from area: CGRect) -> [CGRect] {
        let intersection = area.intersection(obstruction)
        guard !intersection.isNull, !intersection.isEmpty else { return [area] }
        let candidates = [
            CGRect(x: area.minX, y: area.minY, width: intersection.minX - area.minX, height: area.height),
            CGRect(x: intersection.maxX, y: area.minY, width: area.maxX - intersection.maxX, height: area.height),
            CGRect(x: area.minX, y: area.minY, width: area.width, height: intersection.minY - area.minY),
            CGRect(x: area.minX, y: intersection.maxY, width: area.width, height: area.maxY - intersection.maxY)
        ]
        return candidates.filter { $0.width >= 160 && $0.height >= 180 }
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
    static func adaptive(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light) }
    }
    static let paper = adaptive(light: 0xFAF8EF, dark: 0x1B1715)
    static let ink = adaptive(light: 0x776E65, dark: 0xF0E2D3)
    static let board = adaptive(light: 0xBBADA0, dark: 0x47382F)
    static let emptyCell = adaptive(light: 0xCDC1B4, dark: 0x302721)
    static let controlFill = adaptive(light: 0xEDE6DA, dark: 0x382C25)
}

final class GameViewController: UIViewController, UIGestureRecognizerDelegate {
    private let store = GameStore()
    private var game: Game
    private lazy var gameCenter = GameCenter(legacyBest: game.best)
    private let content = UIView()
    private let titleLabel = UILabel()
    private var scoresView: UIStackView!
    private var boardGeometry = CGRect.zero
    private var needsOverlayLayout = false
    private var panGesture: UIPanGestureRecognizer?
    private let board = UIView()
    private let scoreLabel = UILabel()
    private let bestLabel = UILabel()
    private let bestButton = UIButton(type: .custom)
    private let restart = UIButton(type: .system)
    private let privacy = UIButton(type: .system)
    private let appearanceButton = UIButton(type: .system)
    private var appearance = AppearanceMode.load()
    private var scoreCards: [UIView] = []
    private var backgrounds: [UIView] = []
    private var tileViews: [UUID: TileView] = [:]
    private var overlay: UIView?
    private var moving = false
    private struct MovePreview {
        let result: Game
        let mergeFeedback: MergeFeedback?
        let animation: BoardAnimation
        let liquids: [LiquidMergeView]
    }
    private var preview: MovePreview?
    private var settling = false
    private var horizontalPan: Bool?
    private var panDirection: Direction?
    private var dragIntent: DragIntent?
    private var pendingDirections: [Direction] = []
    private let slideHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let haptics = GameHaptics()
    private var cutoffFeedback = CutoffFeedbackState()
    private var dragStarted: CFTimeInterval = 0
    private var side: CGFloat { board.bounds.width }
    private var gap: CGFloat { side * 0.028 }
    private var tileSide: CGFloat { (side - gap * 5) / 4 }

    init() { game = store.load(); super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var preferredStatusBarStyle: UIStatusBarStyle { .default }

    override func viewDidLoad() {
        super.viewDidLoad()
        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (controller: GameViewController, _) in
            if #available(iOS 27.1, *) { controller.setNeedsUpdateOfVerticalBarConfiguration() }
        }
        view.backgroundColor = .paper
        view.addSubview(content)
        let title = titleLabel
        title.text = "2048"
        title.font = .systemFont(ofSize: 48, weight: .bold)
        title.textColor = .ink
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.3
        title.accessibilityTraits = .header
        content.addSubview(title)
        let bestCard = scoreCard("BEST", value: bestLabel)
        bestCard.isUserInteractionEnabled = false
        bestButton.addSubview(bestCard)
        bestCard.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bestCard.leadingAnchor.constraint(equalTo: bestButton.leadingAnchor),
            bestCard.trailingAnchor.constraint(equalTo: bestButton.trailingAnchor),
            bestCard.topAnchor.constraint(equalTo: bestButton.topAnchor),
            bestCard.bottomAnchor.constraint(equalTo: bestButton.bottomAnchor)
        ])
        bestButton.accessibilityHint = "Opens the Game Center leaderboard"
        bestButton.addTarget(self, action: #selector(showGameCenter), for: .touchUpInside)
        let scores = UIStackView(arrangedSubviews: [scoreCard("SCORE", value: scoreLabel), bestButton])
        scoresView = scores
        scores.spacing = 8
        scores.distribution = .fillEqually
        content.addSubview(scores)
        scores.translatesAutoresizingMaskIntoConstraints = true
        board.backgroundColor = .board
        board.layer.cornerRadius = 12
        board.clipsToBounds = true
        content.addSubview(board)
        for _ in 0..<16 {
            let cell = UIView()
            cell.backgroundColor = .emptyCell
            cell.layer.cornerRadius = 6
            board.addSubview(cell)
            backgrounds.append(cell)
        }
        restart.setImage(UIImage(systemName: "arrow.counterclockwise", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)), for: .normal)
        restart.tintColor = .ink
        restart.backgroundColor = .controlFill
        restart.layer.cornerRadius = 25
        restart.accessibilityLabel = "Restart game"
        restart.addTarget(self, action: #selector(confirmRestart), for: .touchUpInside)
        content.addSubview(restart)
        privacy.setImage(UIImage(systemName: "info.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)), for: .normal)
        privacy.tintColor = .ink
        privacy.backgroundColor = .controlFill
        privacy.layer.cornerRadius = 25
        privacy.accessibilityLabel = "Privacy & Support"
        privacy.addTarget(self, action: #selector(showPrivacy), for: .touchUpInside)
        content.addSubview(privacy)
        appearanceButton.tintColor = .ink
        appearanceButton.backgroundColor = .controlFill
        appearanceButton.layer.cornerRadius = 25
        appearanceButton.accessibilityLabel = "Appearance"
        appearanceButton.accessibilityHint = "Cycles between system, dark and light appearance"
        appearanceButton.addTarget(self, action: #selector(cycleAppearance), for: .touchUpInside)
        content.addSubview(appearanceButton)
        updateAppearanceButton()
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        panGesture = pan
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        view.addGestureRecognizer(pan)
        for (name, direction) in [("Swipe left", Direction.left), ("Swipe right", .right), ("Swipe up", .up), ("Swipe down", .down)] {
            board.accessibilityCustomActions = (board.accessibilityCustomActions ?? []) + [UIAccessibilityCustomAction(name: name) { [weak self] _ in self?.move(direction); return true }]
        }
        board.isAccessibilityElement = true
        NotificationCenter.default.addObserver(self, selector: #selector(sceneEnteredBackground(_:)), name: UIScene.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillDeactivate(_:)), name: UIScene.willDeactivateNotification, object: nil)
        gameCenter.onBestScoreChanged = { [weak self] best in self?.updateBestScore(best) }
        render()
        save()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        haptics.prepare()
        gameCenter.start(presenting: self)
    }

    @objc private func showGameCenter() {
        interrupted()
        gameCenter.showDashboard(from: self)
    }

    @objc private func cycleAppearance() {
        let systemIsDark = view.window?.windowScene?.traitCollection.userInterfaceStyle == .dark
        appearance = appearance.next(systemIsDark: systemIsDark)
        appearance.save()
        view.window?.overrideUserInterfaceStyle = appearance.interfaceStyle
        updateAppearanceButton()
        setNeedsStatusBarAppearanceUpdate()
    }

    private func updateAppearanceButton() {
        appearanceButton.setImage(UIImage(systemName: appearance.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)), for: .normal)
        appearanceButton.accessibilityValue = appearance.title
    }

    private func updateBestScore(_ best: Int) {
        bestLabel.text = String(best)
        bestButton.accessibilityLabel = "Best score, \(best)"
    }

    @available(iOS 27.1, *)
    override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
        traitCollection.horizontalSizeClass == .compact ? .disabled : .automatic
    }

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if #available(iOS 27.1, *), preferredVerticalBarBehavior == .disabled {
            definesPresentationContext = true
            viewControllerToPresent.modalPresentationStyle = .overCurrentContext
        }
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateRestartPresentation()
        var verticalControls = false
        var controlsOnLeadingEdge = false
        var edgeToEdge = false
        if #available(iOS 27.1, *) {
            let edge = traitCollection.verticalBarEdge
            verticalControls = edge != .unspecified
            edgeToEdge = traitCollection.horizontalSizeClass == .compact && view.bounds.width <= view.bounds.height
            controlsOnLeadingEdge = (edge == .leading && view.effectiveUserInterfaceLayoutDirection == .leftToRight) ||
                (edge == .trailing && view.effectiveUserInterfaceLayoutDirection == .rightToLeft)
        }
        let landscape = view.bounds.width > view.bounds.height
        let compactLandscape = landscape && traitCollection.horizontalSizeClass == .compact
        let largeControls = traitCollection.horizontalSizeClass == .regular || landscape
        var safeInsets = view.safeAreaInsets
        if landscape {
            let verticalInset = compactLandscape ? min(safeInsets.bottom, 24) : max(safeInsets.top, safeInsets.bottom)
            safeInsets.top = verticalInset
            safeInsets.bottom = verticalInset
        }
        var regions = [view.bounds.inset(by: safeInsets)]
        if #available(iOS 27.1, *) {
            for reserved in view.reservedRegions(kind: .division) {
                regions = regions.flatMap { GameLayout.excluding(reserved.frame, from: $0) }
            }
            for reserved in view.reservedRegions(kind: .occlusion) {
                regions = regions.flatMap { region in
                    if compactLandscape {
                        let layout = GameLayout(in: region, verticalControls: verticalControls,
                                                controlsOnLeadingEdge: controlsOnLeadingEdge, largeControls: largeControls,
                                                horizontalCenter: view.bounds.midX, compactLandscape: true)
                        let frames = [layout.board, layout.title, layout.scores, layout.privacy, layout.restart, layout.appearance]
                        if !frames.contains(where: { $0.offsetBy(dx: layout.content.minX, dy: layout.content.minY).intersects(reserved.frame) }) {
                            return [region]
                        }
                    }
                    return GameLayout.excluding(reserved.frame, from: region)
                }
            }
        }
        let layouts = regions.map {
            GameLayout(in: $0, verticalControls: verticalControls, controlsOnLeadingEdge: controlsOnLeadingEdge,
                       edgeToEdge: edgeToEdge, largeControls: largeControls, horizontalCenter: view.bounds.midX,
                       compactLandscape: compactLandscape)
        }
        guard let layout = layouts.filter({ $0.board.width >= 160 }).max(by: { $0.board.width < $1.board.width }), layout.board.width > 0 else {
            stopInteractionForResize()
            content.isHidden = true
            return
        }
        content.isHidden = false
        let nextGeometry = layout.board.offsetBy(dx: layout.content.minX, dy: layout.content.minY)
        if boardGeometry != nextGeometry {
            stopInteractionForResize()
            boardGeometry = nextGeometry
            needsOverlayLayout = true
        }
        content.frame = layout.content
        titleLabel.frame = layout.title
        scoresView.axis = layout.verticalScores ? .vertical : .horizontal
        scoresView.frame = layout.scores
        board.frame = layout.board
        privacy.frame = layout.privacy
        restart.frame = layout.restart
        appearanceButton.frame = layout.appearance
        let symbolSize: CGFloat = compactLandscape ? 24 : (largeControls ? 28 : 22)
        for (button, symbol) in [(privacy, "info.circle"), (restart, "arrow.counterclockwise"), (appearanceButton, appearance.symbol)] {
            button.layer.cornerRadius = button.bounds.width / 2
            button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)), for: .normal)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        stopInteractionForResize()
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.view.setNeedsLayout()
            self?.view.layoutIfNeeded()
        })
    }

    private func stopInteractionForResize() {
        pendingDirections.removeAll()
        if let panGesture, panGesture.state == .began || panGesture.state == .changed {
            panGesture.isEnabled = false
            panGesture.isEnabled = true
        }
        interrupted()
    }

    @objc private func sceneWillDeactivate(_ notification: Notification) {
        guard notification.object as? UIScene === view.window?.windowScene else { return }
        pendingDirections.removeAll()
        interrupted()
    }

    @objc private func sceneEnteredBackground(_ notification: Notification) {
        guard notification.object as? UIScene === view.window?.windowScene else { return }
        save()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scoresView.layoutIfNeeded()
        bestButton.layoutIfNeeded()
        for (index, cell) in backgrounds.enumerated() { cell.frame = frame(for: index) }
        Squircle.apply(to: board, radius: 28)
        backgrounds.forEach { Squircle.apply(to: $0, radius: tileSide * 0.24) }
        scoreCards.forEach { Squircle.apply(to: $0, radius: 17) }
        if !moving {
            for tile in game.tiles {
                position(tileViews[tile.id], at: tile.cell)
                tileViews[tile.id]?.resize(to: tileSide)
            }
        }
        if needsOverlayLayout {
            needsOverlayLayout = false
            if overlay != nil { updateOverlay(animated: false) }
        }
        overlay?.frame = board.bounds
    }

    private func scoreCard(_ title: String, value: UILabel) -> UIView {
        let label = UILabel()
        label.text = title
        label.textColor = UIColor(hex: 0xEEE4DA)
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        value.font = .monospacedDigitSystemFont(ofSize: 21, weight: .bold)
        value.textColor = .white
        value.textAlignment = .center
        value.adjustsFontSizeToFitWidth = true
        value.minimumScaleFactor = 0.45
        let stack = UIStackView(arrangedSubviews: [label, value])
        stack.axis = .vertical
        stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 6, bottom: 7, right: 6)
        stack.backgroundColor = .board
        stack.layer.cornerRadius = 8
        scoreCards.append(stack)
        return stack
    }

    private func frame(for cell: Int) -> CGRect {
        CGRect(x: gap + CGFloat(cell % 4) * (tileSide + gap), y: gap + CGFloat(cell / 4) * (tileSide + gap), width: tileSide, height: tileSide)
    }

    private func position(_ tile: TileView?, at cell: Int) {
        let target = frame(for: cell)
        tile?.bounds = CGRect(origin: .zero, size: target.size)
        tile?.center = CGPoint(x: target.midX, y: target.midY)
    }

    private func render(spawned: Set<UUID> = []) {
        let ids = Set(game.tiles.map(\.id))
        for id in Array(tileViews.keys) where !ids.contains(id) {
            tileViews.removeValue(forKey: id)?.removeFromSuperview()
        }
        for tile in game.tiles {
            let cell = tileViews[tile.id] ?? TileView()
            if tileViews[tile.id] == nil { board.addSubview(cell); tileViews[tile.id] = cell }
            position(cell, at: tile.cell)
            cell.isHidden = false
            cell.update(value: tile.value, size: tileSide)
            if spawned.contains(tile.id) { cell.appear() }
        }
        scoreLabel.text = String(game.score)
        scoreLabel.accessibilityLabel = "Score, \(game.score)"
        updateBestScore(gameCenter.best)
        board.accessibilityLabel = "Game board. " + (0..<4).map { row in "Row \(row + 1): " + game.values[(row*4)..<(row*4+4)].map { $0 == 0 ? "empty" : String($0) }.joined(separator: ", ") }.joined(separator: ". ")
        updateOverlay()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard !content.isHidden, overlay == nil, presentedViewController == nil else { return false }
        var target = touch.view
        while let current = target {
            if current is UIControl { return false }
            target = current.superview
        }
        return true
    }

    @objc private func panned(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            beginDrag()
            updateDrag(translation: pan.translation(in: view), velocity: pan.velocity(in: view))
        case .changed:
            updateDrag(translation: pan.translation(in: view), velocity: pan.velocity(in: view))
        case .ended:
            updateDrag(translation: pan.translation(in: view), velocity: pan.velocity(in: view), allowCutoffEntry: false)
            endDrag(velocity: pan.velocity(in: view))
        case .cancelled, .failed:
            endDrag(velocity: .zero, cancelled: true)
        default: break
        }
    }

    private func beginDrag() {
        if settling { preview?.animation.finishImmediately() }
        pendingDirections.removeAll()
        horizontalPan = nil
        panDirection = nil
        dragIntent = nil
        cutoffFeedback = CutoffFeedbackState()
        dragStarted = CACurrentMediaTime()
        haptics.prepare()
    }

    private func updateDrag(translation: CGPoint, velocity: CGPoint = .zero, allowCutoffEntry: Bool = true) {
        guard overlay == nil, !settling else { return }
        if horizontalPan == nil {
            guard max(abs(translation.x), abs(translation.y)) >= 4 else { return }
            horizontalPan = abs(translation.x) >= abs(translation.y)
        }
        let horizontal = horizontalPan == true
        let amount = horizontal ? translation.x : translation.y
        let direction: Direction = horizontal ? (amount < 0 ? .left : .right) : (amount < 0 ? .up : .down)
        if panDirection != direction {
            if cutoffFeedback.isOn { haptics.cutoff(.exited) }
            cutoffFeedback = CutoffFeedbackState()
            discardPreview()
            panDirection = direction
            dragIntent = DragIntent(threshold: Double(tileSide * 0.62))
        }
        if preview == nil { makePreview(direction) }
        guard let preview else { return }
        let distance = abs(amount)
        preview.animation.seek(distance: distance)
        _ = dragIntent?.update(distance: Double(distance))
        let speed = horizontal ? velocity.x : velocity.y
        if let cue = cutoffFeedback.update(distance: Double(distance), threshold: Double(tileSide * 0.62),
                                           speed: Double(speed), elapsed: CACurrentMediaTime() - dragStarted,
                                           allowEntry: allowCutoffEntry) {
            haptics.cutoff(cue)
        }
    }

    private func endDrag(velocity: CGPoint, cancelled: Bool = false) {
        let signedVelocity: CGFloat
        switch panDirection {
        case .left: signedVelocity = -velocity.x
        case .right: signedVelocity = velocity.x
        case .up: signedVelocity = -velocity.y
        case .down: signedVelocity = velocity.y
        case nil: signedVelocity = 0
        }
        if !cancelled, let intent = dragIntent, intent.shouldCommit(velocity: Double(signedVelocity)) {
            commitPreview()
        } else {
            if cutoffFeedback.isOn { haptics.cutoff(.exited) }
            cancelPreview()
        }
        cutoffFeedback = CutoffFeedbackState()
        horizontalPan = nil
        panDirection = nil
        dragIntent = nil
    }

    private func move(_ direction: Direction) {
        guard overlay == nil else { return }
        if moving {
            if pendingDirections.count < 2 { pendingDirections.append(direction) }
            return
        }
        makePreview(direction)
        commitPreview()
    }

    private func makePreview(_ direction: Direction) {
        guard preview == nil, overlay == nil else { return }
        var result = game
        guard let turn = result.move(direction, spawnTile: false) else { return }
        moving = true
        let groups = Dictionary(grouping: turn.motions, by: \.destination)
        var liquids: [LiquidMergeView] = []
        for (destination, motions) in groups where motions.count == 2 {
            guard let resultTile = result.tiles.first(where: { $0.cell == destination }),
                  let first = tileViews[motions[0].id], let second = tileViews[motions[1].id] else { continue }
            let liquid = LiquidMergeView(first: first.center, second: second.center,
                                         destination: CGPoint(x: frame(for: destination).midX, y: frame(for: destination).midY),
                                         value: resultTile.value, side: tileSide, direction: direction)
            liquid.frame = board.bounds
            board.addSubview(liquid)
            first.isHidden = true
            second.isHidden = true
            liquids.append(liquid)
        }
        let motions = turn.motions.compactMap { motion -> BoardAnimation.Motion? in
            guard let tile = tileViews[motion.id] else { return nil }
            let target = frame(for: motion.destination)
            return BoardAnimation.Motion(view: tile, start: tile.center, end: CGPoint(x: target.midX, y: target.midY))
        }
        preview = MovePreview(result: result, mergeFeedback: turn.mergeFeedback, animation: BoardAnimation(motions: motions, merges: liquids), liquids: liquids)
    }

    private func commitPreview() {
        guard let preview, !settling else { return }
        game = preview.result
        let spawned = game.spawn()
        save()
        gameCenter.record(score: game.score)
        haptics.prepare()
        let remaining = preview.animation.maximumDistance - preview.animation.distance
        let duration = remaining < 0.5 ? 0 : 0.06 + 0.06 * min(1, remaining / (tileSide + gap))
        settle(to: preview.animation.maximumDistance, duration: duration) { [weak self] in
            guard let self else { return }
            if let feedback = preview.mergeFeedback { self.haptics.merged(feedback) }
            self.discardPreview(spawned: Set([spawned].compactMap { $0 }))
            self.consumeNextSwipe()
        }
    }

    private func cancelPreview(animated: Bool = true) {
        guard let preview, !settling else { return }
        let duration = animated ? 0.06 + 0.07 * min(1, preview.animation.distance / (tileSide + gap)) : 0
        settle(to: 0, duration: duration) { [weak self] in
            self?.discardPreview()
            self?.consumeNextSwipe()
        }
    }

    private func settle(to distance: CGFloat, duration: TimeInterval, completion: @escaping () -> Void) {
        settling = true
        preview?.animation.animate(to: distance, duration: UIAccessibility.isReduceMotionEnabled ? 0 : duration,
                                   maximumFramesPerSecond: view.window?.windowScene?.screen.maximumFramesPerSecond ?? 60,
                                   completion: completion)
    }

    private func discardPreview(spawned: Set<UUID> = []) {
        for liquid in preview?.liquids ?? [] { liquid.removeFromSuperview() }
        preview = nil
        moving = false
        settling = false
        render(spawned: spawned)
    }

    @objc private func interrupted() {
        cutoffFeedback = CutoffFeedbackState()
        if settling { preview?.animation.finishImmediately() }
        else { cancelPreview(animated: false) }
        horizontalPan = nil
        panDirection = nil
        dragIntent = nil
    }

    private func consumeNextSwipe() {
        while !moving && !pendingDirections.isEmpty {
            let next = pendingDirections.removeFirst()
            move(next)
        }
    }

    private func updateOverlay(animated: Bool = true) {
        overlay?.removeFromSuperview(); overlay = nil
        board.isAccessibilityElement = true
        guard game.needsWinPrompt || game.isOver else { return }
        board.isAccessibilityElement = false
        let panel = UIView(frame: board.bounds)
        panel.accessibilityViewIsModal = true
        panel.backgroundColor = .paper.withAlphaComponent(0.94)
        board.addSubview(panel)
        overlay = panel
        let title = UILabel()
        title.text = game.needsWinPrompt ? "2048!" : "Game over"
        title.font = .systemFont(ofSize: min(38, board.bounds.width / 6), weight: .bold)
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.5
        title.textColor = .ink
        title.textAlignment = .center
        let action = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = game.needsWinPrompt ? "Keep going" : "Try again"
        config.baseBackgroundColor = UIColor(hex: 0x8F7A66)
        config.baseForegroundColor = UIColor(hex: 0xF9F6F2)
        config.cornerStyle = .medium
        let padding = min(24, board.bounds.width * 0.08)
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: padding, bottom: 14, trailing: padding)
        action.configuration = config
        action.addTarget(self, action: #selector(outcomeAction), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, action])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        panel.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: panel.widthAnchor, constant: -16)
        ])
        if animated && !UIAccessibility.isReduceMotionEnabled {
            panel.alpha = 0
            UIView.animate(withDuration: 0.22, delay: 0.14, options: [.allowUserInteraction, .curveEaseOut]) { panel.alpha = 1 }
        }
        if animated { UIAccessibility.post(notification: .screenChanged, argument: title) }
    }
    @objc private func outcomeAction() {
        if game.needsWinPrompt { game.continued = true; save(); render() }
        else { newGame() }
    }
    private func updateRestartPresentation() {
        var useMenu = false
        if #available(iOS 27.1, *) { useMenu = preferredVerticalBarBehavior == .disabled }
        guard restart.showsMenuAsPrimaryAction != useMenu else { return }
        restart.showsMenuAsPrimaryAction = useMenu
        if useMenu {
            restart.removeTarget(self, action: #selector(confirmRestart), for: .touchUpInside)
            restart.menu = UIMenu(title: "Restart game?", children: [
                UIAction(title: "Restart", attributes: .destructive) { [weak self] _ in
                    guard let self, !self.moving else { return }
                    self.newGame()
                },
                UIAction(title: "Cancel") { _ in }
            ])
        } else {
            restart.menu = nil
            restart.addTarget(self, action: #selector(confirmRestart), for: .touchUpInside)
        }
    }

    @objc private func confirmRestart() {
        guard !moving else { return }
        let alert = UIAlertController(title: "Restart game?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Restart", style: .destructive) { [weak self] _ in self?.newGame() })
        present(alert, animated: true)
    }
    @objc private func showPrivacy() {
        interrupted()
        present(UINavigationController(rootViewController: PrivacyViewController()), animated: true)
    }
    private func newGame() {
        pendingDirections.removeAll()
        game = Game(best: game.best)
        save()
        slideHaptic.impactOccurred(intensity: 0.6)
        render(spawned: Set(game.tiles.map(\.id)))
    }
    @objc private func save() { store.save(game) }
}

private final class PrivacyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        let text = UITextView()
        text.backgroundColor = .paper
        text.isEditable = false
        text.dataDetectorTypes = []
        text.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 24, right: 20)
        text.adjustsFontForContentSizeCategory = true
        if let url = Bundle.main.url(forResource: "Privacy", withExtension: "html"),
           let data = try? Data(contentsOf: url),
           let policy = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            let styled = NSMutableAttributedString(attributedString: policy)
            let range = NSRange(location: 0, length: styled.length)
            styled.addAttribute(.foregroundColor, value: UIColor.ink, range: range)
            styled.removeAttribute(.backgroundColor, range: range)
            text.attributedText = styled
        }
        text.linkTextAttributes = [.foregroundColor: UIColor.adaptive(light: 0x76592E, dark: 0xE6BB7D)]
        view.addSubview(text)
        text.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            text.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            text.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            text.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}


private final class TileView: UIView {
    private let number = UILabel()
    private var value = 0
    private static let palette: [Int: UInt32] = [
        2: 0xEEE4DA, 4: 0xEDE0C8, 8: 0xF2B179, 16: 0xF59563,
        32: 0xF67C5F, 64: 0xF65E3B, 128: 0xEDCF72, 256: 0xEDCC61,
        512: 0xEDC850, 1024: 0xEDC53F, 2048: 0xEDC22E
    ]

    private static let darkPalette: [Int: UInt32] = [
        2: 0x4C453D, 4: 0x605240, 8: 0xCE9667, 16: 0xD07F54,
        32: 0xD16951, 64: 0xD15032, 128: 0xC9B061, 256: 0xC9AD52,
        512: 0xC9AA44, 1024: 0xC9A736, 2048: 0xC9A527
    ]

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        number.isAccessibilityElement = false
        number.textAlignment = .center
        number.adjustsFontSizeToFitWidth = true
        number.minimumScaleFactor = 0.35
        addSubview(number)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        number.frame = bounds
        Squircle.apply(to: self, radius: bounds.width * 0.24)
    }

    func resize(to side: CGFloat) {
        number.font = Self.font(for: value, side: side)
        number.frame = bounds
    }

    static func fill(for value: Int) -> UIColor {
        .adaptive(light: palette[value] ?? 0x3C3A32, dark: darkPalette[value] ?? 0x211D19)
    }
    static func ink(for value: Int) -> UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle != .dark { return UIColor(hex: value <= 4 ? 0x776E65 : 0xF9F6F2) }
            return .white
        }
    }
    static func font(for value: Int, side: CGFloat) -> UIFont {
        .systemFont(ofSize: max(1, side * (value < 128 ? 0.48 : value < 1024 ? 0.40 : 0.31)), weight: .bold)
    }

    func update(value: Int, size: CGFloat) {
        self.value = value
        number.text = String(value)
        number.textColor = Self.ink(for: value)
        resize(to: size)
        backgroundColor = Self.fill(for: value)
    }

    func appear() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.82, 1.015, 1]
        scale.keyTimes = [0, 0.72, 1]
        scale.duration = 0.10
        scale.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .easeInEaseOut)]
        layer.add(scale, forKey: "appearanceScale")
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.06
        layer.add(fade, forKey: "appearanceFade")
    }
}


private final class BoardAnimation: NSObject {
    struct Motion { let view: UIView; let start: CGPoint; let end: CGPoint }
    private let motions: [Motion]
    private let merges: [LiquidMergeView]
    let maximumDistance: CGFloat
    private(set) var distance: CGFloat = 0
    private var link: CADisplayLink?
    private var started: CFTimeInterval = 0
    private var duration: TimeInterval = 0
    private var startDistance: CGFloat = 0
    private var targetDistance: CGFloat = 0
    private var completion: (() -> Void)?

    init(motions: [Motion], merges: [LiquidMergeView]) {
        self.motions = motions; self.merges = merges
        maximumDistance = motions.map { hypot($0.end.x - $0.start.x, $0.end.y - $0.start.y) }.max() ?? 0
    }

    func seek(distance: CGFloat) {
        self.distance = min(maximumDistance, max(0, distance))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for motion in motions {
            let length = hypot(motion.end.x - motion.start.x, motion.end.y - motion.start.y)
            let fraction = length > 0 ? min(1, self.distance / length) : 1
            motion.view.center = CGPoint(x: motion.start.x + (motion.end.x - motion.start.x) * fraction,
                                         y: motion.start.y + (motion.end.y - motion.start.y) * fraction)
        }
        for merge in merges { merge.update(distance: self.distance) }
        CATransaction.commit()
    }

    func animate(to target: CGFloat, duration: TimeInterval, maximumFramesPerSecond: Int, completion: @escaping () -> Void) {
        self.completion = completion
        self.duration = duration
        startDistance = distance
        targetDistance = target
        started = CACurrentMediaTime()
        guard duration > 0, abs(target - distance) > 0.1 else { finishImmediately(); return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: Float(min(60, maximumFramesPerSecond)), maximum: Float(maximumFramesPerSecond), preferred: Float(maximumFramesPerSecond))
        self.link = link
        link.add(to: .main, forMode: .common)
    }

    @objc private func tick(_ link: CADisplayLink) {
        let progress = min(1, max(0, (link.targetTimestamp - started) / duration))
        let eased = CGFloat(1 - pow(1 - progress, 3))
        seek(distance: startDistance + (targetDistance - startDistance) * eased)
        if progress >= 1 { finishImmediately() }
    }

    func finishImmediately() {
        link?.invalidate()
        link = nil
        seek(distance: targetDistance)
        let done = completion
        completion = nil
        done?()
    }
}

private final class LiquidMergeView: UIView {
    private let surface = CAShapeLayer()
    private let highlight = CAShapeLayer()
    private let firstNumber = UILabel()
    private let secondNumber = UILabel()
    private let resultNumber = UILabel()
    private let first: CGPoint
    private let second: CGPoint
    private let destination: CGPoint
    private let side: CGFloat
    private let horizontal: Bool
    private let oldColour: UIColor
    private let newColour: UIColor

    init(first: CGPoint, second: CGPoint, destination: CGPoint, value: Int, side: CGFloat, direction: Direction) {
        self.first = first; self.second = second; self.destination = destination; self.side = side
        horizontal = direction == .left || direction == .right
        oldColour = TileView.fill(for: value / 2)
        newColour = TileView.fill(for: value)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.addSublayer(surface)
        highlight.fillColor = UIColor.clear.cgColor
        highlight.lineWidth = 0.65
        layer.addSublayer(highlight)
        for (label, number) in [(firstNumber, value / 2), (secondNumber, value / 2), (resultNumber, value)] {
            label.text = String(number)
            label.font = TileView.font(for: number, side: side)
            label.textColor = TileView.ink(for: number)
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.35
            label.isAccessibilityElement = false
            addSubview(label)
        }
        resultNumber.alpha = 0
        _ = update(distance: 0)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @discardableResult func update(distance fingerDistance: CGFloat) -> Bool {
        func point(_ start: CGPoint) -> CGPoint {
            let length = hypot(destination.x - start.x, destination.y - start.y)
            let fraction = length > 0 ? min(1, fingerDistance / length) : 1
            return CGPoint(x: start.x + (destination.x - start.x) * fraction, y: start.y + (destination.y - start.y) * fraction)
        }
        let a = point(first), b = point(second)
        let distance = horizontal ? abs(a.x - b.x) : abs(a.y - b.y)
        let geometry = MagneticMergeGeometry(side: Double(side), separation: Double(distance), movement: Double(fingerDistance))
        let melt = CGFloat(geometry.fusion)
        let blend = smooth(min(1, max(0, (melt - 0.08) / 0.55)))
        let outgoing = 1 - smooth(min(1, melt / 0.32))
        firstNumber.alpha = outgoing
        secondNumber.alpha = outgoing
        resultNumber.alpha = smooth(min(1, max(0, (melt - 0.18) / 0.28)))
        for (label, center) in [(firstNumber, a), (secondNumber, b), (resultNumber, CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))] {
            label.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            label.center = center
        }
        let path: UIBezierPath
        if geometry.attraction < 0.000001 {
            path = UIBezierPath()
            for center in [a, b] {
                path.append(Squircle.path(in: CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side), radius: side * 0.24))
            }
        } else {
            let axisA = horizontal ? a.x : a.y
            let axisB = horizontal ? b.x : b.y
            let cross = horizontal ? a.y : a.x
            path = magneticContour(geometry, middle: (axisA + axisB) / 2, cross: cross)
            if !horizontal { path.apply(CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)) }
        }
        surface.path = path.cgPath
        surface.fillColor = colour(from: oldColour, to: newColour, amount: blend).cgColor
        highlight.path = path.cgPath
        highlight.strokeColor = UIColor.white.withAlphaComponent(0.14 * CGFloat(geometry.attraction)).cgColor
        return melt > 0.02
    }

    private func magneticContour(_ geometry: MagneticMergeGeometry, middle: CGFloat, cross: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let low = -geometry.separation / 2 - geometry.halfSide
        let high = geometry.separation / 2 + geometry.halfSide
        let count = max(2, Int(ceil((high - low) / 0.85)))
        var upper: [CGPoint] = []
        var lower: [CGPoint] = []
        func closeComponent() {
            guard let first = upper.first else { return }
            path.move(to: first)
            appendSmooth(upper, to: path)
            let bottom = Array(lower.reversed())
            path.addLine(to: bottom[0])
            appendSmooth(bottom, to: path)
            path.close()
            upper.removeAll(keepingCapacity: true)
            lower.removeAll(keepingCapacity: true)
        }
        for index in 0...count {
            let x = low + (high - low) * Double(index) / Double(count)
            if let height = geometry.halfHeight(at: x) {
                upper.append(CGPoint(x: middle + CGFloat(x), y: cross - CGFloat(height)))
                lower.append(CGPoint(x: middle + CGFloat(x), y: cross + CGFloat(height)))
            } else {
                closeComponent()
            }
        }
        closeComponent()
        return path
    }

    private func appendSmooth(_ points: [CGPoint], to path: UIBezierPath) {
        guard points.count > 1 else { return }
        func slope(_ index: Int) -> CGFloat {
            let before = points[max(0, index - 1)]
            let after = points[min(points.count - 1, index + 1)]
            return (after.y - before.y) / (after.x - before.x)
        }
        for index in 1..<points.count {
            let a = points[index - 1], b = points[index]
            let dx = b.x - a.x
            let delta = (b.y - a.y) / dx
            func limited(_ value: CGFloat) -> CGFloat {
                guard value * delta > 0 else { return 0 }
                return (delta > 0 ? 1 : -1) * min(abs(value), 3 * abs(delta))
            }
            path.addCurve(to: b,
                          controlPoint1: CGPoint(x: a.x + dx / 3, y: a.y + limited(slope(index - 1)) * dx / 3),
                          controlPoint2: CGPoint(x: b.x - dx / 3, y: b.y - limited(slope(index)) * dx / 3))
        }
    }
    private func smooth(_ x: CGFloat) -> CGFloat { x * x * (3 - 2 * x) }
    private func colour(from: UIColor, to: UIColor, amount: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        from.resolvedColor(with: traitCollection).getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        to.resolvedColor(with: traitCollection).getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(red: ar + (br - ar) * amount, green: ag + (bg - ag) * amount, blue: ab + (bb - ab) * amount, alpha: 1)
    }
}


private final class GameHaptics {
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    private let cutoffOn = UIImpactFeedbackGenerator(style: .light)
    private let cutoffOff = UIImpactFeedbackGenerator(style: .soft)
    private let mergeFallback = UIImpactFeedbackGenerator(style: .rigid)

    func prepare() {
        cutoffOn.prepare()
        cutoffOff.prepare()
        if !startEngine() { mergeFallback.prepare() }
    }

    func cutoff(_ cue: CutoffCue) {
        switch cue {
        case .entered:
            cutoffOn.impactOccurred(intensity: 0.45)
            cutoffOff.prepare()
        case .exited:
            cutoffOff.impactOccurred(intensity: 0.30)
            cutoffOn.prepare()
        }
    }

    func merged(_ feedback: MergeFeedback) {
        if !transient(intensity: feedback.intensity, sharpness: feedback.sharpness) {
            mergeFallback.impactOccurred(intensity: CGFloat(feedback.intensity))
        }
    }

    private func startEngine() -> Bool {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }
        do {
            if engine == nil {
                let engine = try CHHapticEngine()
                engine.playsHapticsOnly = true
                engine.isAutoShutdownEnabled = true
                self.engine = engine
            }
            try engine?.start()
            return true
        } catch { return false }
    }

    private func transient(intensity: Float, sharpness: Float) -> Bool {
        guard startEngine(), let engine else { return false }
        do {
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            player = try engine.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
            return true
        } catch { return false }
    }
}
