//
//  HorseIcons.swift
//  HorseRecommend
//
//  Created by Shutaro Makino on 2026/04/26.
//

import SwiftUI

// MARK: - 固め用の馬（緑・優しい）
struct SafeHorse: View {
    var body: some View {
        ZStack {
            // 頭部
            Ellipse()
                .fill(Color(red: 0.063, green: 0.725, blue: 0.506))
                .frame(width: 18, height: 20)
                .offset(y: -4)

            // 鼻・口の部分
            Ellipse()
                .fill(Color(red: 0.204, green: 0.827, blue: 0.6))
                .frame(width: 10, height: 12)
                .offset(y: 5)

            // 耳（左）
            Ellipse()
                .fill(Color(red: 0.063, green: 0.725, blue: 0.506))
                .frame(width: 4, height: 8)
                .rotationEffect(.degrees(-20))
                .offset(x: -6, y: -12)

            // 耳（右）
            Ellipse()
                .fill(Color(red: 0.063, green: 0.725, blue: 0.506))
                .frame(width: 4, height: 8)
                .rotationEffect(.degrees(20))
                .offset(x: 6, y: -12)

            // 目（左）
            Circle()
                .fill(Color(red: 0.024, green: 0.373, blue: 0.275))
                .frame(width: 5, height: 5)
                .offset(x: -4, y: -5)
            Circle()
                .fill(.white)
                .frame(width: 2, height: 2)
                .offset(x: -3.5, y: -5.5)

            // 目（右）
            Circle()
                .fill(Color(red: 0.024, green: 0.373, blue: 0.275))
                .frame(width: 5, height: 5)
                .offset(x: 4, y: -5)
            Circle()
                .fill(.white)
                .frame(width: 2, height: 2)
                .offset(x: 4.5, y: -5.5)

            // 鼻の穴
            Ellipse()
                .fill(Color(red: 0.024, green: 0.373, blue: 0.275))
                .frame(width: 2, height: 3)
                .offset(x: -2, y: 6)
            Ellipse()
                .fill(Color(red: 0.024, green: 0.373, blue: 0.275))
                .frame(width: 2, height: 3)
                .offset(x: 2, y: 6)

            // 口（優しい笑顔）
            Path { path in
                path.move(to: CGPoint(x: -3, y: 9))
                path.addQuadCurve(to: CGPoint(x: 3, y: 9), control: CGPoint(x: 0, y: 11))
            }
            .stroke(Color(red: 0.024, green: 0.373, blue: 0.275), lineWidth: 1.5)

            // 頬の赤み
            Ellipse()
                .fill(Color.red.opacity(0.3))
                .frame(width: 4, height: 3)
                .offset(x: -7, y: -1)
            Ellipse()
                .fill(Color.red.opacity(0.3))
                .frame(width: 4, height: 3)
                .offset(x: 7, y: -1)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - 中穴用の馬（青・自信あり）
struct BalancedHorse: View {
    var body: some View {
        ZStack {
            // 頭部
            Ellipse()
                .fill(Color(red: 0.231, green: 0.510, blue: 0.965))
                .frame(width: 18, height: 20)
                .offset(y: -4)

            // 鼻・口の部分
            Ellipse()
                .fill(Color(red: 0.376, green: 0.647, blue: 0.980))
                .frame(width: 10, height: 12)
                .offset(y: 5)

            // 耳（左）
            Ellipse()
                .fill(Color(red: 0.231, green: 0.510, blue: 0.965))
                .frame(width: 4, height: 8)
                .rotationEffect(.degrees(-20))
                .offset(x: -6, y: -12)

            // 耳（右）
            Ellipse()
                .fill(Color(red: 0.231, green: 0.510, blue: 0.965))
                .frame(width: 4, height: 8)
                .rotationEffect(.degrees(20))
                .offset(x: 6, y: -12)

            // 額の星
            Circle()
                .fill(Color(red: 0.984, green: 0.749, blue: 0.141))
                .frame(width: 3, height: 3)
                .offset(y: -10)

            // 目（左・自信あり）
            Ellipse()
                .fill(Color(red: 0.118, green: 0.227, blue: 0.541))
                .frame(width: 5, height: 6)
                .offset(x: -4, y: -5)
            Circle()
                .fill(.white)
                .frame(width: 2, height: 2)
                .offset(x: -3.5, y: -5.5)

            // 目（右）
            Ellipse()
                .fill(Color(red: 0.118, green: 0.227, blue: 0.541))
                .frame(width: 5, height: 6)
                .offset(x: 4, y: -5)
            Circle()
                .fill(.white)
                .frame(width: 2, height: 2)
                .offset(x: 4.5, y: -5.5)

            // 鼻の穴
            Ellipse()
                .fill(Color(red: 0.118, green: 0.227, blue: 0.541))
                .frame(width: 2, height: 3)
                .offset(x: -2, y: 6)
            Ellipse()
                .fill(Color(red: 0.118, green: 0.227, blue: 0.541))
                .frame(width: 2, height: 3)
                .offset(x: 2, y: 6)

            // 口（自信ありげな笑顔）
            Path { path in
                path.move(to: CGPoint(x: -3, y: 9))
                path.addQuadCurve(to: CGPoint(x: 3, y: 9), control: CGPoint(x: 0, y: 12))
            }
            .stroke(Color(red: 0.118, green: 0.227, blue: 0.541), lineWidth: 2)

            // エネルギーライン（左）
            Path { path in
                path.move(to: CGPoint(x: -11, y: -2))
                path.addLine(to: CGPoint(x: -14, y: 0))
            }
            .stroke(Color(red: 0.376, green: 0.647, blue: 0.980).opacity(0.6), lineWidth: 2)

            // エネルギーライン（右）
            Path { path in
                path.move(to: CGPoint(x: 11, y: -2))
                path.addLine(to: CGPoint(x: 14, y: 0))
            }
            .stroke(Color(red: 0.376, green: 0.647, blue: 0.980).opacity(0.6), lineWidth: 2)
        }
        .frame(width: 32, height: 32)
    }
}

// MARK: - ロマン用の馬（オレンジ・興奮）
struct RomanticHorse: View {
    var body: some View {
        ZStack {
            // 炎エフェクト（左）
            Path { path in
                path.move(to: CGPoint(x: -12, y: -8))
                path.addCurve(
                    to: CGPoint(x: -11, y: -8),
                    control1: CGPoint(x: -12, y: -10),
                    control2: CGPoint(x: -13, y: -12)
                )
                path.addCurve(
                    to: CGPoint(x: -9, y: -5),
                    control1: CGPoint(x: -10, y: -9),
                    control2: CGPoint(x: -10, y: -7)
                )
            }
            .fill(Color(red: 0.965, green: 0.620, blue: 0.043).opacity(0.7))

            // 炎エフェクト（右）
            Path { path in
                path.move(to: CGPoint(x: 12, y: -8))
                path.addCurve(
                    to: CGPoint(x: 11, y: -8),
                    control1: CGPoint(x: 12, y: -10),
                    control2: CGPoint(x: 13, y: -12)
                )
                path.addCurve(
                    to: CGPoint(x: 9, y: -5),
                    control1: CGPoint(x: 10, y: -9),
                    control2: CGPoint(x: 10, y: -7)
                )
            }
            .fill(Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.7))

            // 頭部
            Ellipse()
                .fill(Color(red: 0.976, green: 0.451, blue: 0.086))
                .frame(width: 18, height: 20)
                .offset(y: -2)

            // 鼻・口の部分
            Ellipse()
                .fill(Color(red: 0.984, green: 0.573, blue: 0.235))
                .frame(width: 10, height: 12)
                .offset(y: 7)

            // 耳（左）
            Ellipse()
                .fill(Color(red: 0.976, green: 0.451, blue: 0.086))
                .frame(width: 4, height: 8)
                .rotationEffect(.degrees(-20))
                .offset(x: -6, y: -10)

            // 耳（右）
            Ellipse()
                .fill(Color(red: 0.976, green: 0.451, blue: 0.086))
                .frame(width: 4, height: 8)
                .rotationEffect(.degrees(20))
                .offset(x: 6, y: -10)

            // 目（左・興奮）
            Ellipse()
                .fill(Color(red: 0.486, green: 0.176, blue: 0.071))
                .frame(width: 6, height: 8)
                .offset(x: -4, y: -3)
            Circle()
                .fill(.white)
                .frame(width: 2.4, height: 2.4)
                .offset(x: -3.5, y: -4)

            // 目（右）
            Ellipse()
                .fill(Color(red: 0.486, green: 0.176, blue: 0.071))
                .frame(width: 6, height: 8)
                .offset(x: 4, y: -3)
            Circle()
                .fill(.white)
                .frame(width: 2.4, height: 2.4)
                .offset(x: 4.5, y: -4)

            // 鼻の穴（興奮で広がる）
            Ellipse()
                .fill(Color(red: 0.486, green: 0.176, blue: 0.071))
                .frame(width: 3, height: 4)
                .offset(x: -2, y: 8)
            Ellipse()
                .fill(Color(red: 0.486, green: 0.176, blue: 0.071))
                .frame(width: 3, height: 4)
                .offset(x: 2, y: 8)

            // 口（興奮した笑顔）
            Path { path in
                path.move(to: CGPoint(x: -4, y: 11))
                path.addQuadCurve(to: CGPoint(x: 4, y: 11), control: CGPoint(x: 0, y: 14))
            }
            .stroke(Color(red: 0.486, green: 0.176, blue: 0.071), lineWidth: 2)

            // スパーク
            Circle()
                .fill(Color(red: 0.984, green: 0.749, blue: 0.141))
                .frame(width: 2, height: 2)
                .offset(x: -10, y: -5)
            Circle()
                .fill(Color(red: 0.984, green: 0.749, blue: 0.141))
                .frame(width: 2, height: 2)
                .offset(x: 10, y: -5)
            Circle()
                .fill(Color(red: 0.992, green: 0.831, blue: 0.302))
                .frame(width: 1.6, height: 1.6)
                .offset(x: -8, y: -8)
            Circle()
                .fill(Color(red: 0.992, green: 0.831, blue: 0.302))
                .frame(width: 1.6, height: 1.6)
                .offset(x: 8, y: -8)
        }
        .frame(width: 32, height: 32)
    }
}

