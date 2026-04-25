import SwiftUI
import UIKit

/// 특정 곡에 대한 유저 번역 버전 목록.
/// 각 버전을 탭하면 해당 버전의 SongDetailView로 이동한다.
struct TranslationVersionsView: View {
    let summary: MyTranslationSummary
    @Environment(\.dbUserId) private var dbUserId
    @State private var versions: [TranslationVersion] = []
    @State private var isLoading = true
    @State private var navigateToVersion: Int?

    private let service = UserTranslationService()

    /// P1 #11 — 마지막(최신) 버전이 빈 상태(라인 0)면 새 버전 생성 비활성화.
    private var canCreateNewVersion: Bool {
        guard let latest = versions.first else { return true }
        return latest.lineCount > 0
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if versions.isEmpty {
                Text("번역 버전이 없습니다")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                versionList
            }
        }
        .navigationTitle(summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await createNewVersion() }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!canCreateNewVersion)
                .accessibilityLabel("새 번역 버전 만들기")
                .accessibilityHint(canCreateNewVersion ? "" : "마지막 버전을 먼저 채워주세요")
            }
        }
        .task {
            await loadVersions()
        }
        .navigationDestination(item: $navigateToVersion) { ver in
            SongDetailView(
                song: summary.toSong(),
                translationVersion: ver
            )
        }
    }

    // MARK: - 버전 목록

    private var versionList: some View {
        List(versions) { version in
            NavigationLink {
                SongDetailView(
                    song: summary.toSong(),
                    translationVersion: version.version
                )
            } label: {
                versionRow(version)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func versionRow(_ version: TranslationVersion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("버전 \(version.version)")
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    Label("\(version.lineCount)줄", systemImage: "text.alignleft")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let date = version.updatedAt {
                        Text(date.formatted(.dateTime.month().day().hour().minute()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if version.version == versions.first?.version {
                Text("최신")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.appStudy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appStudy.opacity(0.12), in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("버전 \(version.version), \(version.lineCount)줄")
    }

    // MARK: - 로드/생성

    private func loadVersions() async {
        guard let userId = dbUserId else {
            isLoading = false
            return
        }
        versions = await service.fetchVersions(userId: userId, appleMusicID: summary.appleMusicID)
        isLoading = false
    }

    private func createNewVersion() async {
        guard let userId = dbUserId else { return }
        let nextVer = await service.nextVersion(userId: userId, appleMusicID: summary.appleMusicID)
        // 빈 번역으로 새 버전 생성
        await service.save(
            userId: userId,
            appleMusicID: summary.appleMusicID,
            title: summary.title,
            artist: summary.artist,
            lines: [],
            version: nextVer
        )
        // P1 #11 — 햅틱 피드백
        await MainActor.run {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        await loadVersions()
        // 새 버전 자동 push
        navigateToVersion = nextVer
    }
}
