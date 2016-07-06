//
//  XTWMapInterfaceController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/5/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTWMapInterfaceController.h"
#import "InterfaceController.h"
#import "XTSessionDelegate.h"

@import WatchConnectivity;

@interface XTWMapInterfaceController ()

@property (strong) NSArray *coordinates;
@property (nonatomic) XTSessionDelegate *sessionDelegate;

@end

@implementation XTWMapInterfaceController

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];

    self.sessionDelegate = [XTSessionDelegate sharedDelegate];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(defaultsChanged:)
                                                 name:XTWatchAppContextNotification
                                               object:nil];
}

- (void)defaultsChanged:(NSNotification *)note
{
    [self updateDefaultsFromDictionary:[note userInfo]];
}

- (void)updateDefaultsFromDictionary:(NSDictionary *)dict
{
    NSArray *coordObj = [dict objectForKey:@"coordinate"];
    NSString *title = [dict objectForKey:@"stationName"];
    if (coordObj) {
        [[NSUserDefaults standardUserDefaults] setObject:coordObj forKey:@"coordinate"];
    }
    if (title) {
        [[NSUserDefaults standardUserDefaults] setObject:title forKey:@"stationName"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (coordObj && title) {
        [self updateMap:coordObj title:title];
    }
}


- (void)requestCoordinate
{
    [[WCSession defaultSession] sendMessage:@{@"kind"   : @"requestCoordinate" }
    replyHandler:^(NSDictionary *reply) {
        if (reply) {
            [self updateDefaultsFromDictionary:reply];
        }
    }
    errorHandler:^(NSError *error){
        NSLog(@"%@", error);
    }];
}

- (void)updateMap:(NSArray *)coordObj title:(NSString *)title
{
    // Configure interface objects here.
    if ([coordObj count] == 2 && ![coordObj isEqualToArray:self.coordinates]) {
        CLLocationCoordinate2D coord;
        coord.latitude = [[coordObj firstObject] floatValue];
        coord.longitude = [[coordObj lastObject] floatValue];
        [self.map removeAllAnnotations];
        [self.map addAnnotation:coord withPinColor:WKInterfaceMapPinColorPurple];
        MKCoordinateSpan coordinateSpan = MKCoordinateSpanMake(0.1, 0.1);
        [self.map setRegion:(MKCoordinateRegionMake(coord, coordinateSpan))];
        self.coordinates = coordObj;
    }
    [self.mapLabel setText:title];
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    NSArray *coordObj = [[NSUserDefaults standardUserDefaults] objectForKey:@"coordinate"];
    NSString *title = [[NSUserDefaults standardUserDefaults] objectForKey:@"stationName"];
    if (coordObj && title) {
        [self updateMap:coordObj title:title];
    } else {
        [self requestCoordinate];
    }
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

@end



