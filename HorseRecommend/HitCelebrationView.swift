import SwiftUI

// MARK: - Hit Celebration Overlay

struct HitCelebrationOverlay: View {
    let payout: Int
    let xpGained: Int
    var onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            ConfettiLayer()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                Text("🏆")
                    .font(.system(size: 64))
                    .scaleEffect(appeared ? 1.0 : 0.2)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1), value: appeared)

                Text("的中！")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(SplatTheme.yellow)
                    .shadow(color: SplatTheme.yellow.opacity(0.9), radius: 24)

                VStack(spacing: 4) {
                    Text("払戻")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                    Text("¥\(payout)")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                if xpGained > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                        Text("+\(xpGained) XP")
                            .font(.system(size: 16, weight: .black))
                    }
                    .foregroundStyle(SplatTheme.cyan)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(SplatTheme.cyan.opacity(0.18))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(SplatTheme.cyan.opacity(0.45), lineWidth: 1))
                }

                Button(action: onDismiss) {
                    Text("最高！")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(SplatTheme.bg)
                        .padding(.horizontal, 52).padding(.vertical, 16)
                        .background(SplatTheme.yellow)
                        .clipShape(Capsule())
                        .shadow(color: SplatTheme.yellow.opacity(0.6), radius: 16, y: 6)
                }
                .buttonStyle(ScalePressStyle())
                .padding(.top, 4)
            }
            .padding(.horizontal, 40).padding(.vertical, 36)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(SplatTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 32).stroke(SplatTheme.yellow.opacity(0.5), lineWidth: 2))
                    .shadow(color: .black.opacity(0.6), radius: 50)
            )
            .padding(.horizontal, 28)
            .scaleEffect(appeared ? 1.0 : 0.4)
            .opacity(appeared ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.68)) {
                appeared = true
            }
        }
    }
}

// MARK: - Confetti

private struct ConfettiLayer: View {
    private let particles: [ConfettiParticle] = (0..<60).map { _ in ConfettiParticle() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    ConfettiPieceView(p: p, containerSize: geo.size)
                }
            }
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let xFrac: CGFloat = .random(in: 0.02...0.98)
    let color: Color = [SplatTheme.yellow, SplatTheme.cyan, SplatTheme.magenta,
                        Color.orange, Color.green, Color.white].randomElement()!
    let pieceW: CGFloat = .random(in: 5...12)
    let delay: Double = .random(in: 0...1.6)
    let xDrift: CGFloat = .random(in: -80...80)
    let isSquare: Bool = .random()
    let initRot: Double = .random(in: 0...360)
    let endRot: Double = .random(in: -900...900)
}

private struct ConfettiPieceView: View {
    let p: ConfettiParticle
    let containerSize: CGSize
    @State private var fallen = false

    var body: some View {
        let startX = containerSize.width * p.xFrac
        let endX = startX + p.xDrift

        Group {
            if p.isSquare {
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.pieceW, height: p.pieceW * 1.6)
            } else {
                Circle()
                    .fill(p.color)
                    .frame(width: p.pieceW, height: p.pieceW)
            }
        }
        .rotationEffect(.degrees(fallen ? p.endRot : p.initRot))
        .position(
            x: fallen ? endX : startX,
            y: fallen ? containerSize.height + 30 : -30
        )
        .animation(.easeIn(duration: 2.0).delay(p.delay), value: fallen)
        .onAppear { fallen = true }
    }
}
