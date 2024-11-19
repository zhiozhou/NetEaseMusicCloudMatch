import SwiftUI

struct CachedAsyncImage: View {
    let url: URL?
    @State private var image: NSImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.gray
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        // 先从缓存中查找
        if let cachedImage = ImageCache.shared.get(url.absoluteString) {
            self.image = cachedImage
            return
        }
        
        // 如果缓存中没有，则下载图片
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let downloadedImage = NSImage(data: data) {
                DispatchQueue.main.async {
                    // 保存到缓存
                    ImageCache.shared.set(downloadedImage, for: url.absoluteString)
                    self.image = downloadedImage
                }
            }
        }.resume()
    }
} 