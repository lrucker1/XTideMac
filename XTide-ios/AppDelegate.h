//
//  AppDelegate.h
//  XTide-ios
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * XTideMapsLoadedNotification;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (readonly, retain) NSArray *stationRefArray;


@end

