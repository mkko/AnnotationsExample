//
//  AnnotationDiff.swift
//  AnnotationsExample
//
//  Created by Mikko Välimäki on 10/08/2017.
//  Copyright © 2017 Mikko Välimäki. All rights reserved.
//

import Foundation
import MapKit
import RxSwift
import RxCocoa

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
    
    return AnnotationDiff(removed: removedItems, added: newItems)
}
