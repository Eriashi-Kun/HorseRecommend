import SwiftUI

struct ParameterCustomizeView: View {
    @Environment(UserWeightsManager.self) private var weights
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var weights = weights
        ZStack {
            SplatTheme.bg.ignoresSafeArea()

            Ellipse()
                .fill(SplatTheme.purple.opacity(0.18))
                .frame(width: 350, height: 260)
                .blur(radius: 80)
                .offset(x: 120, y: -180)
                .allowsHitTesting(false)

            Ellipse()
                .fill(SplatTheme.cyan.opacity(0.12))
                .frame(width: 280, height: 220)
                .blur(radius: 70)
                .offset(x: -130, y: 200)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                titleBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        dataSection(weights: $weights)
                        vibesSection(weights: $weights)
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { weights.save() }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(alignment: .center) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(width: 36, height: 36)
                    .background(SplatTheme.card)
                    .clipShape(Circle())
            }
            .buttonStyle(ScalePressStyle())

            Spacer()

            VStack(spacing: -4) {
                Text("CUSTOMIZE")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("予想スタイルを設定")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.40))
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    weights.reset()
                }
            }) {
                Text("リセット")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(SplatTheme.magenta)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(SplatTheme.magenta.opacity(0.12))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(SplatTheme.magenta.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(ScalePressStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }

    // MARK: - Data Section (objective params)

    private func dataSection(weights: Bindable<UserWeightsManager>) -> some View {
        sectionCard(
            title: "データ系",
            subtitle: "客観的な数値で勝負",
            icon: "chart.bar.fill",
            color: SplatTheme.cyan
        ) {
            VStack(spacing: 16) {
                weightRow(
                    emoji: "🏇",
                    title: "騎手重視度",
                    hint: "騎手の実力をスコアに反映",
                    value: weights.jockey,
                    color: SplatTheme.cyan
                )
                divider
                weightRow(
                    emoji: "📊",
                    title: "過去成績重視度",
                    hint: "馬の過去の走りを重視",
                    value: weights.history,
                    color: SplatTheme.yellow
                )
                divider
                weightRow(
                    emoji: "🔥",
                    title: "人気重視度",
                    hint: "オッズ・人気度をスコアに反映",
                    value: weights.popularity,
                    color: SplatTheme.magenta
                )
            }
        }
    }

    // MARK: - Vibes Section (subjective params)

    private func vibesSection(weights: Bindable<UserWeightsManager>) -> some View {
        sectionCard(
            title: "感覚系",
            subtitle: "直感とロマンで選ぶ",
            icon: "sparkles",
            color: SplatTheme.purple
        ) {
            VStack(spacing: 16) {
                weightRow(
                    emoji: "💝",
                    title: "可愛さ重視度",
                    hint: "名前の響き・イメージで加点",
                    value: weights.cuteness,
                    color: SplatTheme.magenta
                )
                divider
                weightRow(
                    emoji: "🎲",
                    title: "直感重視度",
                    hint: "運とランダム要素でサプライズ",
                    value: weights.intuition,
                    color: SplatTheme.purple
                )
            }
        }
    }

    // MARK: - Section Card Container

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(color)
                    .tracking(1)
                Text("·")
                    .foregroundColor(.white.opacity(0.2))
                Text(subtitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.38))
            }

            Rectangle()
                .fill(color.opacity(0.25))
                .frame(height: 1)

            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(SplatTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.40), color.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }

    // MARK: - Weight Row

    private func weightRow(
        emoji: String,
        title: String,
        hint: String,
        value: Binding<Double>,
        color: Color
    ) -> some View {
        let isOff = value.wrappedValue == 0
        let isMax = value.wrappedValue == 100

        return VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(emoji)
                    .font(.system(size: 22))
                    .opacity(isOff ? 0.4 : 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(isOff ? .white.opacity(0.35) : .white)
                    Text(hint)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(isOff ? 0.18 : 0.38))
                }

                Spacer()

                // バッジ
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isOff ? Color.white.opacity(0.07) : isMax ? color : color.opacity(0.15))
                        .frame(width: 46, height: 30)
                    if isOff {
                        Text("オフ")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.28))
                    } else {
                        Text("\(Int(value.wrappedValue))")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(isMax ? SplatTheme.bg : color)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.12), value: Int(value.wrappedValue))
                    }
                }
            }

            HStack(spacing: 8) {
                Text("なし")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.22))
                    .frame(width: 24, alignment: .leading)

                Slider(value: value, in: 0...100, step: 1)
                    .tint(isOff ? Color.white.opacity(0.2) : color)
                    .animation(.easeInOut(duration: 0.2), value: isOff)

                Text("最重視")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.22))
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isOff)
        .animation(.easeInOut(duration: 0.15), value: isMax)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        Button(action: { dismiss() }) {
            Text("OK！")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(SplatTheme.bg)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SplatButtonStyle(color: SplatTheme.cyan, height: 60))
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .background(SplatTheme.bg.opacity(0.95))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }
}

#Preview {
    ParameterCustomizeView()
        .environment(UserWeightsManager())
}
