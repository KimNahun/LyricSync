import SwiftUI

/// 유저가 번역한 곡 목록을 표시하는 뷰. "내 번역" 탭에서 사용.
struct MyTranslationsListView: View {
    @State private var viewModel = MyTranslationsViewModel()
    @Environment(\.dbUserId) private var dbUserId

    var body: some View {
        Group {
            if dbUserId == nil {
                loginRequiredView
            } else if viewModel.isLoading {
                ProgressView("불러오는 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isEmpty {
                emptyView
            } else {
                translationList
            }
        }
        .task {
            guard let userId = dbUserId else { return }
            await viewModel.fetchTranslations(userId: userId)
        }
        .navigationDestination(for: Song.self) { song in
            SongDetailView(song: song)
        }
    }

    // MARK: - 번역 곡 목록

    private var translationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.translations) { summary in
                    NavigationLink(value: summary.toSong()) {
                        translationRow(summary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
    }

    // MARK: - 개별 행

    private func translationRow(_ summary: MyTranslationSummary) -> some View {
        HStack(spacing: 12) {
            // 앨범 아트
            CachedAsyncImage(url: summary.artworkURL, size: 48)

            // 곡 정보
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(summary.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 번역 줄 수 배지
            Text("\(summary.lineCount)줄")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appStudy)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Color.appStudy.opacity(0.1),
                    in: Capsule()
                )

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - 빈 상태

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "character.book.closed")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("아직 번역한 곡이 없어요")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("곡 상세에서 공부 모드를 켜고\n가사를 직접 번역해 보세요!")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 로그인 필요

    private var loginRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("로그인이 필요합니다")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("내 번역을 저장하고 관리하려면\n로그인해 주세요.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
