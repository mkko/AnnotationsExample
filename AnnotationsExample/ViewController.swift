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

//class City: MKPointAnnotation {
//    
////    let coordinate: CLLocationCoordinate2D
////    
////    let title: String?
////    
////    var subtitle: String? { return "Population \(population)" }
//    
//    let population: Double
//    
//    init(title: String, coordinate: CLLocationCoordinate2D, population: Double) {
//        self.title = title
//        self.coordinate = coordinate
//        self.population = population
//    }
//}

struct Tile {
    let cities: [MKPointAnnotation]
    let overlay: MKOverlay
}

class ViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    
    var regionOverlay = MKPolygon(region: MKCoordinateRegion())
    
    let queue = DispatchQueue(label: "com.mikkovalimaki.MapUpdateQueue")
    
    var grid = MapGrid<Tile>(tileSize: 100000 /* meters */)
    
    var cityMap = MapGrid<[MKPointAnnotation]>(tileSize: 5000)
    
    private var annotationSubscription: Disposable! = nil
    
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        for city in loadCities() {
            let mapIndex = self.cityMap.indexForCoordinate(city.coordinate)
            var tile = self.cityMap[mapIndex] ?? [MKPointAnnotation]()
            tile.append(city)
            self.cityMap[mapIndex] = tile
        }
        
//        annotationSubscription = mapView.rx.regionDidChangeAnimated
//            .map { _ in self.getVisibleRegion(mapView: self.mapView ) }
//            .map { region -> [MKAnnotation] in
//                // Load annotations in given region.
//                return self.cityMap.tiles(atRegion: region).flatMap { $0 }
//            }.bind(to: mapView.rx.annotationsx(dataSource: RxMapViewFadeInOutDataSource()))
        
        annotationSubscription = mapView.rx.regionDidChangeAnimated
            .map { _ in self.getVisibleRegion(mapView: self.mapView ) }
            .map { region -> [MKPointAnnotation] in
                // Load annotations in given region.
                return self.cityMap.tiles(atRegion: region).flatMap { $0 }
            }.bind(to: mapView.rx.annotations)
        
        // Animate new annotations
        mapView.rx.didAddAnnotationViews
        .subscribe { event in
            if case .next(let annotationViews) = event {
                for view in annotationViews {
                    view.alpha = 0.0
                }
                UIView.animate(withDuration: 1.2, animations: {
                    for view in annotationViews {
                        view.alpha = 1.0
                    }
                })
            }
        }.addDisposableTo(disposeBag)
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

func loadCities() -> [MKPointAnnotation] {
    if let path = Bundle.main.path(forResource: "simplemaps-worldcities-basic", ofType: "csv") {
        // Just read the whole chunk, it should be small enough for the example.
        do {
            let data = try String(contentsOfFile: path, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            let cities = lines.flatMap { line -> MKPointAnnotation? in
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
                let a = MKPointAnnotation()//(title: name, coordinate: coord, population: pop)
                a.title = name
                a.coordinate = coord
                a.subtitle = "Population \(pop)"
                return a
            }
            return cities
        } catch {
            print(error)
            abort()
        }
    }
    
    return []
}

public protocol RxMapViewDataSourceType {
    
    /// Type of elements that can be bound to table view.
    associatedtype Element
    
    /// New observable sequence event observed.
    ///
    /// - parameter mapView: Bound map view.
    /// - parameter observedEvent: Event
    func mapView(_ mapView: MKMapView, observedEvent: Event<[Element]>) -> Void
}

extension Reactive where Base: MKMapView {
    
    public func annotations<O: ObservableType>
        (_ source: O)
        -> Disposable
        where O.E == [MKAnnotation] {
            let dataSource = RxMapViewReactiveDataSource()
            return self.annotations(dataSource: dataSource)(source)
    }
    
    public func annotations<
        DataSource: RxMapViewDataSourceType,
        O: ObservableType>
        (dataSource: DataSource)
        -> (_ source: O)
        -> Disposable
        where O.E == [DataSource.Element],
        DataSource.Element: MKAnnotation {
            return { source in
                return source
                    .subscribe({ event in
                        dataSource.mapView(self.base, observedEvent: event)
                    })
            }
    }

    public func annotations<O: ObservableType>
        (fadeDuration: TimeInterval)
        -> (_ source: O)
        -> Disposable
        where O.E == [MKAnnotation] {
            return { source in
                let dataSource = RxMapViewAnimatedDataSource(mapView: self.base, animationDuration: fadeDuration)
                return self.annotations(dataSource: dataSource)(source)
            }
    }
}

extension MKAnnotation {
    func isSame(as another: MKAnnotation) -> Bool {
        return another.coordinate.latitude == self.coordinate.latitude
            && another.coordinate.longitude == self.coordinate.longitude
    }
}

public struct AnnotationDiff {
    let removed: [MKAnnotation]
    let added: [MKAnnotation]
}

func differencesForAnnotations(a: [MKAnnotation], b: [MKAnnotation]) -> AnnotationDiff {
    
    // TODO: Could be improved in performance.
    var remainingItems = Array(b)
    var removedItems = [MKAnnotation]()
    
    // Check the existing ones first.
    for item in a {
        if let index = remainingItems.index(where: item.isSame(as:)) {
            // The item exists still.
            remainingItems.remove(at: index)
        } else {
            // The item doesn't exist, remove it.
            removedItems.append(item)
        }
    }
    
    // Remaining visible indices should be new.
    let newItems = remainingItems
    
    return AnnotationDiff(removed: removedItems, added: newItems)
}

private func areTheSame(_ annotations: [MKAnnotation], _ views: [MKAnnotationView]) -> Bool {
    return !annotations.contains(where: { $0 === views.first?.annotation})
}
