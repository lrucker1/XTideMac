//
//  AppDelegate.m
//  XTide-ios
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "AppDelegate.h"
#import "libxtide.hh"
#import "XTSettings.h"
#import "XTStation.h"
#import "XTStationRef.h"
#import "XTStationIndex.h"

static const CLLocationDistance kUserLocMovement = 5000; // meters

@interface AppDelegate ()

@property (readwrite, retain) NSArray *stationRefArray;
@property (nonatomic) WCSession *watchSession;
@property (strong) CLLocationManager *locationManager;
@property (strong) XTStationRef *stationRefForWatch;
@property BOOL didShowWatchLocationAlert;
@property BOOL canTrackLocation;

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
    self.locationManager = [[CLLocationManager alloc] init];
    [self.locationManager setDelegate:self];
    CLAuthorizationStatus status = [self.locationManager authorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
    } else if (  status == kCLAuthorizationStatusAuthorizedWhenInUse
               || status == kCLAuthorizationStatusAuthorizedAlways) {
        self.canTrackLocation = YES;
    }
    self.locationManager.distanceFilter = kUserLocMovement;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
    [self configureWatch];
    //[self.locationManager allowDeferredLocationUpdatesUntilTraveled:kUserLocMovement timeout:CLTimeIntervalMax];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(defaultsChanged:)
                                                 name:XTStationIndexFavoritesChangedNotification
                                               object:nil];
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

- (BOOL)application:(UIApplication *)application openURL:(nonnull NSURL *)url options:(nonnull NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    if ([[url pathExtension] isEqualToString:@"tcd"]) {
        [self addHarmonicsFiles:@[url]];
        return YES;
    }
    return NO;
}

- (void)addHarmonicsFiles:(NSArray *)urls {
    NSMutableArray *array = [NSMutableArray array];
    for (NSURL *url in urls) {
        if (url) {
            NSData *bookmarkData = [url bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark
                                 includingResourceValuesForKeys:nil
                                                  relativeToURL:nil
                                                          error:NULL];
            if (bookmarkData) {
                [array addObject:bookmarkData];
            }
        }
    }
    [XTSettings_GetUserDefaults() setObject:array forKey:XTide_harmonicsFiles];
    [[XTStationIndex sharedStationIndex] reloadHarmonicsFiles];
    [self loadStationIndexes];
}

- (void)defaultsChanged:(NSNotification *)notification
{
    // Update this first in case stationRefForWatch is changing.
    [self updateWatchState];
}


- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
{
    CLAuthorizationStatus status = [self.locationManager authorizationStatus];
    if (  status == kCLAuthorizationStatusAuthorizedWhenInUse
        || status == kCLAuthorizationStatusAuthorizedAlways) {
        self.canTrackLocation = YES;
        [self configureLocationTrackingForWatch];
        [self updateWatchState];
    } else {
        self.canTrackLocation = NO;
        [self.locationManager stopUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    [self updateWatchState];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"locationManager:didFailWithError: %@", error);
}

#pragma mark watch session

- (void)sessionReachabilityDidChange:(WCSession *)session
{
    // We only care about location when the watch is using it.
    [self configureLocationTrackingForWatch];
}

- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(NSError *)error
{
    if (activationState == WCSessionActivationStateActivated) {
        [self configureLocationTrackingForWatch];
    }
}

- (void)sessionDidBecomeInactive:(WCSession *)session
{
    [self.locationManager stopUpdatingLocation];
}

- (void)sessionDidDeactivate:(WCSession *)session
{
    [self.locationManager stopUpdatingLocation];
}

#pragma mark watch

- (void)showWatchNeedsLocationAlert
{
    if (self.didShowWatchLocationAlert) {
        return;
    }
    // We may reset this after a certain time.
    //
    self.didShowWatchLocationAlert = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Watch needs station", @"No station error title")
                                       message:NSLocalizedString(@"The watch cannot find a station to display. Mark a station as favorite.", @"No station error message")
                                       preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleDefault
           handler:^(UIAlertAction * action) {}];

        [alert addAction:defaultAction];
        UIViewController *topViewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];

        [topViewController presentViewController:alert animated:YES completion:nil];
    });
}

/*
 * First option: closest favorite station. Update whenever location changes.
 * Second option: closest ref station. Update when the user location has moved more than
 *  a distance that's kind of arbitrary.
 * If there's no location services, pick the first favorite.
 * If that fails, either pick the nearest ref station, or we'll show showWatchNeedsLocationAlert when the watch asks for data.
 * Choosing the station seems fast enough, but we can still fail to have a favorite on the Today or Watch
 * if those run before this does.
 */
- (XTStationRef *)findClosestStationRef
{
    XTStationIndex *stationIndex = [XTStationIndex sharedStationIndex];
    NSAssert(self.locationManager, @"Calling this too soon!");
    CLLocation *userLoc = self.locationManager.location;
    if (!userLoc) {
        XTStationRef *ref = [[stationIndex favoriteStationRefs] firstObject];
        [stationIndex saveClosestFavorite:ref];
        return ref;
    }

    XTStationRef *ref = [stationIndex favoriteNearestLocation:userLoc];
    if (!ref) {
        // If we just de-fav'd it, we might still keep using it if we haven't moved.
        ref = self.stationRefForWatch;
        BOOL doUpdate = YES;
        // If we had one, has the user moved very far from it?
        if (ref) {
            CLLocationCoordinate2D coord = ref.coordinate;
            CLLocation *loc = [[CLLocation alloc] initWithLatitude:coord.latitude longitude:coord.longitude];
            CLLocationDistance deltaMeters = [loc distanceFromLocation:userLoc];
            doUpdate = (deltaMeters > kUserLocMovement);
        }
        if (doUpdate) {
            ref = [stationIndex stationRefNearestLocation:userLoc inStations:self.stationRefArray];
        }
    }
    [stationIndex saveClosestFavorite:ref];
    return ref;
}

// The map does its own thing; this is for us to get delegate methods.
// Only the watch needs them.
- (void)configureLocationTrackingForWatch
{
    if (self.watchSession == nil || !self.canTrackLocation) {
        return;
    }

    if (self.watchSession.isReachable || self.watchSession.complicationEnabled) {
        [self.locationManager startUpdatingLocation];
    } else {
        [self.locationManager stopUpdatingLocation];
    }
}

- (void)configureWatch
{
    if (![WCSession isSupported]) {
        return;
    }
    self.watchSession = [WCSession defaultSession];
    self.watchSession.delegate = self;
    [self.watchSession activateSession];
    [self updateWatchState];
    [self configureLocationTrackingForWatch];
}

-    (void)session:(WCSession *)session
didReceiveUserInfo:(NSDictionary<NSString *, id> *)userInfo
{
    [self updateWatchState];
}

-   (void)session:(WCSession *)session
 didReceiveMessage:(NSDictionary<NSString *,id> *)message
{
    if (!self.stationRefForWatch) {
        self.stationRefForWatch = [self findClosestStationRef];
        if (!self.stationRefForWatch) {
            [self showWatchNeedsLocationAlert];
            return;
        }
    }
}

-   (void)session:(WCSession *)session
 didReceiveMessage:(NSDictionary<NSString *,id> *)message
      replyHandler:(void (^)(NSDictionary<NSString *,id> *replyMessage))replyHandler
{
    if (!self.stationRefForWatch) {
        self.stationRefForWatch = [self findClosestStationRef];
        if (!self.stationRefForWatch) {
            [self showWatchNeedsLocationAlert];
            replyHandler(nil);
            return;
        }
    }
    NSDictionary *stationDict = [[self.stationRefForWatch loadStation] stationValuesDictionary];
    replyHandler(stationDict);
}

- (void)updateWatchState
{
    // Closest is used by watch and Today widget.
    XTStationRef *currentRef = [self findClosestStationRef];
    if (!self.watchSession) {
        return;
    }
    if (!currentRef && !self.stationRefForWatch) {
        /*
         * This can happen on first launch while the prompt for locServices is up
         * and there's no favorites list.
         */
        return;
    }
    // Only update if station changed.
    if (currentRef == nil || [currentRef isEqual:self.stationRefForWatch]) {
        return;
    }

    XTStation *station = [currentRef loadStation];
    NSDictionary *stationDict = [station stationValuesDictionary];

    NSError *error = nil;
    if ([self.watchSession updateApplicationContext:stationDict
                                              error:&error]) {
        self.stationRefForWatch = currentRef;
    } else {
        NSLog(@"Updating the context failed: %@", error.localizedDescription);
    }
}

@end
