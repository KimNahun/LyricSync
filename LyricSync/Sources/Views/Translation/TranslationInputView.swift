import SwiftUI

/// 가사 한 줄의 번역을 입력하는 Sheet.
struct TranslationInputView: View {
    let originalText: String
    let lineIndex: Int
    let existingTranslation: String?
    var onSave: (String) -> Void

    @State private var translation: String = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 원본 가사
                VStack(alignment: .leading, spacing: 6) {
                    Text("원문")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(originalText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                }

                // 번역 입력
                VStack(alignment: .leading, spacing: 6) {
                    Text("내 번역")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("번역을 입력하세요", text: $translation, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                        .focused($isFocused)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("번역 입력")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        let trimmed = translation.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                translation = existingTranslation ?? ""
                isFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}
