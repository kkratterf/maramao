import AppKit
import SpriteKit

/// An SKView that reacts to the very first click, even though its window never becomes key.
final class CatPileSKView: SKView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The physics scene: cats fall from above the top edge and pile up until the screen is buried.
/// With Reduce Motion (`calm`) there is no physics at all: cats fade in already stacked,
/// row by row from the bottom, and fade out at the end.
final class CatPileScene: SKScene {
    private struct CatSprite {
        let texture: SKTexture
        let aspect: CGFloat
    }

    private static let catName = "cat"
    private static let catSpriteName = "catSprite"
    private static let meows = [String(localized: "Miao!"), String(localized: "Mrrp!"), String(localized: "Prrr"), String(localized: "MIAAAO"), String(localized: "Miao?"), String(localized: "Mrrrao!")]

    /// Most cats on one screen, for performance.
    private static let maxCats = 250
    /// Frame rate while cats fall or jump, and once the full pile has settled. A buried
    /// screen barely moves, so it does not need to be redrawn 60 times a second.
    private static let activeFPS = 60
    private static let restingFPS = 30

    private let sprites: [CatSprite]
    private let fillTime: TimeInterval
    /// Size factor: 1 on a laptop screen, larger on big displays.
    private let sizeFactor: CGFloat
    /// How many cats should roughly bury the screen.
    private let targetCount: Int

    private let walls = SKNode()
    private let tint = SKSpriteNode(color: .black, size: .zero)
    private var cats: [SKNode] = []

    private var startTime: TimeInterval?
    private var lastSpawn: TimeInterval = 0
    private var lastScan: TimeInterval = 0
    private var nextAutoMeow: TimeInterval = 4
    private var dimStep = 0
    private var pileIsFull = false
    /// Until when to stay at full frame rate after a click on a cat.
    private var activeUntil: TimeInterval = 0
    private var isScattering = false

    private let calm: Bool
    /// Calm stacking: where the next cat goes in the current row.
    private var calmX: CGFloat = 0
    private var calmRowBase: CGFloat = 0
    private var calmRowHeight: CGFloat = 0

    init(size: CGSize, artworks: [CatPileArtwork], fillTime: TimeInterval, calm: Bool = false) {
        self.calm = calm
        sprites = artworks.map { CatSprite(texture: SKTexture(cgImage: $0.image), aspect: $0.aspect) }
        self.fillTime = max(5, fillTime)

        let referenceArea: CGFloat = 1440 * 900
        let area = max(1, size.width * size.height)
        let factor = min(1.6, max(1, sqrt(area / referenceArea)))
        sizeFactor = factor

        // Average physics body area: cats average ~110 pt on their long side, about
        // 0.7 as tall, and the body covers ~0.85 × 0.82 of the sprite.
        let averageLong = 110 * factor
        let averageBodyArea = averageLong * averageLong * 0.7 * 0.85 * 0.82
        let estimate = Int((area / averageBodyArea * 1.3).rounded(.up))
        targetCount = min(Self.maxCats, max(20, estimate))

        super.init(size: size)

        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        physicsWorld.gravity = CGVector(dx: 0, dy: -11)

        // A barely visible tint, so the window catches clicks everywhere from the start.
        tint.anchorPoint = .zero
        tint.size = size
        tint.position = .zero
        tint.alpha = 0.03
        tint.zPosition = -10
        addChild(tint)

        // Left wall, floor and right wall. The walls go far above the top edge so cats
        // spawned near the sides stay in.
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size.height * 4))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: size.height * 4))
        let wallBody = SKPhysicsBody(edgeChainFrom: path)
        wallBody.friction = 0.9
        wallBody.restitution = 0.2
        walls.physicsBody = wallBody
        addChild(walls)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        if startTime == nil {
            startTime = currentTime
        }
        let elapsed = currentTime - (startTime ?? currentTime)

        if isScattering {
            removeFallenCats()
            return
        }

        spawnIfNeeded(elapsed: elapsed)

        if elapsed - lastScan > 0.5 {
            lastScan = elapsed
            scanPile()
        }

        if elapsed > nextAutoMeow {
            nextAutoMeow = elapsed + Double.random(in: 2.5...5.5)
            autoMeow()
        }
    }

    private func spawnIfNeeded(elapsed: TimeInterval) {
        guard !pileIsFull, cats.count < Self.maxCats, !sprites.isEmpty else { return }
        let progress = min(1, elapsed / fillTime)
        if cats.count < targetCount {
            // Slow start, then faster and faster: the first cat comes right away.
            let desired = 1 + Int(Double(targetCount - 1) * pow(progress, 1.5))
            var spawnedThisFrame = 0
            while cats.count < min(desired, targetCount) && spawnedThisFrame < 3 {
                spawnCat()
                spawnedThisFrame += 1
            }
            lastSpawn = elapsed
        } else if elapsed - lastSpawn > 0.35 {
            // The estimate was short: keep topping up until the pile reaches the top.
            spawnCat()
            lastSpawn = elapsed
        }
    }

    private func spawnCat() {
        guard let style = sprites.randomElement() else { return }

        // Long side between 60 and 160 pt (scaled on big screens), biased to the middle.
        let longSide = (60 + 100 * CGFloat((Double.random(in: 0...1) + Double.random(in: 0...1)) / 2)) * sizeFactor
        let spriteSize: CGSize
        if style.aspect > 1 {
            spriteSize = CGSize(width: longSide / style.aspect, height: longSide)
        } else {
            spriteSize = CGSize(width: longSide, height: longSide * style.aspect)
        }

        let cat = SKNode()
        cat.name = Self.catName
        let sprite = SKSpriteNode(texture: style.texture, size: spriteSize)
        sprite.name = Self.catSpriteName
        if Bool.random() {
            sprite.xScale = -1
        }
        cat.addChild(sprite)

        if calm {
            placeCalmly(cat, spriteSize: spriteSize)
            cat.zPosition = CGFloat(cats.count) * 0.01
            addChild(cat)
            cats.append(cat)
            return
        }

        let bodySize = CGSize(width: spriteSize.width * 0.85, height: spriteSize.height * 0.82)
        let body = SKPhysicsBody(rectangleOf: bodySize)
        body.restitution = 0.3
        body.friction = 0.9
        body.density = 1
        body.linearDamping = 0.1
        body.angularDamping = 0.6
        body.allowsRotation = true
        cat.physicsBody = body

        let margin = max(spriteSize.width, spriteSize.height) / 2 + 4
        let minX = margin
        let maxX = max(margin, size.width - margin)
        cat.position = CGPoint(
            x: CGFloat.random(in: minX...maxX),
            y: size.height + margin + CGFloat.random(in: 0...80)
        )
        cat.zRotation = CGFloat.random(in: -0.6...0.6)
        cat.zPosition = CGFloat(cats.count) * 0.01
        body.angularVelocity = CGFloat.random(in: -2...2)
        body.velocity = CGVector(dx: CGFloat.random(in: -60...60), dy: -CGFloat.random(in: 50...250))

        addChild(cat)
        cats.append(cat)
    }

    /// Reduce Motion: puts the cat straight into the stack and fades it in. Rows overlap a
    /// little, like a pile, and fill the screen from the bottom up.
    private func placeCalmly(_ cat: SKNode, spriteSize: CGSize) {
        if cats.isEmpty {
            calmX = -spriteSize.width * 0.2
        }
        if calmX + spriteSize.width * 0.6 > size.width {
            calmRowBase += max(30, calmRowHeight * 0.72)
            calmRowHeight = 0
            calmX = -spriteSize.width * CGFloat.random(in: 0.1...0.4)
        }
        cat.position = CGPoint(x: calmX + spriteSize.width / 2, y: calmRowBase + spriteSize.height / 2)
        cat.zRotation = CGFloat.random(in: -0.12...0.12)
        calmX += spriteSize.width * 0.82
        calmRowHeight = max(calmRowHeight, spriteSize.height)
        cat.alpha = 0
        cat.run(SKAction.fadeIn(withDuration: 0.8))
    }

    /// Checks how high the resting pile is, deepens the tint and stops spawning once full.
    private func scanPile() {
        if calm {
            let top = calmRowBase + calmRowHeight * 0.5
            if top >= size.height * 0.92 || cats.count >= Self.maxCats {
                pileIsFull = true
            }
            // Nothing moves but the fades: a low frame rate is plenty.
            setFrameRate(20)
            updateTint(fraction: Double(min(1, top / max(1, size.height))))
            return
        }
        var top: CGFloat = 0
        for cat in cats {
            guard let body = cat.physicsBody else { continue }
            let v = body.velocity
            let speed = sqrt(v.dx * v.dx + v.dy * v.dy)
            if speed < 40 && cat.position.y < size.height {
                top = max(top, cat.position.y)
            }
        }
        if top >= size.height * 0.92 || cats.count >= Self.maxCats {
            pileIsFull = true
        }
        let settled = pileIsFull && lastScan > activeUntil && cats.allSatisfy { cat in
            guard let v = cat.physicsBody?.velocity else { return true }
            return abs(v.dx) < 8 && abs(v.dy) < 8
        }
        setFrameRate(settled ? Self.restingFPS : Self.activeFPS)

        let byCount = Double(cats.count) / Double(max(1, targetCount))
        let byHeight = Double(top / max(1, size.height))
        updateTint(fraction: min(1, max(byCount, byHeight)))
    }

    private func updateTint(fraction: Double) {
        let step = min(4, Int(fraction * 4))
        if step > dimStep {
            dimStep = step
            tint.removeAction(forKey: "dim")
            tint.run(SKAction.fadeAlpha(to: 0.03 + CGFloat(step) * 0.07, duration: 1.2), withKey: "dim")
        }
    }

    // MARK: - Meows

    private func autoMeow() {
        let visible = cats.filter { cat in
            guard let body = cat.physicsBody else { return calm && cat.position.y < size.height - 20 }
            return cat.position.y < size.height - 20 && abs(body.velocity.dy) < 40
        }
        let topOfPile = visible.sorted { $0.position.y > $1.position.y }.prefix(4)
        guard let cat = topOfPile.randomElement() else { return }
        meow(at: cat)
    }

    private func meow(at cat: SKNode) {
        let text = Self.meows.randomElement() ?? "Miao!"
        let fontSize = CGFloat.random(in: 26...38) * min(1.3, sizeFactor)
        let font = NSFont(name: "AvenirNext-Heavy", size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor(white: 0.1, alpha: 1),
            .strokeWidth: -4.0,
        ]
        let label = SKLabelNode()
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center

        let height = cat.calculateAccumulatedFrame().height
        let x = min(max(cat.position.x, 70), size.width - 70)
        let y = min(cat.position.y + height / 2 + 12, size.height - 40)
        label.position = CGPoint(x: x, y: y)
        label.zPosition = 1000
        label.zRotation = CGFloat.random(in: -0.25...0.25)
        addChild(label)
        if calm {
            // Reduce Motion: the meow fades in and out where it is.
            label.alpha = 0
            label.run(SKAction.sequence([
                SKAction.fadeIn(withDuration: 0.25),
                SKAction.wait(forDuration: 0.9),
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.removeFromParent(),
            ]))
            return
        }
        label.setScale(0.3)

        let pop = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.08),
        ])
        let drift = SKAction.group([
            SKAction.moveBy(x: 0, y: 40, duration: 1.0),
            SKAction.sequence([SKAction.wait(forDuration: 0.5), SKAction.fadeOut(withDuration: 0.5)]),
        ])
        label.run(SKAction.sequence([pop, drift, SKAction.removeFromParent()]))
    }

    // MARK: - Clicks

    override func mouseDown(with event: NSEvent) {
        guard !isScattering else { return }
        let point = event.location(in: self)
        var hit: SKNode?
        for node in nodes(at: point) {
            guard node.name == Self.catSpriteName, let cat = node.parent, cat.name == Self.catName else { continue }
            if hit == nil || cat.zPosition > (hit?.zPosition ?? 0) {
                hit = cat
            }
        }
        if calm, let cat = hit {
            meow(at: cat)
            return
        }
        guard let cat = hit, let body = cat.physicsBody else { return }
        body.velocity = CGVector(dx: CGFloat.random(in: -160...160), dy: CGFloat.random(in: 650...900))
        body.angularVelocity = CGFloat.random(in: -5...5)
        meow(at: cat)
        activeUntil = lastScan + 3
        setFrameRate(Self.activeFPS)
    }

    private func setFrameRate(_ fps: Int) {
        guard let view, view.preferredFramesPerSecond != fps else { return }
        view.preferredFramesPerSecond = fps
    }

    // MARK: - Exit

    /// Removes the floor and walls and flings every cat so the pile falls off the screen.
    func scatter() {
        guard !isScattering else { return }
        isScattering = true
        if calm {
            // Reduce Motion: the pile fades away instead of falling apart.
            for cat in cats {
                cat.run(SKAction.fadeOut(withDuration: 1.0))
            }
            tint.removeAllActions()
            tint.run(SKAction.fadeAlpha(to: 0, duration: 1.0))
            return
        }
        setFrameRate(Self.activeFPS)
        walls.physicsBody = nil
        walls.removeFromParent()
        physicsWorld.gravity = CGVector(dx: 0, dy: -22)
        for cat in cats {
            guard let body = cat.physicsBody else { continue }
            // Cats no longer collide, so the pile falls apart cleanly.
            body.collisionBitMask = 0
            let towardSide: CGFloat = cat.position.x < size.width / 2 ? -1 : 1
            body.velocity = CGVector(
                dx: towardSide * CGFloat.random(in: 80...500),
                dy: CGFloat.random(in: 50...450)
            )
            body.angularVelocity = CGFloat.random(in: -7...7)
        }
        tint.removeAllActions()
        tint.run(SKAction.fadeAlpha(to: 0, duration: 1.0))
    }

    private func removeFallenCats() {
        guard !cats.isEmpty else { return }
        var kept: [SKNode] = []
        kept.reserveCapacity(cats.count)
        for cat in cats {
            if cat.position.y < -300 || cat.position.x < -400 || cat.position.x > size.width + 400 {
                cat.removeFromParent()
            } else {
                kept.append(cat)
            }
        }
        cats = kept
    }
}
