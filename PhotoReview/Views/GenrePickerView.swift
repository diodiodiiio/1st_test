import SwiftUI
import SwiftData

struct GenrePickerView: View {
    let onConfirm: ([String]) -> Void
    let onCancel: () -> Void

    @Query(sort: \Genre.sortOrder) private var genres: [Genre]
    @State private var selectedIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("ジャンルを選択")
                    .font(.headline)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                        ForEach(genres) { genre in
                            GenreChip(genre: genre, isSelected: selectedIDs.contains(genre.id)) {
                                if selectedIDs.contains(genre.id) {
                                    selectedIDs.remove(genre.id)
                                } else {
                                    selectedIDs.insert(genre.id)
                                }
                            }
                        }
                    }
                    .padding()
                }

                Divider()

                HStack(spacing: 16) {
                    Button("スキップ") {
                        onConfirm([])
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button("確定") {
                        onConfirm(Array(selectedIDs))
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(genres.isEmpty)
                }
                .padding()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct GenreChip: View {
    let genre: Genre
    let isSelected: Bool
    let onTap: () -> Void

    var color: Color { Color(hex: genre.colorHex) ?? .blue }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: genre.icon)
                    .font(.title2)
                Text(genre.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? color.opacity(0.25) : Color(.systemGray6))
            .foregroundStyle(isSelected ? color : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8)  & 0xFF) / 255,
            blue:  Double(value         & 0xFF) / 255
        )
    }
}
