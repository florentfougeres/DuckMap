# DuckMap

Native macOS (Apple Silicon) app to explore and map [DuckDB](https://duckdb.org) spatial data.
SQL console + table browser + MapKit rendering of `GEOMETRY` columns.

## Features

- Open `.duckdb` and `.parquet` files
- Browse tables in a sidebar, double-click to load
- SQL console with results table (`⌘↵` to run)
- Auto-detect `GEOMETRY` columns → render on a native MapKit map (via WKB, no JSON overhead)

## Setup

DuckMap links against DuckDB's native library, which is too large for git.
After cloning, download it once:

```bash
./scripts/setup.sh
```

Then open `DuckMap.xcodeproj` in Xcode and build (`⌘B`).

### Xcode configuration (one-time, if cloning fresh)

- **Build Settings → Objective-C Bridging Header**: `DuckMap/DuckMap-Bridging-Header.h`
- **Build Settings → Library Search Paths**: `$(PROJECT_DIR)/DuckDBLib`
- **General → Frameworks, Libraries, and Embedded Content**: add `DuckDBLib/libduckdb.dylib`, set to **Embed & Sign**

## Stack

- SwiftUI + AppKit (MapKit via `NSViewRepresentable`)
- DuckDB C API through a bridging header
- WKB parser → `MKPolyline` / `MKPolygon` / `MKPointAnnotation`
