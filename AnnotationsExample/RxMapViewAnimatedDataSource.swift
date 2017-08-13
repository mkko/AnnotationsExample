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
import RxMKMapView

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
                
                let diff = Diff.calculateFrom(
                    previous: self.currentAnnotations,
                    next: newAnnotations)
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
