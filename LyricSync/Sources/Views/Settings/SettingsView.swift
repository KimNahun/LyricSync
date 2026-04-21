import SwiftUI

/// 설정 화면. 계정 삭제 기능 포함 (App Store 심사 필수).
struct SettingsView: View {
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @Binding var isAuthenticated: Bool

    private let authService = AuthService()

    var body: some View {
        List {
            // 계정 섹션
            Section {
                if let userId = KeychainService.getUserId() {
                    HStack {
                        Text("Apple ID")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(String(userId.prefix(12)) + "...")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .frame(width: 20, height: 20)
                        }
                        Text("계정 삭제")
                    }
                }
                .disabled(isDeleting)
            } header: {
                Text("계정")
            } footer: {
                Text("계정을 삭제하면 모든 데이터가 삭제되며 복구할 수 없습니다.")
            }

            // 앱 정보 섹션
            Section("앱 정보") {
                HStack {
                    Text("버전")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("설정")
        .alert("계정 삭제", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("정말 계정을 삭제하시겠습니까?\n모든 데이터가 삭제됩니다.")
        }
    }

    private func deleteAccount() async {
        guard let userId = KeychainService.getUserId() else { return }

        isDeleting = true
        await authService.deleteUser(appleUserId: userId)
        isDeleting = false

        isAuthenticated = false
    }
}
