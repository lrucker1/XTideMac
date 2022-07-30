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

@interface AppDelegate ()

@property (readwrite, retain) NSArray *stationRefArray;

@end

@implementation AppDelegate


+ (void)initialize
{
    static NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.xtide"];

    libxtide::Global::mutex_init_harmonics();
    RegisterUserDefaults(nil);
    XTSettings_SetDefaults(nil);
    [[XTStationIndex sharedStationIndex] setFavoritesDefaults:defaults];
}

// TODO: Move this to XTStationIndex in both AppDelegates
- (void)loadStationIndexes {
    // loading/processing stations might take a while -- do it in the background.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.stationRefArray = [[XTStationIndex sharedStationIndex] stationRefArray];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:XStationIndexDidLoadNotification object:self];
        });
    });
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self loadStationIndexes];
    return YES;
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
