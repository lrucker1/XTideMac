//
//  TideGraphController.m
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 7/15/06.
//  Copyright 2006 .
//
/*
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#import "TideController.h"
#import "TideGraphController.h"
#import "XTSettings.h"
#import "XTStationRef.h"
#import "XTStationInt.h"
#import "PredictionValue.hh"
#import "XTGraph.h"
#import "XTUtils.h"
#import "GraphView.h"

static TideGraphController *selfContext;

static NSArray *prefsKeysOfInterest;
static NSString * const TideGraph_graphdate = @"graphView.graphdate";
static NSString * const TideGraph_displayDate = @"displayDate";

@interface TideGraphController ()

@property BOOL customDate;

- (void)startNowTimer;
- (void)stopNowTimer:(BOOL)isUserAction;

@end

@implementation TideGraphController

@synthesize nowTimer;

+ (void)initialize
{
    // If any of these prefs change, redisplay the graph
    prefsKeysOfInterest = [[XTGraph colorsOfInterest] arrayByAddingObjectsFromArray:
                           @[XTide_extralines, XTide_toplines, XTide_nofill, XTide_eventmask,
                            XTide_deflwidth, XTide_tideopacity, XTide_units]];
}

- (id)initWith:(XTStationRef*)in_stationRef
{
    self = [super initWithWindowNibName:@"TideGraph" stationRef:in_stationRef];
    
    if (!self) {
        return nil;
    }
    [self addObserver:self forKeyPath:TideGraph_graphdate options:0 context:&selfContext];
    for (NSString *keyPath in prefsKeysOfInterest) {
        [[NSUserDefaults standardUserDefaults] addObserver:self
                                                forKeyPath:keyPath
                                                   options:NSKeyValueObservingOptionNew
                                                   context:&selfContext];
    }
    return self;
}

- (void)removeObservers
{
    [self removeObserver:self forKeyPath:TideGraph_graphdate context:&selfContext];
    for (NSString *keyPath in prefsKeysOfInterest) {
        [[NSUserDefaults standardUserDefaults] removeObserver:self
                                                   forKeyPath:keyPath
                                                      context:&selfContext];
    }
    [super removeObservers];
}

- (void)windowWillClose:(NSNotification*)note
{
    self.graphView.dataSource = nil;
    [super windowWillClose:note];
}

- (BOOL)windowShouldClose:(id)sender
{
    [self stopNowTimer:NO];
    return YES;
}


- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    // If it's showing a modified date, save it.
    if (self.customDate) {
        [coder encodeObject:self.graphView.graphdate forKey:TideGraph_displayDate];
    }
    [super encodeRestorableStateWithCoder:coder];
}

- (void)restoreStateWithCoder:(NSCoder *)coder
{
    // If it's nil, use current time.
    NSDate *displayDate = [coder decodeObjectForKey:TideGraph_displayDate];
    if (displayDate) {
        [self.graphView setGraphdate:displayDate];
        [dateFromPicker setDateValue:displayDate];
        self.customDate = YES;
        [self updateLabels];
    }
    [super restoreStateWithCoder:coder];
}


- (void)awakeFromNib
{
    [super awakeFromNib];
    [dateFromPicker setDateValue:[self.graphView graphdate]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(tideViewStartedTouches:)
                                                 name:TideViewTouchesBeganNotification
                                               object:self.graphView];
    [self updateLabels];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    if (action == @selector(showGraphForSelection:)) {
        return NO;
    }
    return YES;
}

// Time changed by user action.
- (IBAction)updateStartTime:(id)sender
{
    [self stopNowTimer:YES];
    [self.graphView stopMotion];
    [self.graphView setGraphdate:[dateFromPicker dateValue]];
    self.customDate = YES;
    [self updateLabels];
    [self invalidateRestorableState];
}

- (IBAction)copy:(id)sender
{
    [self.graphView copy:sender];
}

- (void)nowTimerFireMethod:(NSTimer *)timer
{
    NSDate *now = [NSDate date];
    [self.graphView setGraphdate:now];
    [dateFromPicker setDateValue:now];
}

- (void)startNowTimer
{
    [self.graphView stopMotion];
    [self nowTimerFireMethod:nil];
    [nowButton setState:NSOnState];
    self.nowTimer =
        [NSTimer scheduledTimerWithTimeInterval:60
                                         target:self
                                       selector:@selector(nowTimerFireMethod:)
                                       userInfo:nil
                                        repeats:YES];
    self.nowTimer.tolerance = 10;
}

- (void)tideViewStartedTouches:(NSNotification *)note
{
    [self stopNowTimer:YES];
}

- (void)stopNowTimer:(BOOL)isUserAction
{
    if (nowTimer) {
        [nowTimer invalidate];
        self.nowTimer = nil;
    }
    [nowButton setState:NSOffState];
}

- (IBAction)returnToNow:(id)sender
{
    self.customDate = NO;
    [self invalidateRestorableState];
    if (nowTimer) {
        [self stopNowTimer:YES];
    } else {
        [self startNowTimer];
    }
}

- (IBAction)hideOptionSheet:(id)sender
{
    [super hideOptionSheet:sender];
    double val = [aspectValueText doubleValue];
    [station aspect:val];
    [self.graphView display];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context != &selfContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    } else if ([prefsKeysOfInterest containsObject:keyPath]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.graphView display];
        });
    } else if ([keyPath isEqualToString:TideGraph_graphdate]) {
        [dateFromPicker setDateValue:self.graphView.graphdate];
    } else {
        NSAssert(0, @"Unhandled key %@ in %@", keyPath, [self className]);
    }
}


@end
