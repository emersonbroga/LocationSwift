//
//  LocationTracker.swift
//  LocationSwift
//
//  Created by Emerson Carvalho on 5/21/15.
//  Copyright (c) 2015 Emerson Carvalho. All rights reserved.
//

import UIKit
import CoreLocation

let LATITUDE = "latitude"
let LONGITUDE = "longitude"
let ACCURACY = "theAccuracy"
let IS_OS_8_OR_LATER : Bool = ( (UIDevice.currentDevice().systemVersion as NSString).floatValue >= 8.0)



class LocationTracker : NSObject, CLLocationManagerDelegate, UIAlertViewDelegate {
    
    var myLastLocation : CLLocationCoordinate2D!
    var myLastLocationAccuracy : CLLocationAccuracy!
    
    var shareModel : LocationShareModel!
    
    var myLocation : CLLocationCoordinate2D!
    var myLocationAcuracy : CLLocationAccuracy!
    var myLocationAltitude : CLLocationDistance!
    
    override init()  {
        super.init()
        self.shareModel = LocationShareModel()
        self.shareModel!.myLocationArray = NSMutableArray()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationEnterBackground", name: UIApplicationDidEnterBackgroundNotification, object: nil)
        
    }
    
    class func sharedLocationManager()-> CLLocationManager! {
        
        struct Static {
            static var _locationManager : CLLocationManager?
        }
        
        objc_sync_enter(self)
        if Static._locationManager == nil {
            Static._locationManager = CLLocationManager()
            Static._locationManager!.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        }
        
        objc_sync_exit(self)
        return Static._locationManager!
    }
    
    // MARK: Application in background
    func applicationEnterBackground() {
        println("applicationEnterBackground")
        var locationManager : CLLocationManager = LocationTracker.sharedLocationManager()!
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.startUpdatingLocation()
        
        self.shareModel!.bgTask = BackgroundTaskManager.sharedBackgroundTaskManager()
        self.shareModel?.bgTask?.beginNewBackgroundTask()
    }
    
    func restartLocationUpdates() {
        print("restartLocationUpdates\n")
        
        if self.shareModel?.timer != nil {
            self.shareModel?.timer?.invalidate()
            self.shareModel!.timer = nil
        }
        
        var locationManager : CLLocationManager = LocationTracker.sharedLocationManager()!
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.startUpdatingLocation()
    }
    
    func startLocationTracking() {
        print("startLocationTracking\n")
        
        if CLLocationManager.locationServicesEnabled() == false {
            print("locationServicesEnabled false\n")
            var servicesDisabledAlert : UIAlertView = UIAlertView(title: "Location Services Disabled", message: "You currently have all location services for this device disabled", delegate: nil, cancelButtonTitle: "OK")
            servicesDisabledAlert.show()
        } else {
            
            
            var authorizationStatus : CLAuthorizationStatus = CLLocationManager.authorizationStatus()
            if (authorizationStatus == CLAuthorizationStatus.Denied) || (authorizationStatus == CLAuthorizationStatus.Restricted) {
                print("authorizationStatus failed")
            } else {
                println("startLocationTracking authorized")
                var locationManager : CLLocationManager = LocationTracker.sharedLocationManager()!
                locationManager.delegate = self
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.distanceFilter = kCLDistanceFilterNone
                if IS_OS_8_OR_LATER {
                    locationManager.requestAlwaysAuthorization()
                }
                locationManager.startUpdatingLocation()
            }
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        print("locationManager didUpdateLocations\n")
        for (var i : Int = 0; i < locations.count; i++) {
            var newLocation : CLLocation! = locations[i] as! CLLocation
            var theLocation : CLLocationCoordinate2D = newLocation.coordinate
            var theAltitude : CLLocationDistance = newLocation.altitude
            var theAccuracy : CLLocationAccuracy = newLocation.horizontalAccuracy
            var locationAge : NSTimeInterval = newLocation.timestamp.timeIntervalSinceNow
            if locationAge > 30.0 {
                continue
            }
            
            // Select only valid location and also location with good accuracy
            if (newLocation != nil) && (theAccuracy > 0) && (theAccuracy < 2000) && !((theLocation.latitude == 0.0) && (theLocation.longitude == 0.0)) {
                
                println("Good location with good accuracy \(theLocation.latitude) & \(theLocation.longitude)")
                
                self.myLastLocation = theLocation
                self.myLastLocationAccuracy = theAccuracy
                
                var dict : NSMutableDictionary = NSMutableDictionary()
                dict.setObject(Float(theLocation.latitude), forKey: "latitude")
                dict.setObject(Float(theLocation.longitude), forKey: "longitude")
                dict.setObject(Float(theAccuracy), forKey: "theAccuracy")
                dict.setObject(Float(theAltitude), forKey: "theAltitude")
                // Add the vallid location with good accuracy into an array
                // Every 1 minute, I will select the best location based on accuracy and send to server
                self.shareModel!.myLocationArray!.addObject(dict)
            }
        }
        // If the timer still valid, return it (Will not run the code below)
        if self.shareModel!.timer != nil {
            return
        }
        
        self.shareModel!.bgTask = BackgroundTaskManager.sharedBackgroundTaskManager()
        self.shareModel!.bgTask!.beginNewBackgroundTask()
        
        // Restart the locationManager after 1 minute
        let restartLocationUpdates : Selector = "restartLocationUpdates"
        self.shareModel!.timer = NSTimer.scheduledTimerWithTimeInterval(60, target: self, selector: restartLocationUpdates, userInfo: nil, repeats: false)
        
        // Will only stop the locationManager after 10 seconds, so that we can get some accurate locations
        // The location manager will only operate for 10 seconds to save battery
        let stopLocationDelayBy10Seconds : Selector = "stopLocationDelayBy10Seconds"
        var delay10Seconds : NSTimer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: stopLocationDelayBy10Seconds, userInfo: nil, repeats: false)
    }
    
    //MARK: Stop the locationManager
    func stopLocationDelayBy10Seconds() {
        var locationManager : CLLocationManager = LocationTracker.sharedLocationManager()!
        locationManager.stopUpdatingLocation()
        print("locationManager stop Updating after 10 seconds\n")
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        
        println("locationManager Error: \(error.localizedDescription)")
        switch (error.code) {
            
            
        case CLError.Network.rawValue:
            println("locationManager Error: Please check your network connection.")
            restartAfterMinutes(1)
            var alert : UIAlertView = UIAlertView(title: "Network Error", message: "Please check your network connection.", delegate: self, cancelButtonTitle: "OK")
            alert.show()
            
            break
        case CLError.Denied.rawValue:
            println("locationManager Error: Please check your network connection.")
            restartAfterMinutes(1)
            var alert : UIAlertView = UIAlertView(title: "Network Error", message: "Please check your network connection.", delegate: self, cancelButtonTitle: "OK")
            alert.show()
            break
        default:
            println("locationManager Error: Uncaught error")
            restartAfterMinutes(1)
            break
        }
        
    }
    
    func restartAfterMinutes(minutes : NSTimeInterval) -> Void {
        
        println("restartAfterMinutes \(minutes)")
        self.shareModel!.bgTask = BackgroundTaskManager.sharedBackgroundTaskManager()
        self.shareModel!.bgTask!.beginNewBackgroundTask()
        
        // Restart the locationManager after 1 minute
        let restartLocationUpdates : Selector = "restartLocationUpdates"
        self.shareModel!.timer = NSTimer.scheduledTimerWithTimeInterval(60 * minutes, target: self, selector: restartLocationUpdates, userInfo: nil, repeats: false)
    
    }
    
    func stopLocationTracking () {
        print("stopLocationTracking\n")
        
        if self.shareModel!.timer != nil {
            self.shareModel!.timer!.invalidate()
            self.shareModel!.timer = nil
        }
        var locationManager : CLLocationManager = LocationTracker.sharedLocationManager()!
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: Update location to server
    func updateLocationToServer() {
       // print("updateLocationToServer\n")
        
        // Find the best location from the array based on accuracy
        var myBestLocation : NSMutableDictionary = NSMutableDictionary()
        
        for (var i : Int = 0 ; i < self.shareModel!.myLocationArray!.count ; i++) {
            var currentLocation : NSMutableDictionary = self.shareModel!.myLocationArray!.objectAtIndex(i) as! NSMutableDictionary
            if i == 0 {
                myBestLocation = currentLocation
            } else {
                if (currentLocation.objectForKey(ACCURACY) as! Float) <= (myBestLocation.objectForKey(ACCURACY) as! Float) {
                    myBestLocation = currentLocation
                }
            }
        }
        //print("My Best location \(myBestLocation)\n")
        
        // If the array is 0, get the last location
        // Sometimes due to network issue or unknown reason,
        // you could not get the location during that period, the best you can do is
        // sending the last known location to the server
        
        if self.shareModel!.myLocationArray!.count == 0 {
            print("Unable to get location, use the last known location\n")
            self.myLocation = self.myLastLocation
            self.myLocationAcuracy = self.myLastLocationAccuracy
        } else {
            var lat : CLLocationDegrees = myBestLocation.objectForKey(LATITUDE) as! CLLocationDegrees
            var lon : CLLocationDegrees = myBestLocation.objectForKey(LONGITUDE) as! CLLocationDegrees
            var theBestLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            self.myLocation = theBestLocation
            self.myLocationAcuracy = myBestLocation.objectForKey(ACCURACY) as! CLLocationAccuracy!
        }
        print("Send to server: latitude \(self.myLocation.latitude) longitude \(self.myLocation?.longitude) accuracy \(self.myLocationAcuracy)\n")
        
        //TODO: Your code to send the self.myLocation and self.myLocationAccuracy to your server
        
        // After sending the location to the server successful,
        // remember to clear the current array with the following code. It is to make sure that you clear up old location in the array
        // and add the new locations from locationManager
        
        self.shareModel!.myLocationArray!.removeAllObjects()
        self.shareModel!.myLocationArray = nil
        self.shareModel!.myLocationArray = NSMutableArray()
    }
    
    func getBestLocationForServer() -> NSDictionary? {
        print("getBestLocationForServer\n")
        
        // Find the best location from the array based on accuracy
        var myBestLocation : NSMutableDictionary = NSMutableDictionary()
        
        for (var i : Int = 0 ; i < self.shareModel!.myLocationArray!.count ; i++) {
            var currentLocation : NSMutableDictionary = self.shareModel!.myLocationArray!.objectAtIndex(i) as! NSMutableDictionary
            if i == 0 {
                myBestLocation = currentLocation
            } else {
                if (currentLocation.objectForKey(ACCURACY) as! Float) <= (myBestLocation.objectForKey(ACCURACY) as! Float) {
                    myBestLocation = currentLocation
                }
            }
        }
        print("My Best location \(myBestLocation)\n")
        
        // If the array is 0, get the last location
        // Sometimes due to network issue or unknown reason,
        // you could not get the location during that period, the best you can do is
        // sending the last known location to the server
        
        if self.shareModel!.myLocationArray!.count == 0 {
            print("Unable to get location, use the last known location\n")
            self.myLocation = self.myLastLocation
            self.myLocationAcuracy = self.myLastLocationAccuracy
        } else {
            var lat : CLLocationDegrees = myBestLocation.objectForKey(LATITUDE) as! CLLocationDegrees
            var lon : CLLocationDegrees = myBestLocation.objectForKey(LONGITUDE) as! CLLocationDegrees
            var theBestLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            self.myLocation = theBestLocation
            
            self.myLocationAcuracy = myBestLocation.objectForKey(ACCURACY) as! CLLocationAccuracy!
        }
        
        var returnType : NSMutableDictionary = NSMutableDictionary()
        returnType.setValue(self.myLocation.latitude, forKey: "lat")
        returnType.setValue(self.myLocation.longitude, forKey: "lon")
        returnType.setValue(self.myLocationAcuracy, forKey: "acc")
        
        
        print("Send to server: latitude \(self.myLocation.latitude) longitude \(self.myLocation.longitude) accuracy \(self.myLocationAcuracy)\n")
        
        //TODO: Your code to send the self.myLocation and self.myLocationAccuracy to your server
        
      
        // After sending the location to the server successful,
        // remember to clear the current array with the following code. It is to make sure that you clear up old location in the array
        // and add the new locations from locationManager
        
        self.shareModel!.myLocationArray!.removeAllObjects()
        self.shareModel!.myLocationArray = nil
        self.shareModel!.myLocationArray = NSMutableArray()
        return returnType
    }
    
}














