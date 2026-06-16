import SwiftUI

struct ProfileHeaderView: View {
    let user: InstagramUser
    let mediaCount: Int

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: user.profilePictureUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Text(String(user.username.prefix(1)).uppercased())
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "833AB4"), Color(hex: "FCAF45")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(user.username)")
                    .font(.headline)
                if let name = user.name {
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 12) {
                    if let followers = user.followersCount {
                        statView(value: followers, label: "フォロワー")
                    }
                    if mediaCount > 0 || user.mediaCount != nil {
                        statView(value: mediaCount > 0 ? mediaCount : (user.mediaCount ?? 0), label: "投稿")
                    }
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    func statView(value: Int, label: String) -> some View {
        HStack(spacing: 2) {
            Text("\(value)")
                .fontWeight(.semibold)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}
