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

// Change the map dot color of favorite stations.
#define DEBUG_DOTS 0

static const CGFloat deltaLimit = 3;
static const CGFloat zoomLimit = 0.5;

static NSString * const XTMap_RegionKey = @"map.region";

@interface XTUIMapViewController ()

@property (copy) NSArray *refStations;
@property (copy) NSArray *subStations;
@property BOOL showingSubStations;
@property (retain) UIColor *currentDotColor;
@property (retain) UIColor *tideDotColor;
@property (retain) id mapsLoadObserver;
@property (strong) XTStationRef *currentAnnotation;

@end

@implementation XTUIMapViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.mapView.showsUserLocation = YES;
    self.mapView.mapType = MKMapTypeSatellite;

    [self loadStations];
    if (!self.refStations) {
        self.mapsLoadObserver = [[NSNotificationCenter defaultCenter] addObserverForName:XStationIndexDidLoadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            [self loadStations];
        }];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(defaultsChanged:)
                                                 name:XTStationIndexFavoritesChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stationsWillReload:)
                                                 name:XStationIndexWillReloadNotification
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
        if (station.isAnnotation) {
            if (station.isReferenceStation) {
                [refs addObject:station];
            } else {
                [subs addObject:station];
            }
            // else ignore it; they can use Search to get to it.
        }
    }
    self.currentDotColor = ColorForKey(XTide_ColorKeys[currentdotcolor]);
    self.tideDotColor = ColorForKey(XTide_ColorKeys[tidedotcolor]);
    self.refStations = refs;
    self.subStations = subs;
    [self.mapView addAnnotations:refs];
    [self updateSubStations];
    [self restoreMapState];
    if (self.mapsLoadObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.mapsLoadObserver];
        self.mapsLoadObserver = nil;
    }
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
    UIColor *color = ref.isCurrent ? self.currentDotColor
                                   : self.tideDotColor;
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
        disclosureButton.accessibilityLabel = NSLocalizedString(@"Show Tides", @"Show Tides button");
        [disclosureButton setImage:[UIImage imageNamed:@"ChartViewTemplate"] forState:UIControlStateNormal];
        returnedAnnotationView.rightCalloutAccessoryView = disclosureButton;
        favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [favoriteButton setFrame:CGRectMake(0, 0, 32, 32)];
        favoriteButton.accessibilityLabel = NSLocalizedString(@"Favorite", @"Favorite button");
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
    [super viewDidAppear:animated];
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

- (void)stationsWillReload:(NSNotification *)notification
{
    [self.mapView removeAnnotations:self.mapView.annotations];
    self.refStations = nil;
    self.subStations = nil;
    self.mapsLoadObserver = [[NSNotificationCenter defaultCenter] addObserverForName:XStationIndexDidLoadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self loadStations];
    }];
}

- (void)defaultsChanged:(NSNotification *)notification
{
    XTStationRef *ref = [[notification userInfo] objectForKey:@"ref"];
    if (ref) {
        // The state just changed on this ref. Update its annotationView button state.
        [self updateAnnotation:ref];
    }
}


@end
