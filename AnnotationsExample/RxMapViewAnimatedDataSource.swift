//
//  RxMapViewAnimatedDataSource.swift
//  AnnotationsExample
//
//  Created by Mikko Välimäki on 09/08/2017.
//  Copyright © 2017 Mikko Välimäki. All rights reserved.
//

import Foundation
import MapKit
import RxSwift
import RxCocoa

let defaultDuration: TimeInterval = 0.2

public class RxMapViewAnimatedDataSource: RxMapViewDataSourceType {
    
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
        UIBindingObserver(UIElement: self) { (dataSource, newAnnotations) in
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
