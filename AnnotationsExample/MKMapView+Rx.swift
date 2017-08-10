//
//  MKMapView+Rx.swift
//  AnnotationsExample
//
//  Created by Mikko Välimäki on 09/08/2017.
//  Copyright © 2017 Mikko Välimäki. All rights reserved.
//

import Foundation
import MapKit
import RxSwift

extension Reactive where Base: MKMapView {
    
    public func annotations<
        A: MKAnnotation,
        O: ObservableType>
        (_ source: O)
        -> Disposable
        where O.E == [A] {
            return self.annotations(dataSource: RxMapViewReactiveDataSource())(source)
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

public protocol RxMapViewDataSourceType {
    
    /// Type of elements that can be bound to table view.
    associatedtype Element
    
    /// New observable sequence event observed.
    ///
    /// - parameter mapView: Bound map view.
    /// - parameter observedEvent: Event
    func mapView(_ mapView: MKMapView, observedEvent: Event<[Element]>) -> Void
}

