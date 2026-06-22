import Foundation
import MapKit

enum WKBGeometry {
    case point(CLLocationCoordinate2D)
    case lineString([CLLocationCoordinate2D])
    case polygon(exterior: [CLLocationCoordinate2D], holes: [[CLLocationCoordinate2D]])
    case multiPoint([CLLocationCoordinate2D])
    case multiLineString([[CLLocationCoordinate2D]])
    case multiPolygon([(exterior: [CLLocationCoordinate2D], holes: [[CLLocationCoordinate2D]])])
    case collection([WKBGeometry])
}

struct WKBParser {
    private var data: Data
    private var offset: Int = 0
    private var littleEndian: Bool = true

    static func parse(_ data: Data) -> WKBGeometry? {
        var parser = WKBParser(data: data)
        return try? parser.readGeometry()
    }

    private init(data: Data) {
        self.data = data
    }

    private mutating func readGeometry() throws -> WKBGeometry {
        let byteOrder = try readByte()
        littleEndian = byteOrder == 1

        var typeInt = try readUInt32()
        // Strip SRID flag (ISO WKB)
        let hasSRID = (typeInt & 0x20000000) != 0
        typeInt = typeInt & 0x0FFFFFFF
        if hasSRID { _ = try readUInt32() }

        switch typeInt {
        case 1:  return .point(try readPoint())
        case 2:  return .lineString(try readLineString())
        case 3:
            let rings = try readPolygonRings()
            return .polygon(exterior: rings.exterior, holes: rings.holes)
        case 4:  return .multiPoint(try readMultiPoint())
        case 5:  return .multiLineString(try readMultiLineString())
        case 6:  return .multiPolygon(try readMultiPolygon())
        case 7:  return .collection(try readCollection())
        default: throw WKBError.unsupportedType(typeInt)
        }
    }

    private mutating func readPoint() throws -> CLLocationCoordinate2D {
        let x = try readDouble()
        let y = try readDouble()
        return CLLocationCoordinate2D(latitude: y, longitude: x)
    }

    private mutating func readLineString() throws -> [CLLocationCoordinate2D] {
        let count = Int(try readUInt32())
        return try (0..<count).map { _ in try readPoint() }
    }

    private mutating func readPolygonRings() throws -> (exterior: [CLLocationCoordinate2D], holes: [[CLLocationCoordinate2D]]) {
        let ringCount = Int(try readUInt32())
        var rings: [[CLLocationCoordinate2D]] = []
        for _ in 0..<ringCount {
            rings.append(try readLineString())
        }
        let exterior = rings.first ?? []
        let holes = rings.count > 1 ? Array(rings.dropFirst()) : []
        return (exterior, holes)
    }

    private mutating func readMultiPoint() throws -> [CLLocationCoordinate2D] {
        let count = Int(try readUInt32())
        var points: [CLLocationCoordinate2D] = []
        for _ in 0..<count {
            if case .point(let pt) = try readGeometry() {
                points.append(pt)
            }
        }
        return points
    }

    private mutating func readMultiLineString() throws -> [[CLLocationCoordinate2D]] {
        let count = Int(try readUInt32())
        var lines: [[CLLocationCoordinate2D]] = []
        for _ in 0..<count {
            if case .lineString(let line) = try readGeometry() {
                lines.append(line)
            }
        }
        return lines
    }

    private mutating func readMultiPolygon() throws -> [(exterior: [CLLocationCoordinate2D], holes: [[CLLocationCoordinate2D]])] {
        let count = Int(try readUInt32())
        var polygons: [(exterior: [CLLocationCoordinate2D], holes: [[CLLocationCoordinate2D]])] = []
        for _ in 0..<count {
            if case .polygon(let exterior, let holes) = try readGeometry() {
                polygons.append((exterior: exterior, holes: holes))
            }
        }
        return polygons
    }

    private mutating func readCollection() throws -> [WKBGeometry] {
        let count = Int(try readUInt32())
        return try (0..<count).map { _ in try readGeometry() }
    }

    // MARK: - Low-level readers

    private mutating func readByte() throws -> UInt8 {
        guard offset < data.count else { throw WKBError.unexpectedEnd }
        defer { offset += 1 }
        return data[offset]
    }

    private mutating func readUInt32() throws -> UInt32 {
        guard offset + 4 <= data.count else { throw WKBError.unexpectedEnd }
        let slice = data[offset..<offset+4]
        offset += 4
        var value: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &value) { slice.copyBytes(to: $0) }
        return littleEndian ? value.littleEndian : value.bigEndian
    }

    private mutating func readDouble() throws -> Double {
        guard offset + 8 <= data.count else { throw WKBError.unexpectedEnd }
        let slice = data[offset..<offset+8]
        offset += 8
        var value: UInt64 = 0
        _ = withUnsafeMutableBytes(of: &value) { slice.copyBytes(to: $0) }
        let bits = littleEndian ? value.littleEndian : value.bigEndian
        return Double(bitPattern: bits)
    }
}

enum WKBError: Error {
    case unexpectedEnd
    case unsupportedType(UInt32)
}

// MARK: - WKBGeometry → MapKit shapes

extension WKBGeometry {
    func toMapKitShapes() -> [MKShape] {
        switch self {
        case .point(let coord):
            let ann = MKPointAnnotation()
            ann.coordinate = coord
            return [ann]

        case .lineString(let coords):
            guard !coords.isEmpty else { return [] }
            return [MKPolyline(coordinates: coords, count: coords.count)]

        case .polygon(let exterior, let holes):
            guard !exterior.isEmpty else { return [] }
            let innerPolygons = holes.filter { !$0.isEmpty }.map {
                MKPolygon(coordinates: $0, count: $0.count)
            }
            return [MKPolygon(coordinates: exterior, count: exterior.count, interiorPolygons: innerPolygons)]

        case .multiPoint(let coords):
            return coords.map {
                let ann = MKPointAnnotation()
                ann.coordinate = $0
                return ann
            }

        case .multiLineString(let lines):
            return lines.filter { !$0.isEmpty }.map {
                MKPolyline(coordinates: $0, count: $0.count)
            }

        case .multiPolygon(let polys):
            return polys.compactMap { (exterior, holes) -> MKPolygon? in
                guard !exterior.isEmpty else { return nil }
                let innerPolygons = holes.filter { !$0.isEmpty }.map {
                    MKPolygon(coordinates: $0, count: $0.count)
                }
                return MKPolygon(coordinates: exterior, count: exterior.count, interiorPolygons: innerPolygons)
            }

        case .collection(let geoms):
            return geoms.flatMap { $0.toMapKitShapes() }
        }
    }

    var boundingRegion: MKCoordinateRegion? {
        let shapes = toMapKitShapes()
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude

        func expand(_ coord: CLLocationCoordinate2D) {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        for shape in shapes {
            if let ann = shape as? MKPointAnnotation {
                expand(ann.coordinate)
            } else if let poly = shape as? MKPolyline {
                poly.points().withMemoryRebound(to: CLLocationCoordinate2D.self, capacity: poly.pointCount) {
                    for i in 0..<poly.pointCount { expand($0[i]) }
                }
            } else if let poly = shape as? MKPolygon {
                poly.points().withMemoryRebound(to: CLLocationCoordinate2D.self, capacity: poly.pointCount) {
                    for i in 0..<poly.pointCount { expand($0[i]) }
                }
            }
        }

        guard minLat < maxLat || minLon < maxLon else { return nil }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.3 + 0.001,
                                    longitudeDelta: (maxLon - minLon) * 1.3 + 0.001)
        return MKCoordinateRegion(center: center, span: span)
    }
}
