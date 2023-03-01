//
//  AppDelegate.h
//  XTide-ios
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WatchConnectivity/WatchConnectivity.h>
#import <CoreLocation/CoreLocation.h>


@interface AppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate, WCSessionDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (readonly, retain) NSArray *stationRefArray;

- (void)loadStationIndexes;
- (void)addHarmonicsFiles:(NSArray *)urls;

@end

