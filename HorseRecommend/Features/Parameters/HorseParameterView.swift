import SwiftUI

// MARK: - HorseParameters

struct HorseParameters {
    let values: [(label: String, value: Double)]

    static func compute(rec: Recommendation) -> HorseParameters {
        let h = rec.horse
        let r = rec.race
        let isWet = r.condition == "重" || r.condition == "不良"
        let isDirt = r.distance.hasPrefix("ダ")
        let dist = Double(r.distance.filter { $0.isNumber }) ?? 2000

        // スピード: 脚質 + スコア補正
        let speed: Double
        switch h.runningStyle {
        case .front:   speed = min(99, 75 + rec.score * 0.18)
        case .stalker: speed = min(99, 68 + rec.score * 0.18)
        case .midpack: speed = min(99, 60 + rec.score * 0.18)
        case .closer:  speed = min(99, 52 + rec.score * 0.22)
        }

        // スタミナ: 距離ベース (1000m→25, 3200m→99)
        let stamina = min(99, max(25, (dist - 1000) / 2200 * 74 + 25))

        // 安定感: オッズ低いほど高い
        let stability = min(99, max(10, 99 - (h.odds - 1.0) / 45.0 * 89.0))

        // 馬場適性: 脚質 × 馬場 × 路面
        let trackFit: Double
        switch h.runningStyle {
        case .front:   trackFit = isDirt ? 88 : (isWet ? 42 : 75)
        case .stalker: trackFit = isDirt ? 78 : (isWet ? 58 : 80)
        case .midpack: trackFit = isWet ? 72 : 67
        case .closer:  trackFit = isWet ? 90 : (isDirt ? 48 : 65)
        }

        // 人気: 1番人気≈95、以降 -6ずつ
        let popularity = max(10, min(99, 99 - Double(rec.popularityRank - 1) * 6))

        return HorseParameters(values: [
            ("スピード", speed.rounded()),
            ("スタミナ", stamina.rounded()),
            ("安定感",   stability.rounded()),
            ("馬場適性", trackFit.rounded()),
            ("人気",     popularity.rounded()),
        ])
    }
}

// MARK: - HorseTrait

enum HorseTrait: Hashable {
    case frontRunner, closer, wetTrack, dirtTrack, sprint, longRoute, longShot, favorite

    var label: String {
        switch self {
        case .frontRunner: return "逃げ先行"
        case .closer:      return "差し追込"
        case .wetTrack:    return "道悪◎"
        case .dirtTrack:   return "ダート◎"
        case .sprint:      return "短距離"
        case .longRoute:   return "長距離"
        case .longShot:    return "穴候補"
        case .favorite:    return "本命"
        }
    }

    var icon: String {
        switch self {
        case .frontRunner: return "bolt.fill"
        case .closer:      return "wind"
        case .wetTrack:    return "drop.fill"
        case .dirtTrack:   return "mountain.2.fill"
        case .sprint:      return "hare.fill"
        case .longRoute:   return "tortoise.fill"
        case .longShot:    return "star.fill"
        case .favorite:    return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .frontRunner: return Color(red: 1.00, green: 0.02, blue: 0.65)
        case .closer:      return Color(red: 0.72, green: 0.00, blue: 1.00)
        case .wetTrack:    return Color(red: 0.00, green: 0.95, blue: 1.00)
        case .dirtTrack:   return Color(red: 1.00, green: 0.55, blue: 0.00)
        case .sprint:      return Color(red: 1.00, green: 0.88, blue: 0.00)
        case .longRoute:   return Color(red: 0.00, green: 0.85, blue: 0.50)
        case .longShot:    return Color(red: 1.00, green: 0.02, blue: 0.65)
        case .favorite:    return Color(red: 1.00, green: 0.88, blue: 0.00)
        }
    }

    static func compute(rec: Recommendation) -> [HorseTrait] {
        var traits: [HorseTrait] = []
        let h = rec.horse
        let r = rec.race
        let isWet = r.condition == "重" || r.condition == "不良"
        let isDirt = r.distance.hasPrefix("ダ")
        let dist = Int(r.distance.filter { $0.isNumber }) ?? 2000

        if h.runningStyle == .front || h.runningStyle == .stalker {
            traits.append(.frontRunner)
        } else {
            traits.append(.closer)
        }
        if isWet { traits.append(.wetTrack) }
        if isDirt { traits.append(.dirtTrack) }
        if dist <= 1400 { traits.append(.sprint) }
        if dist >= 2400 { traits.append(.longRoute) }
        if rec.popularityRank <= 2 { traits.append(.favorite) }
        else if h.odds >= 15 { traits.append(.longShot) }

        return Array(traits.prefix(4))
    }
}

// MARK: - RadarChartView

struct RadarChartView: View {
    let params: HorseParameters
    let color: Color
    let size: CGFloat
    var progress: Double = 1.0

    private var n: Int { params.values.count }
    private var center: CGPoint { CGPoint(x: size / 2, y: size / 2) }
    private var radius: CGFloat { size / 2 * 0.66 }

    private func point(index: Int, ratio: Double) -> CGPoint {
        let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(n)
        let r = radius * CGFloat(max(0, ratio))
        return CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
    }

    var body: some View {
        ZStack {
            // グリッドリング
            ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { ratio in
                Path { path in
                    for i in 0..<n {
                        let pt = point(index: i, ratio: ratio)
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                }
                .stroke(Color.white.opacity(ratio == 1.0 ? 0.18 : 0.07), lineWidth: 1)
            }

            // 軸線
            ForEach(0..<n, id: \.self) { i in
                Path { path in
                    path.move(to: center)
                    path.addLine(to: point(index: i, ratio: 1.0))
                }
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }

            // データポリゴン（塗り）
            Path { path in
                for i in 0..<n {
                    let pt = point(index: i, ratio: params.values[i].value / 99 * progress)
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                path.closeSubpath()
            }
            .fill(color.opacity(0.22))

            // データポリゴン（線）
            Path { path in
                for i in 0..<n {
                    let pt = point(index: i, ratio: params.values[i].value / 99 * progress)
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                path.closeSubpath()
            }
            .stroke(color, lineWidth: 2)
            .shadow(color: color.opacity(0.65), radius: 6)

            // 頂点ドット
            ForEach(0..<n, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .shadow(color: color.opacity(0.8), radius: 4)
                    .position(point(index: i, ratio: params.values[i].value / 99 * progress))
            }

            // ラベル（軸の外側）
            ForEach(0..<n, id: \.self) { i in
                let angle = -CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / CGFloat(n)
                let outer = point(index: i, ratio: 1.0)
                let lp = CGPoint(
                    x: outer.x + 28 * cos(angle),
                    y: outer.y + 28 * sin(angle)
                )
                VStack(spacing: 1) {
                    Text(params.values[i].label)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white.opacity(0.45))
                    Text("\(Int(params.values[i].value))")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(color)
                }
                .position(lp)
            }
        }
        .frame(width: size, height: size)
    }
}
