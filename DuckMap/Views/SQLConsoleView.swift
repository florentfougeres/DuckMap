import SwiftUI

struct SQLConsoleView: View {
    @EnvironmentObject var db: DuckDBManager
    @Binding var queryResult: QueryResult
    @Binding var mapShapes: [MKShapeWrapper]
    @Binding var mapRegion: MKRegionWrapper?
    @Binding var errorMessage: String?

    @State private var sql = "SELECT * FROM data LIMIT 1000"
    @State private var isRunning = false
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Text("SQL")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }

                if isRunning {
                    ProgressView().scaleEffect(0.6)
                }

                Button {
                    Task { await runQuery() }
                } label: {
                    Label("Run", systemImage: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!db.isConnected || isRunning)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Editor
            TextEditor(text: $sql)
                .font(.system(size: 13, design: .monospaced))
                .focused($editorFocused)
                .frame(minHeight: 80)
                .padding(6)
        }
    }

    private func runQuery() async {
        guard !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isRunning = true
        errorMessage = nil
        do {
            let result = try await db.executeQuery(sql)
            queryResult = result
            updateMap(from: result)
        } catch {
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }

    private func updateMap(from result: QueryResult) {
        var shapes: [MKShapeWrapper] = []
        var allGeometries: [WKBGeometry] = []

        for wkbColumn in result.geometryWKB {
            for wkbData in wkbColumn {
                guard let data = wkbData,
                      let geom = WKBParser.parse(data) else { continue }
                allGeometries.append(geom)
                shapes += geom.toMapKitShapes().map { MKShapeWrapper(shape: $0) }
            }
        }

        mapShapes = shapes

        // Fit map to all geometries bounding box
        if !allGeometries.isEmpty {
            let fakeCollection = WKBGeometry.collection(allGeometries)
            if let region = fakeCollection.boundingRegion {
                mapRegion = MKRegionWrapper(region: region)
            }
        }
    }
}

// Wrappers to pass MKShape and MKCoordinateRegion through SwiftUI bindings (non-Sendable workaround)
struct MKShapeWrapper: Identifiable {
    let id = UUID()
    let shape: MKShape
}

struct MKRegionWrapper {
    let region: MKCoordinateRegion
}

import MapKit
