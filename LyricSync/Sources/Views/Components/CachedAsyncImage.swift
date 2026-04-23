import SwiftUI
import UIKit

/// 메모리 캐시를 사용하는 비동기 이미지 컴포넌트.
/// AsyncImage와 달리 한 번 로드한 이미지를 캐시하여 스크롤 시 깜빡임을 방지한다.
struct CachedAsyncImage: View {
    let url: URL?
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var image: UIImage?
    @State private var isLoading = false

    init(url: URL?, size: CGFloat, cornerRadius: CGFloat = 8) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color(.tertiarySystemFill)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "music.note")
                                .font(size > 44 ? .caption : .caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else { return }

        // 캐시 확인
        if let cached = ImageCache.shared.get(for: url) {
            self.image = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        // 최대 2회 재시도 (총 3회 시도)
        for attempt in 0..<3 {
            // URL 변경으로 Task가 취소되었으면 중단
            guard !Task.isCancelled else { return }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                guard !Task.isCancelled else { return }

                if let uiImage = UIImage(data: data) {
                    ImageCache.shared.set(uiImage, for: url)
                    self.image = uiImage
                    return
                } else {
                    AppLogger.warn("이미지 디코딩 실패: \(url.lastPathComponent)", category: .network)
                }
            } catch {
                if Task.isCancelled { return }
                AppLogger.warn("이미지 로드 실패 (시도 \(attempt + 1)/3): \(error.localizedDescription)", category: .network)
            }

            // 마지막 시도가 아니면 1초 대기 후 재시도
            if attempt < 2 {
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

/// 앱 내 이미지 메모리 캐시. NSCache 기반으로 메모리 압박 시 자동 해제.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 200
    }

    func get(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}
