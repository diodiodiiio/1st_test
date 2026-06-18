import SwiftUI
import SwiftData

struct SwipeReviewView: View {
    let weekID: String
    let reviewedIDs: Set<String>

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var photoService: PhotoLibraryService
    @StateObject private var vm: ReviewViewModel

    private let swipeThreshold: CGFloat = 100

    init(weekID: String, reviewedIDs: Set<String>) {
        self.weekID = weekID
        self.reviewedIDs = reviewedIDs
        _vm = StateObject(wrappedValue: ReviewViewModel(weekID: weekID, photoService: PhotoLibraryService()))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if vm.items.isEmpty && !vm.isComplete {
                ContentUnavailableView("この週の写真はありません", systemImage: "photo.slash")
            } else if vm.isComplete {
                SummaryView(vm: vm)
            } else {
                VStack(spacing: 0) {
                    progressBar
                    cardStack
                    actionBar
                }
            }
        }
        .navigationTitle(WeekHelper.weekLabel(for: weekID))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.canUndo {
                    Button("元に戻す") { vm.undo() }
                }
            }
        }
        .sheet(isPresented: $vm.showGenrePicker) {
            GenrePickerView(
                onConfirm: { vm.confirmKeep(genreIDs: $0) },
                onCancel:  { vm.showGenrePicker = false }
            )
        }
        .onAppear {
            vm.load(reviewedIDs: reviewedIDs, context: modelContext)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: vm.progress)
                .tint(.blue)
                .padding(.horizontal)
            Text("\(vm.currentIndex) / \(vm.totalCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            // Back cards (visual depth)
            ForEach(nextCards, id: \.id) { item in
                ReviewCardView(item: item, isTop: false)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .scaleEffect(0.94)
                    .offset(y: 12)
            }

            // Current (top) card
            if let current = vm.currentItem {
                ReviewCardView(item: current, isTop: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .offset(vm.dragOffset)
                    .rotationEffect(.degrees(Double(vm.dragOffset.width) / 20))
                    .overlay(swipeIndicator)
                    .gesture(dragGesture)
                    .animation(.spring(response: 0.3), value: vm.dragOffset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var nextCards: [MediaItem] {
        let start = vm.currentIndex + 1
        let end   = min(start + 2, vm.items.count)
        guard start < vm.items.count else { return [] }
        return Array(vm.items[start..<end])
    }

    // MARK: - Swipe Indicator Overlay

    @ViewBuilder
    private var swipeIndicator: some View {
        HStack {
            if vm.dragOffset.width < -20 {
                Label("削除", systemImage: "trash")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.red.opacity(min(1.0, abs(vm.dragOffset.width) / swipeThreshold)))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
                Spacer()
            } else if vm.dragOffset.width > 20 {
                Spacer()
                Label("残す", systemImage: "heart.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.green.opacity(min(1.0, vm.dragOffset.width / swipeThreshold)))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
            }
        }
        .animation(.easeOut(duration: 0.1), value: vm.dragOffset.width)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                vm.isDragging = true
                vm.dragOffset = value.translation
            }
            .onEnded { value in
                vm.isDragging = false
                let dx = value.translation.width
                if dx > swipeThreshold {
                    withAnimation(.easeOut(duration: 0.2)) {
                        vm.dragOffset = CGSize(width: 500, height: 0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        vm.dragOffset = .zero
                        vm.swipeRight()
                    }
                } else if dx < -swipeThreshold {
                    withAnimation(.easeOut(duration: 0.2)) {
                        vm.dragOffset = CGSize(width: -500, height: 0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        vm.dragOffset = .zero
                        vm.swipeLeft()
                    }
                } else {
                    withAnimation(.spring(response: 0.4)) {
                        vm.dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 32) {
            // Delete button
            CircleActionButton(
                icon: "trash",
                color: .red,
                size: 56
            ) {
                withAnimation(.easeOut(duration: 0.2)) {
                    vm.dragOffset = CGSize(width: -500, height: 0)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    vm.dragOffset = .zero
                    vm.swipeLeft()
                }
            }

            // Skip button
            CircleActionButton(icon: "arrow.right.arrow.left", color: .gray, size: 44) {
                vm.skip()
            }

            // Keep button
            CircleActionButton(
                icon: "heart.fill",
                color: .green,
                size: 56
            ) {
                withAnimation(.easeOut(duration: 0.2)) {
                    vm.dragOffset = CGSize(width: 500, height: 0)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    vm.dragOffset = .zero
                    vm.swipeRight()
                }
            }
        }
        .padding(.bottom, 40)
        .padding(.top, 20)
    }
}

struct CircleActionButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(color.opacity(0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 1.5))
        }
    }
}
