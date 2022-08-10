//
//  RootViewController.h
//  XTide-ios
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface XTUIMapViewController : UIViewController  <MKMapViewDelegate>

@property (nonatomic, strong) IBOutlet MKMapView *mapView;

@end

