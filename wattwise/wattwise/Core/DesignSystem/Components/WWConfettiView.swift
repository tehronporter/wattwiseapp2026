import SwiftUI

// MARK: - Confetti Particle

private struct ConfettiParticle {
    var x: Double
    var y: Double
    var rotation: Double
    var scale: Double
    var color: Color
    var shape: ConfettiShape
    var velocityX: Double
    var velocityY: Double
    var rotationSpeed: Double
}

private enum ConfettiShape: CaseIterable {
    case rectangle, circle, triangle
}

// MARK: - WWConfettiView

struct WWConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animating: Bool = false

    private let particleCount = 60
    private let colors: [Color] = [.wwBlue, .wwSuccess, .wwWarning, Color(hex: "#A78BFA"), Color(hex: "#F472B6")]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let now = timeline.date
                for particle in particles {
                    let elapsed = now.timeIntervalSince(animating ? Date.distantPast : Date())
                    let _ = elapsed  // suppress unused warning; canvas redraws on timeline
                    drawParticle(particle, in: context, size: size)
                }
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            spawnParticles()
        }
    }

    private func spawnParticles() {
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                x: Double.random(in: 0.1...0.9),
                y: Double.random(in: -0.2...0.1),
                rotation: Double.random(in: 0...360),
                scale: Double.random(in: 0.5...1.2),
                color: colors.randomElement()!,
                shape: ConfettiShape.allCases.randomElement()!,
                velocityX: Double.random(in: -0.002...0.002),
                velocityY: Double.random(in: 0.003...0.008),
                rotationSpeed: Double.random(in: -4...4)
            )
        }
    }

    private func drawParticle(_ particle: ConfettiParticle, in context: GraphicsContext, size: CGSize) {
        let x = particle.x * size.width
        let y = particle.y * size.height
        let sz = 8.0 * particle.scale

        var ctx = context
        ctx.translateBy(x: x, y: y)
        ctx.rotate(by: .degrees(particle.rotation))

        let rect = CGRect(x: -sz / 2, y: -sz / 2, width: sz, height: sz * 0.6)
        ctx.fill(
            particle.shape == .circle
                ? Path(ellipseIn: rect)
                : particle.shape == .triangle
                    ? trianglePath(in: rect)
                    : Path(rect),
            with: .color(particle.color)
        )
    }

    private func trianglePath(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// MARK: - Animated Confetti (drives particle physics)

struct WWAnimatedConfetti: View {
    @State private var particles: [AnimatedParticle] = []
    @State private var phase: Double = 0

    private let particleCount = 55
    private let colors: [Color] = [.wwBlue, .wwSuccess, .wwWarning, Color(hex: "#A78BFA"), Color(hex: "#F472B6")]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles.indices, id: \.self) { i in
                    ParticleView(particle: particles[i])
                }
            }
        }
        .onAppear {
            particles = (0..<particleCount).map { i in
                AnimatedParticle(
                    id: i,
                    xFraction: Double.random(in: 0.05...0.95),
                    delay: Double.random(in: 0...0.4),
                    duration: Double.random(in: 1.2...2.0),
                    color: colors.randomElement()!,
                    shape: [0, 1, 2].randomElement()!,
                    rotation: Double.random(in: 0...360),
                    scale: Double.random(in: 0.5...1.1)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AnimatedParticle: Identifiable {
    let id: Int
    let xFraction: Double
    let delay: Double
    let duration: Double
    let color: Color
    let shape: Int    // 0 = rect, 1 = circle, 2 = triangle
    let rotation: Double
    let scale: Double
}

private struct ParticleView: View {
    let particle: AnimatedParticle
    @State private var offsetY: CGFloat = -20
    @State private var opacity: Double = 1.0
    @State private var spin: Double = 0

    var body: some View {
        GeometryReader { geo in
            particleShape
                .frame(width: 10 * particle.scale, height: 6 * particle.scale)
                .foregroundColor(particle.color)
                .rotationEffect(.degrees(spin))
                .position(x: geo.size.width * particle.xFraction, y: offsetY)
                .opacity(opacity)
                .onAppear {
                    offsetY = -20
                    spin = particle.rotation
                    withAnimation(
                        Animation.easeIn(duration: particle.duration)
                            .delay(particle.delay)
                    ) {
                        offsetY = geo.size.height + 20
                        opacity = 0
                        spin = particle.rotation + 360 * (particle.id % 2 == 0 ? 1 : -1)
                    }
                }
        }
    }

    @ViewBuilder
    private var particleShape: some View {
        switch particle.shape {
        case 1:
            Circle()
        case 2:
            TriangleShape()
        default:
            Rectangle()
        }
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
