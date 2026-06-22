import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var db: DuckDBManager
    @Binding var selectedTable: String?
    var onLoadTable: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with file name
            HStack {
                Image(systemName: db.isConnected ? "cylinder.fill" : "cylinder")
                    .foregroundColor(db.isConnected ? .green : .secondary)
                Text(db.isConnected ? db.currentFileName : "No file")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if db.tables.isEmpty && db.isConnected {
                Text("No tables found")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding()
            } else {
                List(db.tables, id: \.self, selection: $selectedTable) { table in
                    Label(table, systemImage: "tablecells")
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            onLoadTable(table)
                        }
                }
                .listStyle(.sidebar)
            }
        }
    }
}
