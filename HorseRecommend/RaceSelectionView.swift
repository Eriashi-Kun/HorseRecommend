import SwiftUI

struct RaceSelectionView: View {
    let races: [Race]
    var onSelect: (Race) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay: RaceDay = .saturday
    @State private var selectedVenue: String = ""

    private func venues(for day: RaceDay) -> [String] {
        let order = ["札幌","函館","福島","新潟","中山","東京","中京","京都","阪神","小倉"]
        let present = Set(races.filter { $0.day == day }.map { $0.venue })
        return order.filter { present.contains($0) }
    }

    private var currentVenues: [String] { venues(for: selectedDay) }

    private var displayedRaces: [Race] {
        races
            .filter { $0.day == selectedDay && $0.venue == selectedVenue }
            .sorted { $0.raceNumber < $1.raceNumber }
    }

    var body: some View {
        ZStack {
            SplatTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                daySelector
                venueSelector
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(displayedRaces) { race in
                            Button {
                                onSelect(race)
                                dismiss()
                            } label: {
                                RaceCard(race: race)
                            }
                            .buttonStyle(ScalePressStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("レース選択")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(SplatTheme.surface, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if selectedVenue.isEmpty {
                selectedVenue = currentVenues.first ?? ""
            }
        }
        .onChange(of: selectedDay) { newDay in
            withAnimation { selectedVenue = venues(for: newDay).first ?? "" }
        }
    }

    // MARK: - Day Selector

    private var daySelector: some View {
        HStack(spacing: 0) {
            ForEach(RaceDay.allCases, id: \.self) { day in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) { selectedDay = day }
                }) {
                    VStack(spacing: 3) {
                        Text(day.label)
                            .font(.system(size: 15, weight: .black))
                        Text(dateString(for: day))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(selectedDay == day ? SplatTheme.cyan : .white.opacity(0.38))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        Rectangle()
                            .fill(selectedDay == day ? SplatTheme.cyan : Color.clear)
                            .frame(height: 3)
                            .shadow(color: SplatTheme.cyan.opacity(0.7), radius: 5),
                        alignment: .bottom
                    )
                }
            }
        }
        .background(SplatTheme.surface)
    }

    // MARK: - Venue Selector

    private var venueSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(currentVenues, id: \.self) { venue in
                    Button(action: { withAnimation { selectedVenue = venue } }) {
                        VStack(spacing: 2) {
                            Text(venue)
                                .font(.system(size: 14, weight: .black))
                            Text("\(races.filter { $0.day == selectedDay && $0.venue == venue }.count)R")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(selectedVenue == venue ? SplatTheme.yellow : .white.opacity(0.32))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .overlay(
                            Rectangle()
                                .fill(selectedVenue == venue ? SplatTheme.yellow : Color.clear)
                                .frame(height: 2)
                                .shadow(color: SplatTheme.yellow.opacity(0.6), radius: 4),
                            alignment: .bottom
                        )
                    }
                }
            }
        }
        .background(SplatTheme.surface)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }

    private func dateString(for day: RaceDay) -> String {
        let calendar = Calendar.current
        var date = Date()
        while calendar.component(.weekday, from: date) != 7 {
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        let sat = date
        let sun = calendar.date(byAdding: .day, value: 1, to: sat)!
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: day == .saturday ? sat : sun)
    }
}

// MARK: - RaceCard

struct RaceCard: View {
    let race: Race

    var body: some View {
        ZStack {
            // Colored glow shadow
            RoundedRectangle(cornerRadius: 16)
                .fill(race.grade.color.opacity(0.28))
                .offset(x: 3, y: 5)
                .blur(radius: 5)

            RoundedRectangle(cornerRadius: 16)
                .fill(SplatTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(race.grade.color.opacity(0.38), lineWidth: 1.5)
                )

            HStack(spacing: 14) {
                // Grade + race number
                VStack(spacing: 6) {
                    Text(race.grade.displayText)
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(SplatTheme.bg)
                        .frame(minWidth: 32)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(race.grade.color)
                        .cornerRadius(6)

                    Text(race.raceNumber)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.38))
                }
                .frame(width: 44)

                // Race info
                VStack(alignment: .leading, spacing: 5) {
                    Text(race.name)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(race.distance)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.48))
                        Text("·")
                            .foregroundColor(.white.opacity(0.22))
                        Text(race.condition)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.48))
                        Text("·")
                            .foregroundColor(.white.opacity(0.22))
                        Text("\(race.horses.count)頭")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.48))
                    }
                }

                Spacer()

                // Start time
                VStack(alignment: .trailing, spacing: 2) {
                    Text(race.time)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(race.grade.color)
                        .shadow(color: race.grade.color.opacity(0.5), radius: 4)
                    Text("発走")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.30))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white.opacity(0.22))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}
