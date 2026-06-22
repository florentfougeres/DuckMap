import Foundation
import Combine

enum DuckMapError: LocalizedError {
    case notConnected
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:         return "No database connected. Open a .duckdb or .parquet file."
        case .queryFailed(let msg): return msg
        }
    }
}

class DuckDBManager: ObservableObject {
    @Published var tables: [String] = []
    @Published var isConnected = false
    @Published var currentFileName = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let queue = DispatchQueue(label: "duckmap.engine", qos: .userInitiated)
    private var db: duckdb_database?
    private var conn: duckdb_connection?

    // MARK: - Open file

    @MainActor
    func openFile(_ url: URL) async {
        isLoading = true
        errorMessage = nil

        let path = url.path
        let ext  = url.pathExtension.lowercased()

        let opened: Bool = await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return continuation.resume(returning: false) }

                // Close previous connection
                if self.conn != nil { duckdb_disconnect(&self.conn); self.conn = nil }
                if self.db   != nil { duckdb_close(&self.db);        self.db   = nil }

                let dbPath = (ext == "duckdb" || ext == "db") ? path : ":memory:"
                guard duckdb_open(dbPath, &self.db) == DuckDBSuccess else {
                    return continuation.resume(returning: false)
                }
                guard duckdb_connect(self.db, &self.conn) == DuckDBSuccess else {
                    return continuation.resume(returning: false)
                }

                // Try to load spatial extension
                self.runSQL("LOAD spatial")

                // Expose non-duckdb files as views
                if ext == "parquet" {
                    let safe = path.replacingOccurrences(of: "'", with: "''")
                    self.runSQL("CREATE OR REPLACE VIEW data AS SELECT * FROM read_parquet('\(safe)')")
                } else if ext == "csv" {
                    let safe = path.replacingOccurrences(of: "'", with: "''")
                    self.runSQL("CREATE OR REPLACE VIEW data AS SELECT * FROM read_csv_auto('\(safe)')")
                }

                continuation.resume(returning: true)
            }
        }

        if opened {
            isConnected = true
            currentFileName = url.lastPathComponent
            await loadTables()
        } else {
            errorMessage = "Failed to open file."
        }
        isLoading = false
    }

    // MARK: - Tables

    @MainActor
    func loadTables() async {
        let sql = """
            SELECT table_name FROM information_schema.tables
            WHERE table_schema NOT IN ('pg_catalog','information_schema')
            UNION ALL
            SELECT view_name FROM information_schema.views
            WHERE view_schema NOT IN ('pg_catalog','information_schema')
            ORDER BY 1
            """
        if let result = try? await executeQuery(sql) {
            tables = result.rows.compactMap { $0.first }
        }
    }

    // MARK: - Query

    func executeQuery(_ sql: String) async throws -> QueryResult {
        guard conn != nil else { throw DuckMapError.notConnected }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self, let conn = self.conn else {
                    return continuation.resume(throwing: DuckMapError.notConnected)
                }
                do {
                    // Detect geometry columns via DESCRIBE
                    let (wrappedSQL, geomIndices, typeNames) = self.prepareSQL(sql, conn: conn)

                    var raw = duckdb_result()
                    guard duckdb_query(conn, wrappedSQL, &raw) == DuckDBSuccess else {
                        let msg = String(cString: duckdb_result_error(&raw))
                        duckdb_destroy_result(&raw)
                        throw DuckMapError.queryFailed(msg)
                    }
                    defer { duckdb_destroy_result(&raw) }

                    let qr = QueryResult(raw: &raw, geomIndices: geomIndices, typeNames: typeNames)
                    continuation.resume(returning: qr)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func loadFullTable(_ name: String) async throws -> QueryResult {
        let safe = name.replacingOccurrences(of: "\"", with: "\"\"")
        return try await executeQuery("SELECT * FROM \"\(safe)\" LIMIT 50000")
    }

    // MARK: - Geometry detection

    private func prepareSQL(_ sql: String, conn: duckdb_connection) -> (sql: String, geomIndices: [Int], typeNames: [String]) {
        var desc = duckdb_result()
        guard duckdb_query(conn, "DESCRIBE (\(sql))", &desc) == DuckDBSuccess else {
            duckdb_destroy_result(&desc)
            return (sql, [], [])
        }
        defer { duckdb_destroy_result(&desc) }

        let rowCount = Int(duckdb_row_count(&desc))
        var typeNames: [String] = []
        var geomCols: [(name: String, idx: Int)] = []

        for row in 0..<rowCount {
            let name = Self.getString(&desc, col: 0, row: row)
            let type = Self.getString(&desc, col: 1, row: row)
            typeNames.append(type)
            if type.uppercased().contains("GEOMETRY") {
                geomCols.append((name: name, idx: row))
            }
        }

        guard !geomCols.isEmpty else { return (sql, [], typeNames) }

        // Wrap geometry columns with ST_AsWKB
        let allNames = (0..<rowCount).map { Self.getString(&desc, col: 0, row: $0) }
        let parts = allNames.enumerated().map { (i, name) -> String in
            let q = "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
            return geomCols.contains(where: { $0.idx == i }) ? "ST_AsWKB(\(q)) AS \(q)" : q
        }

        let wrapped = "SELECT \(parts.joined(separator: ", ")) FROM (\(sql)) AS __dm"
        return (wrapped, geomCols.map { $0.idx }, typeNames)
    }

    // MARK: - Helpers

    @discardableResult
    private func runSQL(_ sql: String) -> Bool {
        guard let conn else { return false }
        var result = duckdb_result()
        let ok = duckdb_query(conn, sql, &result) == DuckDBSuccess
        duckdb_destroy_result(&result)
        return ok
    }

    static func getString(_ result: inout duckdb_result, col: Int, row: Int) -> String {
        guard let ptr = duckdb_value_varchar(&result, idx_t(col), idx_t(row)) else { return "NULL" }
        defer { duckdb_free(ptr) }
        return String(cString: ptr)
    }
}
