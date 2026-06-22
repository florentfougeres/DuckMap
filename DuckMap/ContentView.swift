import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var db: DuckDBManager

    @State private var selectedTable: String? = nil
    @State private var queryResult: QueryResult = .empty
    @State private var mapShapes: [MKShapeWrapper] = []
    @State private var mapRegion: MKRegionWrapper? = nil
    @State private var queryError: String? = nil
    @State private var isImporting = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTable: $selectedTable) { table in
                Task { await loadTable(table) }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        isImporting = true
                    } label: {
                        Label("Open File", systemImage: "folder")
                    }
                    .help("Open .duckdb or .parquet file")
                }
                ToolbarItem {
                    if db.isLoading {
                        ProgressView().scaleEffect(0.7)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            HSplitView {
                // Left: SQL console + results
                VSplitView {
                    SQLConsoleView(
                        queryResult: $queryResult,
                        mapShapes: $mapShapes,
                        mapRegion: $mapRegion,
                        errorMessage: $queryError
                    )
                    .frame(minHeight: 120, idealHeight: 160)

                    ResultsTableView(result: queryResult)
                        .frame(minHeight: 100)
                }
                .frame(minWidth: 380, idealWidth: 480)

                // Right: Map
                MapView(
                    shapes: mapShapes.map { $0.shape },
                    fitRegion: mapRegion?.region
                )
                .frame(minWidth: 300)
                .overlay {
                    if mapShapes.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Run a query with geometry data\nto see it on the map")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.init(filenameExtension: "duckdb")!,
                                  .init(filenameExtension: "parquet")!,
                                  .init(filenameExtension: "db")!],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await db.openFile(url) }
            }
        }
        .alert("Error", isPresented: .constant(db.errorMessage != nil)) {
            Button("OK") { db.errorMessage = nil }
        } message: {
            Text(db.errorMessage ?? "")
        }
    }

    private func loadTable(_ name: String) async {
        do {
            let result = try await db.loadFullTable(name)
            queryResult = result
        } catch {
            queryError = error.localizedDescription
        }
    }
}
