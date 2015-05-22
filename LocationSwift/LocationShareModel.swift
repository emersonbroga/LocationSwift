//
//  LocationShareModel.swift
//  LocationSwift
//
//  Created by Emerson Carvalho on 5/21/15.
//  Copyright (c) 2015 Emerson Carvalho. All rights reserved.
//

import Foundation
import UIKit

class LocationShareModel : NSObject {
    var timer : NSTimer?
    var bgTask : BackgroundTaskManager?
    var myLocationArray : NSMutableArray?
    
    func sharedModel()-> AnyObject {
        struct Static {
            static var sharedMyModel : AnyObject?
            static var onceToken : dispatch_once_t = 0
        }
        dispatch_once(&Static.onceToken) {
            Static.sharedMyModel = LocationShareModel()
        }
        return Static.sharedMyModel!
    }
}