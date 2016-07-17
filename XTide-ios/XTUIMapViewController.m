//
//  RootViewController.m
//  XTide-ios
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "AppDelegate.h"
#import "XTUIMapViewController.h"
#import "XTStationIndex.h"
#import "XTStationRef.h"
#import "XTColorUtils.h"
#import "XTStation.h"
#import "XTUITideTabBarController.h"
#import "UIKitAdditions.h"

// Fetch and log watch events.
#define DEBUG_EVENTS 0
// If DEBUG_EVENTS, also dump the clock image data.
#define DEBUG_EVENT_CLOCK 0
// Change the map dot color of favorite stations.
#define DEBUG_DOTS 0

// TODO: Add a debug menu to do things like force complication updates.
static const CGFloat deltaLimit = 3;
static const CGFloat zoomLimit = 0.5;
static const CLLocationDistance kUserLocMovement = 5000; // meters

static const NSTimeInterval DAY = 60 * 60 * 24;
static NSString * const XTMap_RegionKey = @"map.region";

@interface XTUIMapViewController ()

@property (copy) NSArray *refStations;
@property (copy) NSArray *subStations;
@property BOOL showingSubStations;
@property (retain) UIColor *refColor;
@property (retain) UIColor *subColor;
@property (retain) id mapsLoadObserver;
@property (nonatomic) WCSession *watchSession;
@property (strong) CLLocationManager *locationManager;
@property (strong) XTStationRef *stationRefForWatch;
@property (strong) NSDate *eventStartDate;
@property (strong) NSDate *eventEndDate;
@property (strong) XTStationRef *currentAnnotation;

@property BOOL didShowWatchLocationAlert;

@end

@implementation XTUIMapViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.locationManager = [[CLLocationManager alloc] init];
    [self.locationManager setDelegate:self];
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
    } else if (  status == kCLAuthorizationStatusAuthorizedWhenInUse
               || status == kCLAuthorizationStatusAuthorizedAlways) {
        [self.locationManager startUpdatingLocation];
    }
    self.locationManager.distanceFilter = kUserLocMovement;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
    //[self.locationManager allowDeferredLocationUpdatesUntilTraveled:kUserLocMovement timeout:CLTimeIntervalMax];
    self.mapView.showsUserLocation = YES;
    self.mapView.mapType = MKMapTypeHybrid;

    [self loadStations];
    if (!self.refStations) {
        self.mapsLoadObserver = [[NSNotificationCenter defaultCenter] addObserverForName:XTideMapsLoadedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            [self loadStations];
        }];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(defaultsChanged:)
                                                 name:XTStationIndexFavoritesChangedNotification
                                               object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)loadStations
{
    if (self.refStations) {
        return;
    }
    NSArray *stationRefArray = [(AppDelegate *)[[UIApplication sharedApplication] delegate] stationRefArray];
    if (!stationRefArray) {
        return;
    }
    NSMutableArray *refs = [NSMutableArray array];
    NSMutableArray *subs = [NSMutableArray array];
    for (XTStationRef *station in stationRefArray) {
        if (station.isReferenceStation) {
            [refs addObject:station];
        } else {
            [subs addObject:station];
        }
    }
    self.stationRefForWatch = [self findStationRefForWatch];
    self.refColor = ColorForKey(XTide_ColorKeys[refcolor]);
    self.subColor = ColorForKey(XTide_ColorKeys[subcolor]);
    self.refStations = refs;
    self.subStations = subs;
    [self.mapView addAnnotations:refs];
    [self updateSubStations];
    [self restoreMapState];
    if (self.mapsLoadObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.mapsLoadObserver];
        self.mapsLoadObserver = nil;
    }
    [self configureWatch];
#if DEBUG_EVENTS
    XTStation *station = [[self stationRefForWatch] loadStation];
    if (station) {
        NSArray *angles = [station generateWatchEventsStart:[NSDate date] end:[NSDate dateWithTimeIntervalSinceNow:60*60*24]];
        NSLog(@"%@", angles);
    }
#if DEBUG_EVENT_CLOCK
    NSDictionary *dict = [self clockInfoWithWidth:200 height:200 scale:2];
    NSLog(@"%@", dict);
#endif
#endif
}

// Only show the substations when we're zoomed in; there are over 4000 stations in the database.
- (void)updateSubStations
{
    MKCoordinateRegion newRegion = [self.mapView region];
    BOOL shouldShow =    newRegion.span.latitudeDelta < deltaLimit
                      || newRegion.span.longitudeDelta < deltaLimit;
    if (shouldShow != self.showingSubStations) {
        self.showingSubStations = shouldShow;
        if (shouldShow) {
            [self.mapView addAnnotations:self.subStations];
        } else {
            // Keep any substations in the selection
            NSMutableArray *subs = [NSMutableArray arrayWithArray:self.subStations];
            [subs removeObjectsInArray:self.mapView.selectedAnnotations];
            [self.mapView removeAnnotations:subs];
        }
    }
}


- (IBAction)goHome:(id)sender
{
    CLLocation *loc = self.mapView.userLocation.location;
    if (loc) {
        MKCoordinateRegion region = [self.mapView region];
        BOOL shouldZoom =    region.span.latitudeDelta > zoomLimit
                          && region.span.longitudeDelta > zoomLimit;
        if (shouldZoom) {
            region.center = loc.coordinate;
            region.span.latitudeDelta = region.span.longitudeDelta = zoomLimit;
            [self.mapView setRegion:region animated:YES];
        } else {
            [self.mapView setCenterCoordinate:loc.coordinate animated:YES];
        }
    }
}


-         (void)mapView:(MKMapView *)mapView
regionDidChangeAnimated:(BOOL)animated
{
    [self updateSubStations];
    [self saveMapState];
}

- (UIColor *)colorForStationRef:(XTStationRef *)ref
{
    /*
     * We can only change the color if the annotationView is visible,
     * or when the views all reload, but doing an add/remove does not seem
     * to trigger that - it may be consolidating the changes.
     * So the color is only for debugging.
     */
    UIColor *color = ref.isReferenceStation ? self.refColor
                                            : self.subColor;
#if DEBUG_DOTS
    if ([[XTStationIndex sharedStationIndex] isFavorite:ref]) {
        color = [UIColor whiteColor];
        if ([self.stationRefForWatch isEqual:ref]) {
            // It'll be purple in the map too.
            color = [UIColor purpleColor];
        }
    }
#endif
    return color;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView
            viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }
    if (![annotation isKindOfClass:[XTStationRef class]]) {
        NSLog(@"Unexpected annotation %@", annotation);
        return nil;
    }
    
    MKAnnotationView *returnedAnnotationView =
        [mapView dequeueReusableAnnotationViewWithIdentifier:NSStringFromClass([XTStationRef class])];
    UIButton *favoriteButton = nil;
    if (returnedAnnotationView == nil) {
        returnedAnnotationView =
            [[MKPinAnnotationView alloc] initWithAnnotation:annotation
                                            reuseIdentifier:NSStringFromClass([XTStationRef class])];
        
        // There are over 4000 of them!
        ((MKPinAnnotationView *)returnedAnnotationView).animatesDrop = NO;
        returnedAnnotationView.canShowCallout = YES;
        UIButton *disclosureButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        [disclosureButton setImage:[UIImage imageNamed:@"ChartViewTemplate"] forState:UIControlStateNormal];
        returnedAnnotationView.rightCalloutAccessoryView = disclosureButton;
        favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [favoriteButton setFrame:CGRectMake(0, 0, 32, 32)];
        [favoriteButton setImage:[UIImage imageNamed:@"FavoriteStarOpen"] forState:UIControlStateNormal];
        [favoriteButton setImage:[UIImage imageNamed:@"FavoriteStarFilled"] forState:UIControlStateSelected];
        returnedAnnotationView.leftCalloutAccessoryView = favoriteButton;
    }
    else {
        favoriteButton = (UIButton *)returnedAnnotationView.leftCalloutAccessoryView;
        returnedAnnotationView.annotation = annotation;
    }
    XTStationRef *ref = (XTStationRef *)annotation;
    favoriteButton.selected = [[XTStationIndex sharedStationIndex] isFavorite:ref];

    ((MKPinAnnotationView *)returnedAnnotationView).pinTintColor = [self colorForStationRef:ref];

    return returnedAnnotationView;
}

- (void)viewDidAppear:(BOOL)animated
{
    // Update the button in case the favorites changed.
    XTStationRef *ref = [[self.mapView selectedAnnotations] firstObject];
    if (![ref isKindOfClass:[XTStationRef class]]) {
        return;
    }
    [self updateAnnotation:ref];
}


// user tapped the call out accessory: star or chart button
- (void)mapView:(MKMapView *)aMapView
 annotationView:(MKAnnotationView *)view
calloutAccessoryControlTapped:(UIControl *)control
{
    XTStationRef *annotation = (XTStationRef *)view.annotation;
     if ([annotation isKindOfClass:[MKUserLocation class]]) {
        [self goHome:nil];
        return;
    }
   
    UIButton *button = (UIButton *)control;
    if (control == view.rightCalloutAccessoryView) {
        self.currentAnnotation = annotation;
        [self performSegueWithIdentifier:@"ShowTideViews" sender:self];
    } else {
        button.selected = !button.selected;
        if (button.selected) {
            [[XTStationIndex sharedStationIndex] addFavorite:annotation];
        }
        else {
            [[XTStationIndex sharedStationIndex] removeFavorite:annotation];
        }
    }
}

- (void)saveMapState
{
    MKCoordinateRegion region = [self.mapView region];
    NSArray *encodedRegion = @[@(region.center.latitude), @(region.center.longitude),
                               @(region.span.latitudeDelta), @(region.span.longitudeDelta)];
    [[NSUserDefaults standardUserDefaults] setObject:encodedRegion forKey:XTMap_RegionKey];
}

- (void)restoreMapState
{
    NSArray *encodedRegion = [[NSUserDefaults standardUserDefaults] objectForKey:XTMap_RegionKey];
    if ([encodedRegion count] == 4) {
        MKCoordinateRegion newRegion;
        newRegion.center.latitude = [encodedRegion[0] doubleValue];
        newRegion.center.longitude = [encodedRegion[1] doubleValue];
        newRegion.span.latitudeDelta = [encodedRegion[2] doubleValue];
        newRegion.span.longitudeDelta = [encodedRegion[3] doubleValue];
        @try {
            [self.mapView setRegion:newRegion animated:NO];
        } @catch (NSException *e) {
            // Ignore bad data and continue with restoration.
        }
    }
}

#pragma mark watch

- (void)sessionReachabilityDidChange:(WCSession *)session
{
//    dispatch_sync(dispatch_get_main_queue(), ^{
//        // We only care about location when the watch is using it.
//        if (session.isReachable || session.complicationEnabled) {
//            [self.locationManager startUpdatingLocation];
//        } else {
//            [self.locationManager stopUpdatingLocation];
//        }
//    });
}

- (void)updateWatchState
{
    XTStationRef *currentRef = [self findStationRefForWatch];
    if (!currentRef) {
        /*
         * This can happen on first launch while the prompt for locServices is up
         * and there's no favorites list.
         */
        return;
    }
    if ([currentRef isEqual:self.stationRefForWatch]) {
        return;
    }
    // Update the old favorite.
    XTStationRef *oldStation = self.stationRefForWatch;
    self.stationRefForWatch = currentRef;
    [self updateAnnotation:oldStation];
    [self updateAnnotation:self.stationRefForWatch];

    // TODO: Store the last known watch size so it's right when we do an update.
    if (self.watchSession) {
        NSDictionary *dict = [self clockInfoWithWidth:156 height:195 scale:2];
        NSError *error = nil;
        if (![self.watchSession updateApplicationContext:dict
                                                   error:&error]) {
            NSLog(@"Updating the context failed: %@", error.localizedDescription);
        }
        if ([self.watchSession isComplicationEnabled]) {
            NSDictionary *events = [self complicationEvents];
            if (events) {
                [self.watchSession transferCurrentComplicationUserInfo:events];
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (   status == kCLAuthorizationStatusAuthorizedWhenInUse
        || status == kCLAuthorizationStatusAuthorizedAlways) {
        [self.locationManager startUpdatingLocation];
        if (self.watchSession) {
            [self updateWatchState];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateWatchState];
    });
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"locationManager:didFailWithError: %@", error);
}

// Update the dot (if we could) and button after favorites change
- (void)updateAnnotation:(XTStationRef *)ref
{
    MKAnnotationView *view = [self.mapView viewForAnnotation:ref];
    if (view) {
        UIButton *favoriteButton = (UIButton *)view.leftCalloutAccessoryView;
        favoriteButton.selected = [[XTStationIndex sharedStationIndex] isFavorite:ref];
#if DEBUG_DOTS
        // This only works if the annotationView is visible :(
        ((MKPinAnnotationView *)view).pinTintColor = [self colorForStationRef:ref];
#endif
    }
}

#pragma mark storyboard

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UIViewController<XTUITideView> *vc = [segue destinationViewController];
    if ([vc conformsToProtocol:@protocol(XTUITideView)]) {
        [vc updateStation:[self.currentAnnotation loadStation]];
    }
}

#pragma mark watch

- (void)defaultsChanged:(NSNotification *)notification
{
    // Update this first in case stationRefForWatch is changing.
    [self updateWatchState];
    XTStationRef *ref = [[notification userInfo] objectForKey:@"ref"];
    if (ref) {
        // The state just changed on this ref. Update its annotationView dot and button.
        [self updateAnnotation:ref];
    }
}

- (void)showWatchNeedsLocationAlert
{
    if (self.didShowWatchLocationAlert) {
        return;
    }
    // We may reset this after a certain time.
    //
    self.didShowWatchLocationAlert = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Watch needs station"
                                       message:@"The watch cannot find a station to display. Mark a station as favorite."
                                       preferredStyle:UIAlertControllerStyleAlert];
         
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
           handler:^(UIAlertAction * action) {}];
         
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

/*
 * First option: closest favorite station. Update whenever location changes.
 * Second option: closest ref station. Update when the user location has moved more than
 *  a distance that's kind of arbitrary.
 * If there's no location services, pick the first favorite.
 * If that fails, we'll show showWatchNeedsLocationAlert when the watch asks for data.
 */
- (XTStationRef *)findStationRefForWatch
{
    XTStationIndex *stationIndex = [XTStationIndex sharedStationIndex];
    NSAssert(self.locationManager, @"Calling this too soon!");
    CLLocation *userLoc = self.locationManager.location;
    if (!userLoc) {
        return [[stationIndex favoriteStationRefs] firstObject];
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
            ref = [stationIndex stationRefNearestLocation:userLoc inStations:self.refStations];
        }
    }
    return ref;
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
}


- (NSDictionary *)clockInfoWithWidth:(CGFloat)width height:(CGFloat)height scale:(CGFloat)scale
{
    if (!self.watchSession) {
        return nil;
    }
    XTStation *station = [[self stationRefForWatch] loadStation];
    if (!station) {
        return nil;
    }
    return [station clockInfoWithXSize:width
                                 ysize:height
                                 scale:scale];
}


/*
 * Note: Showing the station in the app isn't a great UI because there's no
 * way to force it to launch the app (a button with no apparent effect is bad),
 * so it's just for debugging.
 */
-    (void)session:(WCSession *)session
didReceiveUserInfo:(NSDictionary<NSString *, id> *)userInfo
{
    if (!self.stationRefForWatch) {
        NSLog(@"No station");
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController<XTUITideView> *vc = (UIViewController<XTUITideView> *)self.navigationController.visibleViewController;
        XTStation *station = [self.stationRefForWatch loadStation];
        if ([vc conformsToProtocol:@protocol(XTUITideView)]) {
            [vc updateStation:station];
        } else {
            // Whatever else it is, it supports showing a station.
            self.currentAnnotation = self.stationRefForWatch;
            [self performSegueWithIdentifier:@"ShowTideViews" sender:self];
        }
    });
}

- (NSDictionary *)complicationEvents
{
    XTStation *station = [[self stationRefForWatch] loadStation];
    if (!station) {
        return nil;
    }
    if (!self.eventStartDate) {
        self.eventStartDate = [NSDate dateWithTimeIntervalSinceNow:-DAY];
    }
    if (!self.eventEndDate) {
        self.eventEndDate = [NSDate dateWithTimeIntervalSinceNow:DAY * 2];
    }
    NSArray *events = [station generateWatchEventsStart:self.eventStartDate end:self.eventEndDate];
    if (events) {
        return @{@"events":events};
    }
    return nil;
}

-   (void)session:(WCSession *)session
 didReceiveMessage:(NSDictionary<NSString *,id> *)message
      replyHandler:(void (^)(NSDictionary<NSString *,id> *replyMessage))replyHandler
{
    if (!self.stationRefForWatch) {
        self.stationRefForWatch = [self findStationRefForWatch];
        if (!self.stationRefForWatch) {
            [self showWatchNeedsLocationAlert];
            replyHandler(nil);
            return;
        }
    }
    // TODO: Make loadStation thread safe. This comes in on a background thread.
    NSString *kind = [message objectForKey:@"kind"];
    if ([kind isEqualToString:@"requestImage"]) {
        CGFloat width = [[message objectForKey:@"width"] floatValue];
        CGFloat height = [[message objectForKey:@"height"] floatValue];
        CGFloat scale = [[message objectForKey:@"scale"] floatValue];
        if (scale == 0) scale = 1;
        if (width > 0 && height > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary *dict = [self clockInfoWithWidth:width height:height scale:scale];
                replyHandler( dict );
            });
            return;
        }
    } else if ([kind isEqualToString:@"requestEvents"]) {
        self.eventStartDate = [message objectForKey:@"first"];
        self.eventEndDate = [message objectForKey:@"last"];
        dispatch_async(dispatch_get_main_queue(), ^{
            replyHandler( [self complicationEvents] );
        });
        return;
    }
    replyHandler(nil);
}

@end
