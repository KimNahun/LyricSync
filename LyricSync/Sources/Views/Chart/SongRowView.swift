import SwiftUI

/// 차트/검색 리스트에서 개별 곡을 표시하는 행 컴포넌트.
struct SongRowView: View {
    let song: Song
    var hasStudied: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 순위
            if let rank = song.rank {
                Text("\(rank)")
                    .font(.footnote.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
            }

            // 앨범 아트
            CachedAsyncImage(url: song.artworkURL, size: 48)

            // 곡 정보
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 배지 영역
            if hasStudied {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.appStudy)
            }

            // 셰브론
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(song.rank.map { "\($0)위, " } ?? "")\(song.title), \(song.artistName)\(hasStudied ? ", 공부 완료" : "")")
    }
}
