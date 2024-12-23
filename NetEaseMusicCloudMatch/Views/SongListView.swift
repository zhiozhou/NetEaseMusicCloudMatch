import SwiftUI

struct SongListView: View {
    @Binding var songs: [Song]
    @Binding var searchText: String
    @Binding var currentPage: Int
    @Binding var pageSize: Int
    
    // 状态管理
    @State private var sortOrder = [KeyPathComparator(\Song.addTime, order: .reverse)]
    @State private var editingId: String?
    @State private var tempEditId: String = ""
    @State private var selection: Set<String> = []
    
    // 计算总页数
    private var totalPages: Int {
        let total = SongManager.shared.totalSongCount
        return max(1, Int(ceil(Double(total) / Double(pageSize))))
    }
    
    // 过滤后的歌曲列表
    private var filteredSongs: [Song] {
        if searchText.isEmpty {
            return songs
        } else {
            return songs.filter { song in
                song.name.localizedCaseInsensitiveContains(searchText) ||
                song.artist.localizedCaseInsensitiveContains(searchText) ||
                song.album.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 表格视图
            Table(filteredSongs, selection: $selection, sortOrder: $sortOrder) {
                // 序号列
                TableColumn("#", value: \.id) { song in
                    Text(String(format: "%02d", filteredSongs.firstIndex(where: { $0.id == song.id })! + 1))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .width(20)

                // 可编辑的歌曲ID列
                TableColumn("歌曲ID", value: \.id) { song in
                    ZStack {
                        if editingId == song.id {
                            EditableTextField(
                                text: $tempEditId,
                                song: song,
                                songs: $songs,
                                editingId: $editingId,
                                selection: $selection,
                                performMatch: SongManager.shared.performMatch,
                                onTab: selectNextRow,
                                onShiftTab: selectPreviousRow
                            )
                        } else {
                            Text(song.id)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        selection = [song.id]
                                        startEditing(songId: song.id)
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .width(min: 50, ideal: 50)

                // 歌曲信息列
                TableColumn("歌曲信息", value: \.name) { song in
                    HStack(spacing: 10) {
                        CachedAsyncImage(url: URL(string: song.picUrl))
                            .frame(width: 30, height: 30)
                            .cornerRadius(4)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .width(min: 140, ideal: 140)

                // 专辑列
                TableColumn("专辑", value: \.album) { song in
                    Text(song.album)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                .width(min: 100, ideal: 100)

                // 上传时间列
                TableColumn("上传时间", value: \.addTime) { song in
                    Text(formatDate(song.addTime))
                }
                .width(min: 80, ideal: 80)

                // 文件大小列
                TableColumn("文件大小", value: \.fileSize) { song in
                    Text(formatFileSize(song.fileSize))
                }
                .width(min: 40, ideal: 40)

                // 时长列
                TableColumn("时长", value: \.duration) { song in
                    Text(formatDuration(song.duration))
                }
                .width(min: 20, ideal: 20)
            }
            
            // 分页控制器
            HStack {
                Spacer()
                PaginationControl(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    onPageChange: { page in
                        currentPage = page
                        loadPage(page)
                    }
                )
                Spacer()
            }
        }
        .onChange(of: sortOrder) { _, newValue in
            withAnimation {
                songs.sort { lhs, rhs in
                    for comparator in newValue {
                        switch comparator.compare(lhs, rhs) {
                        case .orderedAscending: return true
                        case .orderedDescending: return false
                        case .orderedSame: continue
                        }
                    }
                    return false
                }
            }
        }
        .onChange(of: selection) { _, newSelection in
            if let selectedId = newSelection.first {
                startEditing(songId: selectedId)
            }
        }
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    // 格式化文件大小
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // 格式化时长
    private func formatDuration(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 选择相邻行
    private func selectAdjacentRow(offset: Int) {
        if let currentId = editingId,
           let currentIndex = filteredSongs.firstIndex(where: { $0.id == currentId }),
           let newIndex = Optional(currentIndex + offset),
           newIndex >= 0 && newIndex < filteredSongs.count {
            let targetSong = filteredSongs[newIndex]
            editingId = targetSong.id
            tempEditId = targetSong.id
            selection = [targetSong.id]
        }
    }
    
    // 选择下一行
    private func selectNextRow() {
        selectAdjacentRow(offset: 1)
    }
    
    // 选择上一行
    private func selectPreviousRow() {
        selectAdjacentRow(offset: -1)
    }
    
    // 开始编辑
    private func startEditing(songId: String) {
        editingId = songId
        tempEditId = songId
        
        // 找到对应的歌曲并复制到剪贴板
        if let song = filteredSongs.first(where: { $0.id == songId }) {
            let pasteboard = NSPasteboard.general
            // 如果歌手是未知艺术家，则只复制歌曲名
            let textToCopy = song.artist == "未知艺术家" ? song.name : "\(song.name)-\(song.artist)"
            
            // 获取当前剪贴板内容
            let currentPasteboardString = pasteboard.string(forType: .string) ?? ""
            
            // 只有当剪贴板内容与要复制的内容不同时才进行复制
            if currentPasteboardString != textToCopy {
                pasteboard.clearContents()
                pasteboard.setString(textToCopy, forType: .string)
                
                // 添加复制成功的日志
                SongManager.shared.matchLogs.append(LogInfo(
                    songName: song.name,
                    songId: song.id,
                    matchSongId: "",
                    message: "歌曲名称已复制",
                    status: .info
                ))
            }
        }
    }
    
    private func loadPage(_ page: Int) {
        SongManager.shared.fetchPage(page: page, limit: pageSize)
    }
}

// 在文件末尾添加 EditableTextField 结构体
private struct EditableTextField: View {
    @Binding var text: String
    let song: Song
    @Binding var songs: [Song]
    @Binding var editingId: String?
    @Binding var selection: Set<String>
    let performMatch: (String, String, @escaping (Bool, String) -> Void) -> Void
    let onTab: () -> Void
    let onShiftTab: () -> Void
    
    var body: some View {
        FocusedTextField(text: $text, onSubmit: {
            performMatch(song.id, text) { success, _ in
                if success {
                    // 只在匹配成功时更新歌曲ID
                    if let index = songs.firstIndex(where: { $0.id == song.id }) {
                        songs[index].id = text
                    }
                }
                editingId = nil
                selection.removeAll()
            }
        }, onTab: onTab, onShiftTab: onShiftTab)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 添加 FocusedTextField 结构体
private struct FocusedTextField: NSViewRepresentable {
    typealias NSViewType = NSTextField
    
    @Binding var text: String
    var onSubmit: () -> Void
    var onTab: () -> Void
    var onShiftTab: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.bezelStyle = .roundedBezel
        textField.font = .systemFont(ofSize: 12)
        
        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
            textField.selectText(nil)
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusedTextField
        
        init(_ parent: FocusedTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                parent.onShiftTab()
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }
            return false
        }
    }
}

// 修改 PaginationControl 结构体
private struct PaginationControl: View {
    let currentPage: Int
    let totalPages: Int
    let onPageChange: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            // 上一页按钮
            Button(action: {
                if currentPage > 1 {
                    onPageChange(currentPage - 1)
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(currentPage > 1 ? .blue : .gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .frame(width: 32, height: 28)
            .buttonStyle(PaginationButtonStyle())
            .disabled(currentPage <= 1)
            
            // 页码按钮
            ForEach(getPageRange(), id: \.self) { page in
                Button(action: {
                    if page != currentPage {
                        onPageChange(page)
                    }
                }) {
                    Text("\(page)")
                        .foregroundColor(currentPage == page ? .white : .primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .frame(width: 32, height: 28)
                .buttonStyle(PaginationButtonStyle(isCurrentPage: currentPage == page))
                .disabled(page == currentPage)
            }
            
            // 下一页按钮
            Button(action: {
                if currentPage < totalPages {
                    onPageChange(currentPage + 1)
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(currentPage < totalPages ? .blue : .gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .frame(width: 32, height: 28)
            .buttonStyle(PaginationButtonStyle())
            .disabled(currentPage >= totalPages)
        }
        .padding(.vertical, 8)
    }
    
    // 获取要显示的页码范围
    private func getPageRange() -> [Int] {
        let maxVisiblePages = 3
        var range = [Int]()
        
        if totalPages <= maxVisiblePages {
            range = Array(1...totalPages)
        } else {
            let leftOffset = 1
            let rightOffset = 1
            
            if currentPage <= leftOffset + 1 {
                range = Array(1...maxVisiblePages)
            } else if currentPage >= totalPages - rightOffset {
                range = Array((totalPages - maxVisiblePages + 1)...totalPages)
            } else {
                range = Array((currentPage - leftOffset)...(currentPage + rightOffset))
            }
        }
        
        return range
    }
}

// 修改自定义按钮样式
private struct PaginationButtonStyle: ButtonStyle {
    var isCurrentPage: Bool = false
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor(configuration.isPressed))
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
    
    private func backgroundColor(_ isPressed: Bool) -> Color {
        if isCurrentPage {
            return .blue
        } else if isPressed {
            return .secondary.opacity(0.3)
        } else if isHovering {
            return .secondary.opacity(0.1)
        } else {
            return .clear
        }
    }
}

// 在文件末尾添加预览代码
#Preview {
    // 创建模拟数据
    let mockSongs = [
        Song(
            json: [
                "simpleSong": [
                    "id": 1234567,
                    "name": "测试歌曲1",
                    "ar": [["name": "测试歌手1"]],
                    "al": [
                        "name": "测试专辑1",
                        "picUrl": "https://p2.music.126.net/6y-UleORITEDbvrOLV0Q8A==/5639395138885805.jpg"
                    ],
                    "dt": 180000
                ],
                "fileName": "test1.mp3",
                "fileSize": 8388608,
                "bitrate": 320000,
                "addTime": Date().timeIntervalSince1970 * 1000
            ]
        ),
        Song(
            json: [
                "simpleSong": [
                    "id": 7654321,
                    "name": "测试歌曲2",
                    "ar": [["name": "测试歌手2"]],
                    "al": [
                        "name": "测试专辑2",
                        "picUrl": "https://p2.music.126.net/6y-UleORITEDbvrOLV0Q8A==/5639395138885805.jpg"
                    ],
                    "dt": 240000
                ],
                "fileName": "test2.mp3",
                "fileSize": 12582912,
                "bitrate": 320000,
                "addTime": (Date().timeIntervalSince1970 - 86400) * 1000
            ]
        )
    ].compactMap { $0 }

    return SongListView(
        songs: .constant(mockSongs),
        searchText: .constant(""),
        currentPage: .constant(1),
        pageSize: .constant(200)
    )
    .frame(height: 400)
}

// 添加一个带搜索状态的预览
#Preview("带搜索") {
    let mockSongs = [
        Song(
            json: [
                "simpleSong": [
                    "id": 1234567,
                    "name": "周杰伦 - 晴天",
                    "ar": [["name": "周杰伦"]],
                    "al": [
                        "name": "叶惠美",
                        "picUrl": "https://p2.music.126.net/6y-UleORITEDbvrOLV0Q8A==/5639395138885805.jpg"
                    ],
                    "dt": 180000
                ],
                "fileName": "周杰伦 - 晴天.mp3",
                "fileSize": 8388608,
                "bitrate": 320000,
                "addTime": Date().timeIntervalSince1970 * 1000
            ]
        ),
        Song(
            json: [
                "simpleSong": [
                    "id": 7654321,
                    "name": "林俊杰 - 江南",
                    "ar": [["name": "林俊杰"]],
                    "al": [
                        "name": "第二天堂",
                        "picUrl": "https://p2.music.126.net/6y-UleORITEDbvrOLV0Q8A==/5639395138885805.jpg"
                    ],
                    "dt": 240000
                ],
                "fileName": "林俊杰 - 江南.mp3",
                "fileSize": 12582912,
                "bitrate": 320000,
                "addTime": (Date().timeIntervalSince1970 - 86400) * 1000
            ]
        )
    ].compactMap { $0 }

    return SongListView(
        songs: .constant(mockSongs),
        searchText: .constant("周杰伦"),
        currentPage: .constant(1),
        pageSize: .constant(200)
    )
    .frame(height: 400)
} 
