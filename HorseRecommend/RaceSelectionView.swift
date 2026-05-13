import SwiftUI

struct RaceSelectionView: View {
    let races: [Race]
    var onSelect: (Race) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay: String = ""
    @State private var selectedVenue: String = ""

    private var uniqueDays: [String] {
        Array(Set(races.map { $0.day })).sorted()
    }

    private func dayLabel(for dateStr: String) -> String {
        guard dateStr.count == 8 else { return dateStr }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        guard let date = fmt.date(from: dateStr) else { return dateStr }
        let disp = DateFormatter()
        disp.locale = Locale(identifier: "ja_JP")
        disp.dateFormat = "M/d(E)"
        return disp.string(from: date)
    }

    private func venues(for day: String) -> [String] {
        let order = ["札幌","函館","福島","新潟","中山","東京","中京","京都","阪神","小倉"]
        let present = Set(races.filter { $0.day == day }.map { $0.venue })
        return order.filter { present.contains($0) }
    }

    private var currentVenues: [String] { venues(for: selectedDay) }

    private var displayedRaces: [Race] {
        races
            .filter { $0.day == selectedDay && $0.venue == selectedVenue }
            .sorted { $0.time < $1.time }
    }

    private var nextRaceID: UUID? {
        displayedRaces.first(where: { !$0.isPast })?.id
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
                            let past = race.isPast
                            let next = race.id == nextRaceID
                            Button {
                                onSelect(race)
                                dismiss()
                            } label: {
                                RaceCard(race: race, isPast: past, isNext: next)
                            }
                            .buttonStyle(ScalePressStyle())
                            .disabled(past)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(width: 36, height: 36)
                        .background(SplatTheme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(ScalePressStyle())
            }
        }
        .onAppear {
            if selectedDay.isEmpty {
                let dateFmt = DateFormatter()
                dateFmt.dateFormat = "yyyyMMdd"
                let today = dateFmt.string(from: Date())
                selectedDay = uniqueDays.first(where: { $0 >= today }) ?? uniqueDays.first ?? ""
            }
            if selectedVenue.isEmpty {
                selectedVenue = currentVenues.first ?? ""
            }
        }
        .onChange(of: selectedDay) { _, newDay in
            withAnimation { selectedVenue = venues(for: newDay).first ?? "" }
        }
    }

    // MARK: - Day Selector

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(uniqueDays, id: \.self) { day in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) { selectedDay = day }
                    }) {
                        Text(dayLabel(for: day))
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(selectedDay == day ? SplatTheme.cyan : .white.opacity(0.38))
                            .padding(.horizontal, 20)
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
}

// MARK: - RaceCard

struct RaceCard: View {
    let race: Race
    var isPast: Bool = false
    var isNext: Bool = false

    private var accentColor: Color {
        isNext ? SplatTheme.yellow : race.grade.color
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(accentColor.opacity(isNext ? 0.35 : 0.18))
                .offset(x: 3, y: 5)
                .blur(radius: isNext ? 8 : 4)

            RoundedRectangle(cornerRadius: 16)
                .fill(SplatTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            accentColor,
                            lineWidth: isNext ? 2.0 : 1.0
                        )
                        .opacity(isNext ? 1.0 : 0.38)
                )

            HStack(spacing: 14) {
                VStack(spacing: 6) {
                    if race.showsGradeBadge {
                        Text(race.grade.displayText)
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(SplatTheme.bg)
                            .frame(minWidth: 32)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(isPast ? Color.gray : race.grade.color)
                            .cornerRadius(6)
                    }
                    Text(race.raceNumber)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(isPast ? 0.22 : 0.38))
                }
                .frame(width: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(race.name)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(isPast ? .white.opacity(0.35) : .white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(race.distance)
                            .font(.system(size: 12, weight: .bold))
                        Text("·")
                        Text(race.condition)
                            .font(.system(size: 12, weight: .bold))
                        Text("·")
                        Text("\(race.horses.count)頭")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(isPast ? 0.22 : 0.48))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(race.time)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(isPast ? .white.opacity(0.25) : accentColor)
                        .shadow(
                            color: accentColor.opacity(isNext ? 0.9 : 0.0),
                            radius: isNext ? 10 : 0
                        )
                    Text(isPast ? "終了" : (isNext ? "次走" : "発走"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(
                            isPast ? .white.opacity(0.22)
                            : isNext ? SplatTheme.yellow.opacity(0.85)
                            : .white.opacity(0.30)
                        )
                }

                if isPast {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.18))
                } else if isNext {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(SplatTheme.yellow.opacity(0.7))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white.opacity(0.22))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .opacity(isPast ? 0.5 : 1.0)
    }
}
