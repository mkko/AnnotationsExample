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
        
        let annotation1 = MKPointAnnotation()
        annotation1.title = "title1"
        annotation1.subtitle = "subtitle1"
        annotation1.coordinate = CLLocationCoordinate2D(latitude: 0.1, longitude: 0.1)
        
        let annotation2 = MKPointAnnotation()
        annotation2.title = "title2"
        annotation2.subtitle = "subtitle2"
        annotation2.coordinate = CLLocationCoordinate2D(latitude: 1, longitude: 1)
        
        let annotations = [annotation1, annotation2]
        
        _ = Observable.from(annotations)
            .bind(to: mapView.rx.annotations)

        _ = Observable.from(annotations)
            .subscribe(onNext: {self.mapView.addAnnotation($0)})
        
//        annotationSubscription = mapView.rx.regionDidChangeAnimated
//            .map { _ in self.getVisibleRegion(mapView: self.mapView ) }
//            .map { region -> [MKPointAnnotation] in
//                // Load annotations in given region.
//                return self.cityMap.tiles(atRegion: region).flatMap { $0 }
//            }.bind(to: mapView.rx.annotations)
//        
//        // Animate new annotations
//        mapView.rx.didAddAnnotationViews
//        .subscribe { event in
//            if case .next(let annotationViews) = event {
//                for view in annotationViews {
//                    view.alpha = 0.0
//                }
//                UIView.animate(withDuration: 1.2, animations: {
//                    for view in annotationViews {
//                        view.alpha = 1.0
//                    }
//                })
//            }
//        }.addDisposableTo(disposeBag)
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
