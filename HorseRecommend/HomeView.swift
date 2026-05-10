//
//  HomeView.swift
//  HorseRecommend
//
//  Created by Shutaro Makino on 2026/04/26.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                VStack(spacing: 12) {
                    Text("🏇")
                        .font(.system(size: 80))
                    Text("競馬レコメンド")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                NavigationLink(destination: RaceSelectionView(onSelect: { _ in })) {
                    HStack {
                        Text("レースを選んで始める")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.36, green: 0.51, blue: 1.0), Color(red: 0.58, green: 0.38, blue: 0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                }
                .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 100)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.93, blue: 1.0),
                        Color(red: 0.98, green: 0.93, blue: 1.0),
                        Color(red: 1.0, green: 0.96, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}
