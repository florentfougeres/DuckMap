import SwiftUI
import MapKit

struct MapView: NSViewRepresentable {
    let shapes: [MKShape]
    var fitRegion: MKCoordinateRegion?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsZoomControls = true
        map.showsCompass = true
        return map
    }

    func updateNSView(_ map: MKMapView, context: Context) {
        map.removeAnnotations(map.annotations)
        map.removeOverlays(map.overlays)

        var annotations: [MKAnnotation] = []
        var overlays: [MKOverlay] = []

        for shape in shapes {
            if let ann = shape as? MKAnnotation {
                annotations.append(ann)
            } else if let overlay = shape as? MKOverlay {
                overlays.append(overlay)
            }
        }

        map.addAnnotations(annotations)
        map.addOverlays(overlays)

        if let region = fitRegion {
            map.setRegion(region, animated: true)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = NSColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 0.85)
                r.lineWidth = 2
                return r
            }
            if let polygon = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: polygon)
                r.fillColor = NSColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 0.25)
                r.strokeColor = NSColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 0.85)
                r.lineWidth = 1.5
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
