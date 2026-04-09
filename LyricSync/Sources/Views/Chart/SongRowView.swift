import SwiftUI

/// 차트 리스트에서 개별 곡을 표시하는 행 컴포넌트.
/// 순위, 앨범 아트 썸네일, 곡명, 아티스트명을 표시한다.
struct SongRowView: View {
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            // 순위
            if let rank = song.rank {
                Text("\(rank)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 28, alignment: .trailing)
                    .accessibilityLabel("순위 \(rank)위")
            }

            // 앨범 아트
            AsyncImage(url: song.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.systemFill)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)

            // 곡 정보
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(song.rank.map { "\($0)위, " } ?? "")\(song.title), \(song.artistName)")
    }
}
