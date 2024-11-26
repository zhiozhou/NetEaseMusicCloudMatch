import SwiftUI

struct HeaderView: View {
    @ObservedObject var loginManager: LoginManager
    @ObservedObject private var userManager = UserManager.shared
    @Binding var searchText: String
    @Binding var currentPage: Int
    @Binding var pageSize: Int
    @StateObject private var songManager = SongManager.shared
    
    private func formatSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1024 / 1024 / 1024
        return String(format: "%.1fG", gb)
    }
    
    var body: some View {
        HStack {
            // 用户信息区域：头像和用户名
            HStack(spacing: 10) {
                // 用户头像 - 如果有头像则显示，否则显示默认图标
                if let avatar = userManager.userAvatar {
                    Image(nsImage: avatar)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .cornerRadius(4)  // 圆角效果提升视觉体验
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .cornerRadius(4)
                }
                
                // 用户名和登出按钮垂直排列
                VStack(alignment: .leading, spacing: 2) {
                    Text(userManager.username)
                        .fontWeight(.medium)
                    Button("Sign Out") {
                        Task { @MainActor in
                            await loginManager.logout()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.blue)
                    .font(.caption)
                }
            }
            
            Spacer()
            
            // 添加容量信息
            if songManager.maxSize > 0 {
                Text("\(formatSize(songManager.usedSize))/\(formatSize(songManager.maxSize))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 搜索栏 - 使用HStack组合搜索图标和输入框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索音乐", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .frame(width: 200)
            }
            .padding(6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // 刷新按钮 - 用于重新加载云盘音乐
            Button(action: {
                refreshData()
            }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 10)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func refreshData() {
        currentPage = 1
        SongManager.shared.fetchPage(page: currentPage, limit: pageSize)
    }
}

#Preview {
    HeaderView(
        loginManager: LoginManager.shared,
        searchText: .constant(""),
        currentPage: .constant(1),
        pageSize: .constant(1)
    )
} 