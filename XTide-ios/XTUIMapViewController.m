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
#import "XTUIGraphViewController.h"

static const CGFloat deltaLimit = 5;
static NSString * const XTMap_RegionKey = @"map.region";

@interface XTUIMapViewController ()

@property (copy) NSArray *refStations;
@property (copy) NSArray *subStations;
@property BOOL showingSubStations;
@property (retain) UIColor *refColor;
@property (retain) UIColor *subColor;
@property (retain) id mapsLoadObserver;

@end

@implementation XTUIMapViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self loadStations];
    if (!self.refStations) {
        self.mapsLoadObserver = [[NSNotificationCenter defaultCenter] addObserverForName:XTideMapsLoadedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            [self loadStations];
        }];
    }
    self.mapView.showsUserLocation = YES;
    self.mapView.mapType = MKMapTypeHybrid;
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
        BOOL shouldZoom =    region.span.latitudeDelta > deltaLimit
                          && region.span.longitudeDelta > deltaLimit;
        if (shouldZoom) {
            region.center = loc.coordinate;
            region.span.latitudeDelta = region.span.longitudeDelta = deltaLimit;
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

    /*
     * TODO: Remove when not debugging: Use another color for favorites. We'd have to add/remove
     * all pins when favorites change if we wanted that for a user feature.
     */
    UIColor *color = ref.isReferenceStation ? self.refColor
                                            : self.subColor;
    if ([[XTStationIndex sharedStationIndex] isFavorite:ref]) {
        color = [UIColor whiteColor];
        // TODO: Cache this.
        CLLocation *loc = self.mapView.userLocation.location;
        XTStationRef *closest = nil;
        if (loc) {
            closest = [[XTStationIndex sharedStationIndex] favoriteNearestLocation:loc];
        }
        if ([closest isEqual:ref]) {
            color = [UIColor blackColor];
        }
    }
    ((MKPinAnnotationView *)returnedAnnotationView).pinTintColor = color;

    return returnedAnnotationView;
}


// user tapped the call out accessory: star or 'i' button
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
        XTUIGraphViewController *viewController = [[XTUIGraphViewController alloc] init];
        viewController.edgesForExtendedLayout = UIRectEdgeNone;
        [viewController updateStation:[annotation loadStation]];
        
        [self.navigationController pushViewController:viewController animated:YES];
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

@end
