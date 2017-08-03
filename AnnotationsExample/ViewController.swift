//
//  ViewController.swift
//  AnnotationsExample
//
//  Created by Mikko Välimäki on 23/07/2017.
//  Copyright © 2017 Mikko Välimäki. All rights reserved.
//

import UIKit
import MapKit
import MapGrid
import RxMKMapView
import RxSwift
import RxCocoa

class City: NSObject, MKAnnotation {
    
    let coordinate: CLLocationCoordinate2D
    
    let title: String?
    
    var subtitle: String? { return "Population \(population)" }
    
    let population: Double
    
    init(title: String, coordinate: CLLocationCoordinate2D, population: Double) {
        self.title = title
        self.coordinate = coordinate
        self.population = population
    }
}

struct Tile {
    let cities: [City]
    let overlay: MKOverlay
}

class ViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    
    var regionOverlay = MKPolygon(region: MKCoordinateRegion())
    
    let queue = DispatchQueue(label: "com.mikkovalimaki.MapUpdateQueue")
    
    var grid = MapGrid<Tile>(tileSize: 100000 /* meters */)
    
    var cityMap = MapGrid<[City]>(tileSize: 5000)
    
    private var annotationSubscription: Disposable! = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        for city in loadCities() {
            let mapIndex = self.cityMap.indexForCoordinate(city.coordinate)
            var tile = self.cityMap[mapIndex] ?? [City]()
            tile.append(city)
            self.cityMap[mapIndex] = tile
        }
        
//        let x = UILabel()
//        x.rx.text
        
        //let annotations = mapView.rxAnnotations.configure()

//        let x = self.annotations(handler: { diff in
//            self.base.removeAnnotations(diff.removed)
//            self.base.addAnnotations(diff.added)
//        })
        
        annotationSubscription = mapView.rx.regionDidChangeAnimated
            .map { _ in self.getVisibleRegion(mapView: self.mapView ) }
            .map { region -> [MKAnnotation] in
                // Load annotations in given region.
                return self.cityMap.tiles(atRegion: region).flatMap { $0 }
            }.bind(to: mapView.rx.annotations(animation: .fadeInFadeOut(duration: 0.2)))
    }
}

extension ViewController: MKMapViewDelegate {
        
    func getVisibleRegion(mapView: MKMapView) -> MKCoordinateRegion {
        return mapView.zoomLevel > 13
            ? MKCoordinateRegion()
//            : mapView.region
            : MKCoordinateRegion(
                center: mapView.region.center,
                span: MKCoordinateSpan(
                    latitudeDelta: mapView.region.span.latitudeDelta / 2.0,
                    longitudeDelta: mapView.region.span.longitudeDelta / 2.0))
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolygonRenderer(overlay: overlay)
        renderer.strokeColor = UIColor.magenta
        renderer.fillColor = UIColor.magenta.withAlphaComponent(0.3)
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        let reuseID = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            pinView!.canShowCallout = true
            //pinView!.animatesDrop = true
        }
        return pinView
    }
}

extension MKCoordinateRegion {
    
    var bounds: (nw: CLLocationCoordinate2D, ne: CLLocationCoordinate2D, se: CLLocationCoordinate2D, sw: CLLocationCoordinate2D) {
        let nw = CLLocationCoordinate2D(
            latitude: self.center.latitude + self.span.latitudeDelta / 2.0,
            longitude: self.center.longitude - self.span.longitudeDelta / 2.0)
        let ne = CLLocationCoordinate2D(
            latitude: self.center.latitude + self.span.latitudeDelta / 2.0,
            longitude: self.center.longitude + self.span.longitudeDelta / 2.0)
        let se = CLLocationCoordinate2D(
            latitude: self.center.latitude - self.span.latitudeDelta / 2.0,
            longitude: self.center.longitude + self.span.longitudeDelta / 2.0)
        let sw = CLLocationCoordinate2D(
            latitude: self.center.latitude - self.span.latitudeDelta / 2.0,
            longitude: self.center.longitude - self.span.longitudeDelta / 2.0)
        return (nw, ne, se, sw)
    }
}

extension MKPolygon {
    
    convenience init(region: MKCoordinateRegion) {
        let bounds = region.bounds
        var coordinates = [bounds.nw, bounds.ne, bounds.se, bounds.sw]
        self.init(coordinates: &coordinates, count: coordinates.count)
    }
}

extension MKMapView {
    
    var zoomLevel: Int {
        return Int(log2(self.visibleMapRect.size.width)) - 9
    }
}

func loadCities() -> [City] {
    if let path = Bundle.main.path(forResource: "simplemaps-worldcities-basic", ofType: "csv") {
        // Just read the whole chunk, it should be small enough for the example.
        do {
            let data = try String(contentsOfFile: path, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            let cities = lines.flatMap { line -> City? in
                let csv = line.components(separatedBy: ",")
                guard csv.count > 3,
                    let lat = Double(csv[2]),
                    let lon = Double(csv[3]),
                    let pop = Double(csv[4]) else {
                        print("WARNING: Skipping line: \(line)")
                        return nil
                }
                let name = csv[0]
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                return City(title: name, coordinate: coord, population: pop)
            }
            return cities
        } catch {
            print(error)
            abort()
        }
    }
    
    return []
}

public enum AnnotationAnimationType {
    case noAnimation
    case fadeInFadeOut(duration: TimeInterval)
    // TODO: case custom(MKMapView, AnnotationDiff)
    
    func act(mapView: MKMapView, diff: AnnotationDiff) {
        switch self {
        case .noAnimation:
            mapView.removeAnnotations(diff.removed)
            mapView.addAnnotations(diff.added)
        case .fadeInFadeOut(let duration):
            mapView.removeAnnotations(diff.removed, animationDuration: duration)
            mapView.addAnnotations(diff.added, animationDuration: duration)
        }
    }
}

public struct AnnotationDiff {
    let removed: [MKAnnotation]
    let added: [MKAnnotation]
}

extension Reactive where Base: MKMapView {
    
    public func annotations<O: ObservableType>(animation: AnnotationAnimationType = .noAnimation) -> (_ source: O)
        -> Disposable where O.E == [MKAnnotation] {
            return { source in
                let shared = source.share()
                return Observable
                    .zip(shared.startWith([]), shared) { ($0, $1) }
                    .subscribe(AnyObserver { event in
                        if case let .next(element) = event {
                            let diff = self.diff(a: element.0, b: element.1)
                            //print("diff: \(diff)")
                            animation.act(mapView: self.base, diff: diff)
                        }
                    })
            }
    }
    
    
    func diff(a: [MKAnnotation], b: [MKAnnotation]) -> AnnotationDiff {
        
        // TODO: Could be improved in performance.
        var remainingItems = Array(b) //Set<BoxedAnnotation>(b.map(BoxedAnnotation))
        //var existingItems = [MKAnnotation]()
        var removedItems = [MKAnnotation]()
        
        // Check the existing ones first.
        for item in a {
            if let index = remainingItems.index(where: item.isSame(as:)) {
                // The item exists still.
                remainingItems.remove(at: index)
                //existingItems.append(item)
            } else {
                // The item doesn't exist, remove it.
                removedItems.append(item)
            }
        }
        
        // Remaining visible indices should be new.
        let newItems = remainingItems
        
        return AnnotationDiff(removed: removedItems, added: newItems)
    }
}

extension MKAnnotation {
    func isSame(as another: MKAnnotation) -> Bool {
        return another.coordinate.latitude == self.coordinate.latitude
            && another.coordinate.longitude == self.coordinate.longitude
    }
}

extension MKMapView {
    
    func removeAnnotations(_ annotations: [MKAnnotation], animationDuration: TimeInterval) {
        UIView.animate(withDuration: animationDuration, animations: {
            for view in annotations.flatMap(self.view(for:)) {
                view.alpha = 0.0
            }
        }, completion: { _ in
            self.removeAnnotations(annotations)
        })
    }

    func addAnnotations(_ annotations: [MKAnnotation], animationDuration: TimeInterval) {
        self.addAnnotations(annotations) { views in
            for view in views {
                view.alpha = 0.0
            }
            UIView.animate(withDuration: animationDuration, animations: {
                for view in views {
                    view.alpha = 1.0
                }
            })
        }
    }
    
    func addAnnotations(_ annotations: [MKAnnotation], callback: @escaping ([MKAnnotationView]) -> ()) {
        // Subscribe to the next mapView(_:didAdd:) to get the added views.
        let _ = self.rx.didAddAnnotationViews
            .filter { areTheSame(annotations, $0) }
            .take(1)
            .subscribe { event in
                if case .next(let e) = event {
                    callback(e)
                }
        }
        self.addAnnotations(annotations)
    }
}

private func areTheSame(_ annotations: [MKAnnotation], _ views: [MKAnnotationView]) -> Bool {
    return !annotations.contains(where: { $0 === views.first?.annotation})
}
