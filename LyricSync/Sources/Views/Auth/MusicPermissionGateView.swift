import SwiftUI
import MusicKit
import UIKit

/// MusicKit 권한이 거부/제한된 상태일 때 전체 화면을 대체하는 게이트.
/// 설정 앱 열기 버튼 + 권한 재요청 버튼을 제공한다.
struct MusicPermissionGateView: View {
    var onAuthorized: () -> Void = {}

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Apple Music 접근 권한이 필요합니다")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("LyricSync 는 Apple Music 차트 조회와\n곡 재생을 위해 음악 라이브러리 접근 권한이 필요합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await requestPermission() }
                } label: {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("권한 요청")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)
                .accessibilityLabel("Apple Music 권한 요청")

                Button {
                    openSettings()
                } label: {
                    Text("설정 앱 열기")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("iOS 설정에서 권한 허용하기")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func requestPermission() async {
        isRequesting = true
        let status = await MusicAuthorization.request()
        isRequesting = false
        if status == .authorized {
            onAuthorized()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
