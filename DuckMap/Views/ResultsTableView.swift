import SwiftUI

struct ResultsTableView: View {
    let result: QueryResult
    @State private var sortColumn: Int? = nil
    @State private var sortAscending = true

    private var sortedRows: [[String]] {
        guard let col = sortColumn, col < result.columns.count else { return result.rows }
        return result.rows.sorted {
            let a = $0[col], b = $1[col]
            return sortAscending ? a < b : a > b
        }
    }

    var body: some View {
        if result.columns.isEmpty {
            Color.clear
        } else {
            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                    // Header
                    GridRow {
                        ForEach(result.columns.indices, id: \.self) { i in
                            let col = result.columns[i]
                            Button {
                                if sortColumn == i { sortAscending.toggle() }
                                else { sortColumn = i; sortAscending = true }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(col.name)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    if col.isGeometry {
                                        Image(systemName: "map")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    if sortColumn == i {
                                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                            .font(.caption2)
                                    }
                                }
                                .frame(minWidth: 80, maxWidth: 240, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .background(Color(NSColor.controlBackgroundColor))
                            .overlay(alignment: .trailing) {
                                Divider()
                            }
                        }
                    }

                    Divider()

                    // Rows
                    ForEach(sortedRows.indices, id: \.self) { rowIdx in
                        GridRow {
                            ForEach(result.columns.indices, id: \.self) { colIdx in
                                Text(sortedRows[rowIdx][colIdx])
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(
                                        result.columns[colIdx].isGeometry ? .blue :
                                        sortedRows[rowIdx][colIdx] == "NULL" ? .secondary : .primary
                                    )
                                    .lineLimit(1)
                                    .frame(minWidth: 80, maxWidth: 240, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(rowIdx % 2 == 0 ? Color.clear : Color(NSColor.alternatingContentBackgroundColors[1]))
                                    .overlay(alignment: .trailing) { Divider() }
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Text("\(result.rowCount) rows · \(result.columns.count) cols")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(.regularMaterial)
                    .cornerRadius(4)
                    .padding(6)
            }
        }
    }
}
