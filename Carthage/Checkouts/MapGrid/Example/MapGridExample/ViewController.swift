//
//  ViewController.swift
//  MapGridExample
//
//  Created by Mikko Välimäki on 17-05-15.
//  Copyright © 2017 Mikko Välimäki. All rights reserved.
//

import UIKit
import MapKit
import MapGrid

// Turn this on if you want compare to displaying all annotations
// on the map at once. Makes a bigger difference with more annotations.
let GRID_BASED_LOADING = true

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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !GRID_BASED_LOADING {
            mapView.addAnnotations(loadCities())
        } else {
            for city in loadCities() {
                let mapIndex = self.cityMap.indexForCoordinate(city.coordinate)
                var tile = self.cityMap[mapIndex] ?? [City]()
                tile.append(city)
                self.cityMap[mapIndex] = tile
            }
        }
    }
}

extension ViewController: MKMapViewDelegate {
    
    private func createTile(mapIndex: MapIndex, mapGrid: MapGrid<Tile>) -> Tile {
        let region = mapGrid.region(at: mapIndex)
        let cities = self.cityMap.tiles(atRegion: region).flatMap { $0 }
        return Tile(cities: cities, overlay: MKPolygon(region: region))
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        if !GRID_BASED_LOADING {
            return
        }
        
        let visibleRegion = getVisibleRegion(mapView: mapView)
        
        mapView.remove(regionOverlay)
        self.regionOverlay = MKPolygon(region: visibleRegion)
        mapView.add(regionOverlay)
        
        // Crop and fill the grid.
        
        let removedTiles = grid.crop(toRegion: visibleRegion)
        let newTiles = grid.fill(toRegion: visibleRegion, newTile: self.createTile)

        print("update: +\(newTiles.count) -\(removedTiles.count)")

        // Update the map.
        
        mapView.addAnnotations(newTiles.flatMap { $0.item.cities })
        mapView.removeAnnotations(removedTiles.flatMap { $0.item.cities })
        
        mapView.addOverlays(newTiles.map { $0.item.overlay })
        mapView.removeOverlays(removedTiles.map { $0.item.overlay })
    }
    
    func getVisibleRegion(mapView: MKMapView) -> MKCoordinateRegion {
        return mapView.zoomLevel > 13
            ? MKCoordinateRegion()
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
