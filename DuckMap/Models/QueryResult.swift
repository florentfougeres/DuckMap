import Foundation

struct QueryResult: Sendable {
    struct ColumnInfo: Sendable {
        let name: String
        let typeName: String
        let isGeometry: Bool
    }

    let columns: [ColumnInfo]
    let rows: [[String]]
    let geometryWKB: [[Data?]]   // [geomColumnIndex][rowIndex]
    let geometryColumnIndices: [Int]
    let rowCount: Int

    static let empty = QueryResult(columns: [], rows: [], geometryWKB: [], geometryColumnIndices: [], rowCount: 0)

    init(columns: [ColumnInfo], rows: [[String]], geometryWKB: [[Data?]], geometryColumnIndices: [Int], rowCount: Int) {
        self.columns = columns
        self.rows = rows
        self.geometryWKB = geometryWKB
        self.geometryColumnIndices = geometryColumnIndices
        self.rowCount = rowCount
    }

    init(raw: inout duckdb_result, geomIndices: [Int], typeNames: [String]) {
        let colCount = Int(duckdb_column_count(&raw))
        let rowCount = Int(duckdb_row_count(&raw))

        var columns: [ColumnInfo] = []
        for i in 0..<colCount {
            let name = String(cString: duckdb_column_name(&raw, idx_t(i)))
            let typeName = i < typeNames.count ? typeNames[i] : "UNKNOWN"
            columns.append(ColumnInfo(name: name, typeName: typeName, isGeometry: geomIndices.contains(i)))
        }

        var rows: [[String]] = []
        var geomWKB: [[Data?]] = Array(repeating: Array(repeating: nil, count: rowCount), count: geomIndices.count)

        for row in 0..<rowCount {
            var rowVals: [String] = []
            for col in 0..<colCount {
                if geomIndices.contains(col) {
                    rowVals.append("<geometry>")
                    // Extract WKB blob
                    if let geomArrayIdx = geomIndices.firstIndex(of: col) {
                        var blob = duckdb_value_blob(&raw, idx_t(col), idx_t(row))
                        if blob.size > 0, let ptr = blob.data {
                            geomWKB[geomArrayIdx][row] = Data(bytes: ptr, count: Int(blob.size))
                        }
                        duckdb_free(blob.data)
                    }
                } else {
                    if let ptr = duckdb_value_varchar(&raw, idx_t(col), idx_t(row)) {
                        rowVals.append(String(cString: ptr))
                        duckdb_free(ptr)
                    } else {
                        rowVals.append("NULL")
                    }
                }
            }
            rows.append(rowVals)
        }

        self.columns = columns
        self.rows = rows
        self.geometryWKB = geomWKB
        self.geometryColumnIndices = geomIndices
        self.rowCount = rowCount
    }
}
