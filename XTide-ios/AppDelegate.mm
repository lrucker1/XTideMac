//
//  AppDelegate.m
//  XTide-ios
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "AppDelegate.h"
#import "libxtide.hh"
#import "XTSettings.h"
#import "XTStationIndex.h"
#import "XTStationRef.h"
#import "XTStation.h"
#import "XTTideEventsOrganizer.h"
#import "UIKitAdditions.h"

#define DEBUG_EVENTS 0

NSString * XTideMapsLoadedNotification = @"XTideMapsLoadedNotification";

@interface AppDelegate ()

@property (readwrite, retain) NSArray *stationRefArray;
@property (strong) CLLocationManager *locationManager;
@property (nonatomic) WCSession* watchSession;

@end

@implementation AppDelegate


+ (void)initialize
{
   libxtide::Global::settings.setMacDefaults();
   libxtide::Global::settings.applyMacResources();
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.locationManager = [[CLLocationManager alloc] init];
    [self.locationManager requestWhenInUseAuthorization];

    // loading/processing stations might take a while -- do it asynchronously
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.stationRefArray = [[XTStationIndex sharedStationIndex] stationRefArray];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XTideMapsLoadedNotification object:self];
            [self configureWatch];
        });
    });

     return YES;
}

- (void)configureWatch
{
#if DEBUG_EVENTS
    XTStationIndex *stationIndex = [XTStationIndex sharedStationIndex];
    XTStationRef *ref = [[stationIndex favoriteStationRefs] firstObject];
    XTStation *station = [ref loadStation];
    if (station) {
        NSArray *angles = [station generateWatchEventsStart:[NSDate date] end:[NSDate dateWithTimeIntervalSinceNow:60*60*24]];
        NSLog(@"%@", angles);
    }
#endif
    if (![WCSession isSupported]) {
        return;
    }
    self.watchSession = [WCSession defaultSession];
    self.watchSession.delegate = self;
    [self.watchSession activateSession];
//    [self updateWatchImage];
}

- (NSData *)clockImageDataWithWidth:(CGFloat)width height:(CGFloat)height scale:(CGFloat)scale
{
    if (!self.watchSession) {
        return nil;
    }
    XTStationIndex *stationIndex = [XTStationIndex sharedStationIndex];
    XTStationRef *ref = [[stationIndex favoriteStationRefs] firstObject];
    XTStation *station = [ref loadStation];
    if (!station) {
        return nil;
    }
    UIImage *image = [station clockImageWithXSize:width
                                            ysize:height
                                            scale:scale];
    return UIImageJPEGRepresentation(image, 1.0);
}

- (void)updateWatchImage
{
    NSData *data = [self clockImageDataWithWidth:200 height:200 scale:2];
    if (!data) {
        return;
    }
    
    NSError *error = nil;
    if (![self.watchSession updateApplicationContext:@{@"clockImage" : data }
                                               error:&error]) {
        NSLog(@"Updating the context failed: %@", error.localizedDescription);
    }
}


- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *,id> *)message replyHandler:(void (^)(NSDictionary<NSString *,id> *replyMessage))replyHandler
{
    NSString *kind = [message objectForKey:@"kind"];
    if ([kind isEqualToString:@"requestImage"]) {
        CGFloat width = [[message objectForKey:@"width"] floatValue];
        CGFloat height = [[message objectForKey:@"height"] floatValue];
        CGFloat scale = [[message objectForKey:@"scale"] floatValue];
        if (scale == 0) scale = 1;
        if (width > 0 && height > 0) {
            NSData *data = [self clockImageDataWithWidth:width height:height scale:scale];
            if (data) {
                replyHandler( @{@"clockImage" : data } );
            }
        }
    } else if ([kind isEqualToString:@"requestEvents"]) {
        XTStationIndex *stationIndex = [XTStationIndex sharedStationIndex];
        XTStationRef *ref = [[stationIndex favoriteStationRefs] firstObject];
        XTStation *station = [ref loadStation];
        if (!station) {
            return;
        }
        NSDate *first = [message objectForKey:@"first"];
        NSDate *last = [message objectForKey:@"last"];
        if (first && last) {
            NSArray *events = [station generateWatchEventsStart:first end:last];
            replyHandler( @{@"events":events} );
        }
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
