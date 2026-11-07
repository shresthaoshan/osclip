import SwiftUI

struct HistoryView: View {
    let store: HistoryStore
    let watcher: ClipboardWatcher
    @State private var query = ""
    @AppStorage("grid") private var grid = false

    var body: some View {
        let items = store.search(query)
        Group {
            if items.isEmpty {
                ContentUnavailableView(query.isEmpty ? "No History" : "No Results", systemImage: "doc.on.clipboard")
            } else if grid {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                        ForEach(items) { item in
                            button(item) { cell(item) }
                        }
                    }
                    .padding()
                }
            } else {
                List(items) { item in
                    button(item) { row(item) }
                }
            }
        }
        .searchable(text: $query)
        .toolbar {
            Picker("Layout", selection: $grid) {
                Image(systemName: "list.bullet").tag(false)
                Image(systemName: "square.grid.2x2").tag(true)
            }
            .pickerStyle(.segmented)
        }
        .frame(minWidth: 420, minHeight: 360)
    }

    /// Copies the item and hides the app, so focus returns to the previous app for Cmd+V.
    private func button(_ item: ClipItem, @ViewBuilder label: () -> some View) -> some View {
        Button {
            watcher.copy(item)
            NSApp.hide(nil)
        } label: {
            label().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) { store.remove(item) }
        }
    }

    private func row(_ item: ClipItem) -> some View {
        HStack {
            ItemIcon(item: item, store: store, size: 40).frame(width: 40, height: 40)
            VStack(alignment: .leading) {
                Text(item.title).lineLimit(1)
                Text(item.date, style: .relative).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func cell(_ item: ClipItem) -> some View {
        Group {
            if item.kind == .image {
                ItemIcon(item: item, store: store, size: 130)
            } else {
                Text(item.kind == .file ? item.title : item.text)
                    .font(.caption)
                    .lineLimit(7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(8)
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
