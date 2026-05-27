import SwiftUI
import GoogleMobileAds
import UIKit

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}

// 「広告」ラベル付きバナー（AdMobポリシー：ナビゲーション誤認防止）
struct LabeledBannerAdView: View {
    let adUnitID: String

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            HStack {
                Spacer()
                Text("広告")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.35))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            .background(SplatTheme.bg)
            BannerAdView(adUnitID: adUnitID)
                .frame(height: 50)
                .background(SplatTheme.bg)
        }
    }
}
