//
//  AnnotationDiff.swift
//  RxMKMapView
//
//  Created by Mikko Välimäki on 08/08/2017.
//  Copyright © 2017 RxSwiftCommunity. All rights reserved.
//

import Foundation
import MapKit

public struct Diff {
    
    let removed: [MKAnnotation]
    let added: [MKAnnotation]
}

public extension Diff {

    static func calculateFrom(previous: [MKAnnotation], next: [MKAnnotation]) -> Diff {
        
        // TODO: Could be improved in performance.
        var remainingItems = Array(next)
        var removedItems = [MKAnnotation]()
        
        // Check the existing ones first.
        for item in previous {
            if let index = remainingItems.index(where: { item === $0 }) {
                // The item exists still.
                remainingItems.remove(at: index)
            } else {
                // The item doesn't exist, remove it.
                removedItems.append(item)
            }
        }
        
        // Remaining visible indices should be new.
        let newItems = remainingItems
        
        return Diff(removed: removedItems, added: newItems)
    }

}
