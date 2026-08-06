import MurmureCore
import SwiftUI

struct LogsView: View {
    let logStore: AppLogStore

    var body: some View {
        ZStack {
            Color.black

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logStore.entries) { entry in
                            Text(line(for: entry))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(entry.id)
                        }
                    }
                    .padding(12)
                }
                .onAppear { scrollToLatest(using: proxy) }
                .onChange(of: logStore.entries.count) { _, _ in
                    scrollToLatest(using: proxy)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Effacer") {
                    logStore.clear()
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 720, minHeight: 420)
    }

    private func line(for entry: AppLogEntry) -> String {
        "\(entry.date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits).secondFraction(.fractional(3))))  \(entry.message)"
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let lastID = logStore.entries.last?.id else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}
