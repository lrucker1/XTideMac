//
//  AppDelegate.h
//  XTide
//
//  Created by Lee Ann Rucker on 4/11/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XTStationIndex.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly, retain) NSArray *stationRefArray;

- (IBAction)showStationMap: (id)sender;
- (IBAction)showDisclaimer:(id)sender;

- (NSWindow *)showTideGraphForStation:(XTStationRef *)ref;
- (NSWindow *)showTideDataForStation:(XTStationRef *)ref;
- (NSWindow *)showTideCalendarForStation:(XTStationRef *)ref;

@end

