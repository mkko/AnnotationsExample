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

class ViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
        
    let queue = DispatchQueue(label: "com.mikkovalimaki.MapUpdateQueue")
    
    var cityMap = MapGrid<[MKPointAnnotation]>(tileSize: 5000)
    
    private var annotationSubscription: Disposable! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for city in loadCities() {
            let mapIndex = self.cityMap.indexForCoordinate(city.coordinate)
            var tile = self.cityMap[mapIndex] ?? [MKPointAnnotation]()
            tile.append(city)
            self.cityMap[mapIndex] = tile
        }
        
        annotationSubscription = mapView.rx.regionDidChangeAnimated
            .map { _ in self.getVisibleRegion(mapView: self.mapView ) }
            .map { region -> [MKAnnotation] in
                // Load annotations in given region.
                return self.cityMap.tiles(atRegion: region).flatMap { $0 }
            }.bind(to: mapView.rx.annotations)
    }
}

extension ViewController: MKMapViewDelegate {
        
    func getVisibleRegion(mapView: MKMapView) -> MKCoordinateRegion {
        return mapView.zoomLevel > 13
            ? MKCoordinateRegion()
            : mapView.region
//            : MKCoordinateRegion(
//                center: mapView.region.center,
//                span: MKCoordinateSpan(
//                    latitudeDelta: mapView.region.span.latitudeDelta / 2.0,
//                    longitudeDelta: mapView.region.span.longitudeDelta / 2.0))
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
