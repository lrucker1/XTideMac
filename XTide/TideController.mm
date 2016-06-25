//
//  TideController.m
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
#import "AppDelegate.h"
#import "XTPrefFlagsViewController.h"
#import "XTSettings.h"
#import "XTStationInt.h"
#import "XTStationRef.h"
#import "XTTideEventsOrganizer.h"
#import "XTTideEvent.h"
#import "XTUtils.h"
#import "PredictionValue.hh"

static TideController *selfContext;

@interface TideController ()

@property (strong) NSPopover *eventMaskPopover;
@property (strong) XTPrefFlagsViewController *popoverViewController;
@property (strong) XTStationRef *stationRef;
@property (nonatomic, strong) XTStation *station;
@property BOOL isObserving;

@end

@implementation TideController

@synthesize stationRef;
@synthesize station;
@synthesize organizer;

- (instancetype)initWithWindowNibName:(NSString*)nibName stationRef:(XTStationRef *)in_stationRef
{
    self = [super initWithWindowNibName:nibName];
    if (self == nil) {
        return nil;
    }
    self.stationRef = in_stationRef;
    self.station = [stationRef loadStation];
    _isObserving = YES;
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:XTide_units
                                               options:NSKeyValueObservingOptionNew
                                               context:&selfContext];
    
    return self;
}

- (instancetype)initWith:(XTStationRef*)in_stationRef
{
    NSLog(@"Child must implement initWith:");
    return self;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    // "name" is used in AppDelegate to create the window.
    [coder encodeObject:self.stationRef.title forKey:@"name"];
    [super encodeRestorableStateWithCoder:coder];
}

- (void)removeObservers
{
   [[NSUserDefaults standardUserDefaults] removeObserver:self
                                               forKeyPath:XTide_units
                                                  context:&selfContext];
}

- (void)windowWillClose:(NSNotification*)note
{
    // TODO: Find out why this is called a second time at termination.
    if (self.isObserving) {
        [self removeObservers];
        self.isObserving = NO;
    }
}

- (void)awakeFromNib
{
    [dateFromPicker setMinDate:TimestampToNSDate(libxtide::Global::beginningOfTime)];
    [dateFromPicker setMaxDate:TimestampToNSDate(libxtide::Global::endOfTime)];
    [dateFromPicker setTimeZone:[station timeZone]];
    [self invalidateRestorableState];
}

- (void)dealloc
{
    // A blanket remove is only safe in dealloc; otherwise it gets rid of delegate notifications too.
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];
    self.stationRef = nil;
    self.station = nil;
    self.organizer = nil;
}

// Set the window title to "station name - date"
- (void)setWindowTitleDate:(NSDate*)date
{
    // @lar use app's preferred time format
    [[self window] setTitle:
        [NSString stringWithFormat:@"%@ - %@",[stationRef title], date]];
}
- (XTStation*)station
{
    return station;
}

// Keep this in sync with date picker
- (void)updateLabels
{
    NSDate *timeFrom = [dateFromPicker dateValue];
    [timeZoneFromLabel setStringValue:[[station timeZone] abbreviationForDate:timeFrom]];
    [self setWindowTitleDate:timeFrom];
}

// Even controllers for non-text views support this, for file save as
- (NSString*)stringWithIndexes:(NSIndexSet *)rowIndexes form:(char)form mode:(char)mode
{
    if ([organizer count] == 0)
        return nil;
    
    NSInteger i, first, last;
    if (rowIndexes == nil) {
        first = 0;
        last = [organizer count]-1;
    }
    else {
        first = [rowIndexes firstIndex];
        last = [rowIndexes lastIndex];
    }
    NSMutableString *str = [NSMutableString string];
    [str appendString:[XTTideEvent descriptionListHeadForm:form mode:mode station:station]];
    
    for (i = first; i <= last; i++) {
        [str appendString:[[organizer objectAtIndex:i] descriptionWithForm:form mode:mode station:station]];
        if (i < last && form == 't')
            [str appendString:@"\n"];
    }
    [str appendString:[XTTideEvent descriptionListTailForm:form mode:mode station:station]];
    return str;
}


- (IBAction)showGraphForSelection:(id)sender
{
    [(AppDelegate *)[NSApp delegate] showTideGraphForStation:self.stationRef];
}

- (IBAction)showDataForSelection:(id)sender
{
    [(AppDelegate *)[NSApp delegate] showTideDataForStation:self.stationRef];
}

- (IBAction)showCalendarForSelection:(id)sender
{
    [(AppDelegate *)[NSApp delegate] showTideCalendarForStation:self.stationRef];
}

#pragma mark popover

// -------------------------------------------------------------------------------
//  createPopover
// -------------------------------------------------------------------------------
- (void)createPopover
{
    if (self.eventMaskPopover == nil)
    {
        // create and setup our popover
        _eventMaskPopover = [[NSPopover alloc] init];
        
        // the popover retains us and we retain the popover,
        // we drop the popover whenever it is closed to avoid a cycle
 
        if (self.popoverViewController == nil) {
            self.popoverViewController = [[XTPrefFlagsViewController alloc] init];
        }
        self.eventMaskPopover.contentViewController = self.popoverViewController;
        
        self.eventMaskPopover.animates = YES;
        
        // AppKit will close the popover when the user interacts with a user interface element outside the popover.
        // note that interacting with menus or panels that become key only when needed will not cause a transient popover to close.
        self.eventMaskPopover.behavior = NSPopoverBehaviorTransient;
        
        // so we can be notified when the popover appears or closes
        self.eventMaskPopover.delegate = self;
    }
}

// -------------------------------------------------------------------------------
//  showPopoverAction:sender
// -------------------------------------------------------------------------------
- (IBAction)showPopoverAction:(id)sender
{
    [self createPopover];
    
    NSButton *targetButton = (NSButton *)sender;
    
    [self.eventMaskPopover showRelativeToRect:targetButton.bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
}

// -------------------------------------------------------------------------------
// Invoked on the delegate when the NSPopoverDidCloseNotification notification is sent.
// This method will also be invoked on the popover.
// -------------------------------------------------------------------------------
- (void)popoverDidClose:(NSNotification *)notification
{
    // release our popover since it closed
    self.eventMaskPopover = nil;
}

#pragma mark observation

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context != &selfContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    } else if ([keyPath isEqualToString:XTide_units]) {
        libxtide::Global::settings.applyMacResources();
        [self.station updateUnits];
    } else {
        NSAssert(0, @"Unhandled key %@ in %@", keyPath, [self className]);
    }
}

@end
