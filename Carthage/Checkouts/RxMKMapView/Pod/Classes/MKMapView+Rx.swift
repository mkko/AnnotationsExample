//
//  MKMapView+Rx.swift
//  RxCocoa
//
//  Created by Spiros Gerokostas on 04/01/16.
//  Copyright © 2016 Spiros Gerokostas. All rights reserved.
//

import MapKit
import RxSwift
import RxCocoa

// Taken from RxCococa until marked as public
func castOrThrow<T>(_ resultType: T.Type, _ object: Any) throws -> T {
    guard let returnValue = object as? T else {
        throw RxCocoaError.castingError(object: object, targetType: resultType)
    }
    return returnValue
}

extension Reactive where Base : MKMapView {

    /**
     Reactive wrapper for `delegate`.

     For more information take a look at `DelegateProxyType` protocol documentation.
     */
    public var delegate: DelegateProxy {
        return RxMKMapViewDelegateProxy.proxyForObject(base)
    }

    // MARK: Responding to Map Position Changes

    public var regionWillChangeAnimated: ControlEvent<Bool> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:regionWillChangeAnimated:)))
            .map { a in
                return try castOrThrow(Bool.self, a[1])
            }
        return ControlEvent(events: source)
    }

    public var regionDidChangeAnimated: ControlEvent<Bool> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:regionDidChangeAnimated:)))
            .map { a in
                return try castOrThrow(Bool.self, a[1])
            }
        return ControlEvent(events: source)
    }

    // MARK: Loading the Map Data

    public var willStartLoadingMap: ControlEvent<Void>{
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapViewWillStartLoadingMap(_:)))
            .map { _ in
                return()
            }
        return ControlEvent(events: source)
    }

    public var didFinishLoadingMap: ControlEvent<Void>{
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapViewDidFinishLoadingMap(_:)))
            .map { _ in
                return()
            }
        return ControlEvent(events: source)
    }

    public var didFailLoadingMap: Observable<NSError>{
        return delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapViewDidFailLoadingMap(_:withError:)))
            .map { a in
                return try castOrThrow(NSError.self, a[1])
            }
    }

    // MARK: Responding to Rendering Events

    public var willStartRenderingMap: ControlEvent<Void>{
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapViewWillStartRenderingMap(_:)))
            .map { _ in
                return()
            }
        return ControlEvent(events: source)
    }

    public var didFinishRenderingMap: ControlEvent<Bool> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapViewDidFinishRenderingMap(_:fullyRendered:)))
            .map { a in
                return try castOrThrow(Bool.self, a[1])
            }
        return ControlEvent(events: source)
    }

    // MARK: Tracking the User Location

    public var willStartLocatingUser: ControlEvent<Void> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapViewWillStartLocatingUser(_:)))
            .map { _ in
                return()
            }
        return ControlEvent(events: source)
    }

    public var didStopLocatingUser: ControlEvent<Void> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapViewDidStopLocatingUser(_:)))
            .map { _ in
                return()
            }
        return ControlEvent(events: source)
    }

    public var didUpdateUserLocation: ControlEvent<MKUserLocation> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:didUpdate:)))
            .map { a in
                return try castOrThrow(MKUserLocation.self, a[1])
            }
        return ControlEvent(events: source)
    }

    public var didFailToLocateUserWithError: Observable<NSError> {
        return delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:didFailToLocateUserWithError:)))
            .map { a in
                return try castOrThrow(NSError.self, a[1])
            }
    }

    public var didChangeUserTrackingMode:
        ControlEvent<(mode: MKUserTrackingMode, animated: Bool)> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:didChange:animated:)))
            .map { a in
                return (mode: try castOrThrow(Int.self, a[1]),
                    animated: try castOrThrow(Bool.self, a[2]))
            }
            .map { (mode, animated) in
                return (mode: MKUserTrackingMode(rawValue: mode)!,
                    animated: animated)
            }
        return ControlEvent(events: source)
    }

    // MARK: Responding to Annotation Views

    public var didAddAnnotationViews: ControlEvent<[MKAnnotationView]> {
        let source = delegate
            .methodInvoked(#selector(
                (MKMapViewDelegate.mapView(_:didAdd:))!
                    as (MKMapViewDelegate) -> (MKMapView, [MKAnnotationView]) -> Void
                )
            )
            .map { a in
                return try castOrThrow([MKAnnotationView].self, a[1])
            }
        return ControlEvent(events: source)
    }

    public var annotationViewCalloutAccessoryControlTapped:
        ControlEvent<(view: MKAnnotationView, control: UIControl)> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:annotationView:calloutAccessoryControlTapped:)))
            .map { a in
                return (view: try castOrThrow(MKAnnotationView.self, a[1]),
                    control: try castOrThrow(UIControl.self, a[2]))
            }
        return ControlEvent(events: source)
    }

    // MARK: Selecting Annotation Views

    public var didSelectAnnotationView: ControlEvent<MKAnnotationView> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:didSelect:)))
            .map { a in
                return try castOrThrow(MKAnnotationView.self, a[1])
            }
        return ControlEvent(events: source)
    }

    public var didDeselectAnnotationView: ControlEvent<MKAnnotationView> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:didDeselect:)))
            .map { a in
                return try castOrThrow(MKAnnotationView.self, a[1])
            }
        return ControlEvent(events: source)
    }

    public var didChangeState:
        ControlEvent<(view: MKAnnotationView, newState: MKAnnotationViewDragState, oldState: MKAnnotationViewDragState)> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:annotationView:didChange:fromOldState:)))
            .map { a in
                return (view: try castOrThrow(MKAnnotationView.self, a[1]),
                    newState: try castOrThrow(UInt.self, a[2]),
                    oldState: try castOrThrow(UInt.self, a[3]))
            }
            .map { (view, newState, oldState) in
                return (view: view,
                    newState: MKAnnotationViewDragState(rawValue: newState)!,
                    oldState: MKAnnotationViewDragState(rawValue: oldState)!)
            }
        return ControlEvent(events: source)
    }

    // MARK: Managing the Display of Overlays

    public var didAddOverlayRenderers: ControlEvent<[MKOverlayRenderer]> {
        let source = delegate
            .methodInvoked(#selector(
                (MKMapViewDelegate.mapView(_:didAdd:))!
                    as (MKMapViewDelegate) -> (MKMapView, [MKOverlayRenderer]) -> Void
                )
            )
            .map { a in
                return try castOrThrow([MKOverlayRenderer].self, a[1])
            }
        return ControlEvent(events: source)
    }
    
    // MARK: Binding annotation to the Map
    
    public func annotations<S: Sequence, O: ObservableType> (_ source: O)
        -> (_ transform: @escaping (S.Iterator.Element) -> MKAnnotation)
        -> Disposable where O.E == S {
            
            return { factory in
                source.map { elements -> [MKAnnotation] in
                    elements.map(factory)
                    }
                    .bind(to: self.annotations)
            }
    }
    
    public func annotations<O: ObservableType> (_ source: O)
        -> Disposable where O.E == [MKAnnotation] {
            let shared = source.share()
            return Observable
                .zip(shared.startWith([]), shared) { ($0, $1) }
                .subscribe(AnyObserver { event in
                    if case let .next(element) = event {
                        let diff = self.diff(a: element.0, b: element.1)
                        print("diff: \(diff)")
                        self.base.removeAnnotations(diff.removedItems)
                        self.base.addAnnotations(diff.newItems)
                    }
                })
    }
    
    struct DiffResult {
        let removedItems: [MKAnnotation]
        let newItems: [MKAnnotation]
    }
    
//    struct BoxedAnnotation {
//        let boxed: MKAnnotation
//    }
    
    func diff(a: [MKAnnotation], b: [MKAnnotation]) -> DiffResult {
        
        // TODO: Could be improved in performance.
        var remainingItems = Array(b) //Set<BoxedAnnotation>(b.map(BoxedAnnotation))
        var existingItems = [MKAnnotation]()
        var removedItems = [MKAnnotation]()
        
        // Check the existing ones first.
        for item in a {
            if let index = remainingItems.index(where: item.isSame(as:)) {
                // The item exists still.
                remainingItems.remove(at: index)
                existingItems.append(item)
            } else {
                // The item doesn't exist, remove it.
                removedItems.append(item)
            }
        }
        
        // Remaining visible indices should be new.
        let newItems = remainingItems
        
        return DiffResult(removedItems: removedItems, newItems: newItems)
    }
    
    /*public func annotations<O: ObservableType> (_ source: O)
        -> Disposable where O.E: MKAnnotation {
            let shared = source.share()
            return Observable
                .zip(shared.startWith(null), shared) { ($0, $1) }
                .subscribe(AnyObserver { event in
                    if case let .next(element) = event {
                        self.base.removeAnnotation(element.0)
                        self.base.addAnnotation(element.1)
                    }
                })
    }*/
}

extension MKAnnotation {
    func isSame(as another: MKAnnotation) -> Bool {
        return another.coordinate.latitude == self.coordinate.latitude
            && another.coordinate.longitude == self.coordinate.longitude
    }
}

