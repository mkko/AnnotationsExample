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
        
//        annotationSubscription = mapView.rx.regionDidChangeAnimated
//            .map { _ in self.getVisibleRegion(mapView: self.mapView ) }
//            .map { region -> [MKAnnotation] in
//                // Load annotations in given region.
//                return self.cityMap.tiles(atRegion: region).flatMap { $0 }
//            }.bind(to: mapView.rx.annotationsx(animator: RxMapViewFadeInOutAnimator()))
        
        annotationSubscription = mapView.rx.regionDidChangeAnimated
            .map { _ in self.getVisibleRegion(mapView: self.mapView ) }
            .map { region -> [MKAnnotation] in
                // Load annotations in given region.
                return self.cityMap.tiles(atRegion: region).flatMap { $0 }
            }.bind(to: mapView.rx.annotations(fadeDuration: 1.2))
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

public protocol RxMapViewAnimatorType {
    
    /// Type of elements that can be bound to table view.
    associatedtype Element
    
    /// New observable sequence event observed.
    ///
    /// - parameter mapView: Bound map view.
    /// - parameter observedEvent: Event
    func mapView(_ mapView: MKMapView, observedEvent: Event<[Element]>) -> Void
}

let defaultDuration: TimeInterval = 0.2

public class RxMapViewFadeInOutAnimator: RxMapViewAnimatorType {
    
    public typealias Element = MKAnnotation
    
    let duration: TimeInterval
    
    var currentAnnotations: [MKAnnotation] = []
    
    let disposeBag = DisposeBag()
    
    init(mapView: MKMapView, animationDuration duration: TimeInterval = defaultDuration) {
        self.duration = duration
        mapView.rx.didAddAnnotationViews
            .subscribe { event in
                if case .next(let annotations) = event {
                    let newAnnotations = annotations.filter(self.shouldAnimate(annotation:))
                    self.animateNew(views: newAnnotations)
                }
            }.addDisposableTo(disposeBag)
    }
    
    public func mapView(_ mapView: MKMapView, observedEvent: Event<[MKAnnotation]>) {
        UIBindingObserver(UIElement: self) { (animator, newAnnotations) in
            DispatchQueue.main.async {
                
                let diff = differencesForAnnotations(a: self.currentAnnotations, b: newAnnotations)
                self.currentAnnotations = newAnnotations
                
                // The subscription is used to animate new annotations. The removal can be animated in place.
                self.removeAnnotations(diff.removed, mapView: mapView, animationDuration: self.duration)
                mapView.addAnnotations(diff.added)
            }
        }.on(observedEvent)
    }
    
    private func shouldAnimate(annotation: MKAnnotationView) -> Bool {
        return true
    }
    
    private func animateNew(views: [MKAnnotationView]) {
        for view in views {
            view.alpha = 0.0
        }
        UIView.animate(withDuration: self.duration, animations: {
            for view in views {
                view.alpha = 1.0
            }
        })
    }
    
    func removeAnnotations(_ annotations: [MKAnnotation], mapView: MKMapView, animationDuration: TimeInterval) {
        UIView.animate(withDuration: animationDuration, animations: {
            for view in annotations.flatMap(mapView.view(for:)) {
                view.alpha = 0.0
            }
        }, completion: { _ in
            mapView.removeAnnotations(annotations)
        })
    }
}

extension Reactive where Base: MKMapView {
    
    public func annotations<O: ObservableType>
        (fadeDuration: TimeInterval)
        -> (_ source: O)
        -> Disposable
        where O.E == [MKAnnotation] {
            return { source in
                let animator = RxMapViewFadeInOutAnimator(mapView: self.base, animationDuration: fadeDuration)
                return self.annotations(animator: animator)(source)
            }
    }
    
    public func annotations<
            Animator: RxMapViewAnimatorType,
            O: ObservableType>
            (animator: Animator)
            -> (_ source: O)
            -> Disposable
        where O.E == [Animator.Element],
        Animator.Element: MKAnnotation {
                return { source in
                    return source
                        .subscribe({ event in
                            animator.mapView(self.base, observedEvent: event)
                        })
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
