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
#import "Graph.hh"
#import "PrintPanelAccessoryController.h"
#import "XTSavePanelAccessoryController.h"
#import "XTGraphTouchBarView.h"

static TideController *selfContext;
NSString *XT_ICalPboardType = @"com.apple.ical.ics";
NSString *XT_CSVPboardType = @"Comma-separated value (CSV) file";
static NSTouchBarItemIdentifier CustomViewIdentifier = @"com.lrucker.xtide.touchGraph";
static NSTouchBarItemIdentifier NowButtonIdentifier = @"com.lrucker.xtide.nowButton";

@interface TideController ()

@property (strong) NSPopover *eventMaskPopover;
@property (strong) XTPrefFlagsViewController *popoverViewController;
@property (strong) XTStationRef *stationRef;
@property (nonatomic, strong) XTStation *station;
@property BOOL isObserving;
@property (nonatomic, strong) NSSavePanel             *savePanel;
@property (nonatomic, strong) XTSavePanelAccessoryController *accessoryVC;
@property (strong) NSCustomTouchBarItem *customViewItem;

@end

@implementation TideController

@synthesize stationRef;
@synthesize station;

- (instancetype)initWithWindowNibName:(NSString*)nibName stationRef:(XTStationRef *)in_stationRef
{
    self = [super initWithWindowNibName:nibName];
    if (self == nil) {
        return nil;
    }
    self.stationRef = in_stationRef;
    self.station = [stationRef loadStation];
    _isObserving = YES;
    
    [XTSettings_GetUserDefaults() addObserver:self
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
    [XTSettings_GetUserDefaults() removeObserver:self
                                      forKeyPath:XTide_units
                                         context:&selfContext];
    self.isObserving = NO;
}

#if DEBUG
- (IBAction)generateStuff:(id)sender
{
    XTStation *station = [self station];
    [[station stationValuesDictionary] writeToFile:[@"~/debugStation.xml" stringByExpandingTildeInPath] atomically:NO];
    NSLog(@"Saved to %@", [@"~/debugStation.xml" stringByExpandingTildeInPath]);

}
#endif

- (void)windowWillClose:(NSNotification*)note
{
    // TODO: Find out why this is called a second time at termination.
    if (self.isObserving) {
        [self removeObservers];
    }
}

- (void)awakeFromNib
{
    [dateFromPicker setMinDate:TimestampToNSDate(libxtide::Graph::beginningOfTime)];
    [dateFromPicker setMaxDate:TimestampToNSDate(libxtide::Graph::endOfTime)];
    [dateFromPicker setTimeZone:[station timeZone]];
    [self invalidateRestorableState];
    [[self window] setTitle:[NSString stringWithFormat:[self titleFormat], [stationRef title]]];
}

- (NSString *)titleFormat
{
    return @"%@";
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

- (XTStation*)station
{
    return station;
}

// Keep this in sync with date picker
- (void)updateLabels
{
    NSDate *timeFrom = [dateFromPicker dateValue];
    [timeZoneFromLabel setStringValue:[[station timeZone] abbreviationForDate:timeFrom]];
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

#pragma mark touchbar

- (NSDate *)startDate
{
    NSAssert(0, @"Subclass must implement");
    return [NSDate date];
}

- (void)syncStartDate:(NSDate *)date
{
    [self.touchBarView setGraphdate:date];
}

- (void)refreshDate:(id)sender
{
    [self syncStartDate:[NSDate date]];
}

- (NSTouchBar *)makeTouchBar
{
    NSTouchBar *bar = [[NSTouchBar alloc] init];
    bar.delegate = self;
    
    // Set the default ordering of items.
    bar.defaultItemIdentifiers =
        @[NowButtonIdentifier, CustomViewIdentifier, NSTouchBarItemIdentifierOtherItemsProxy];
    
    return bar;
}

- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    if ([identifier isEqualToString:NowButtonIdentifier]) {
        NSButton *button = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameTouchBarRefreshTemplate]
                                              target:self
                                              action:@selector(refreshDate:)];
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:NowButtonIdentifier];
        item.view = button;
        return item;
    } else if ([identifier isEqualToString:CustomViewIdentifier]) {
        self.touchBarView = [[XTGraphTouchBarView alloc] initWithFrame:NSZeroRect
                                                                  date:[self startDate]
                                                            stationRef:self.stationRef];
        self.touchBarView.dataSource = self;
        
            self.touchBarView.allowedTouchTypes = NSTouchTypeMaskDirect;
    
        _customViewItem = [[NSCustomTouchBarItem alloc] initWithIdentifier:CustomViewIdentifier];
        self.customViewItem.view = self.touchBarView;

        return self.customViewItem;
    }
    
    return nil;
}

#pragma mark export

- (NSArray *)writableTypes
{
	return [NSArray arrayWithObjects:@"txt", @"ics", nil];
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    NSAssert(0, @"Not reached");
    return NO;
}

- (IBAction)exportFile:(id)sender
{
    if (!self.savePanel) {
        // The accessory changes allowedFileTypes to match the current extension.
        self.savePanel = [NSSavePanel savePanel];
        [self.savePanel setAllowedFileTypes:[self writableTypes]];
    }
    [self.savePanel setNameFieldStringValue:self.stationRef.title];
    [self.savePanel setNameFieldLabel:NSLocalizedString(@"Export As:", @"Export As:")];
    if (!self.accessoryVC) {
        self.accessoryVC = [[XTSavePanelAccessoryController alloc] init];
        [self.accessoryVC setSavePanel:self.savePanel];
    }
    [self.savePanel setAccessoryView:[[self accessoryVC] view]];
    [self.savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSError *error;
            if (![self writeToURL:[self.savePanel URL] ofType:[[self.savePanel URL] pathExtension] error:&error]) {
                NSLog(@"%@", error);
            }
        }
    }];
}

#pragma mark printing

- (NSPrintOperation *)printOperationWithView:(NSView *)view
{
    NSPrintOperation *printOp = [NSPrintOperation printOperationWithView:view];
    PrintPanelAccessoryController *accessoryController = [PrintPanelAccessoryController new];
    NSPrintPanel *printPanel = [printOp printPanel];
    [printPanel setOptions:[printPanel options] | NSPrintPanelShowsPaperSize | NSPrintPanelShowsOrientation];
    [printPanel addAccessoryController:accessoryController];
    [printOp setJobTitle:self.station.name];
    return printOp;
}

#pragma mark sheet

- (IBAction)showOptionSheet:(id)sender
{
    [aspectValueText setDoubleValue:[station aspect]];
    if ([station hasMarkLevel]) {
        libxtide::NullablePredictionValue mark = [station markLevel];
        [markValueText setDoubleValue:mark.val()];
        if (![station isCurrent] && mark.Units() != libxtide::Units::zulu) {
            // @lar units in prefs
            NSString *markString = DstrToNSString(libxtide::Units::shortName(mark.Units()));
            NSInteger index = [[XTStation unitsPrefMap] indexOfObject:markString];
            if (index < 0 || index >= 3) {
                index = 0;
            }
            [markUnitsCombo selectItemAtIndex:index];
        }
        [showMarkCheckbox setState:NSControlStateValueOn];
    }
    else {
        [showMarkCheckbox setState:NSControlStateValueOff];
    }
    [[self window] beginSheet:markSheet completionHandler:nil];
}

- (IBAction)hideOptionSheet:(id)sender
{
    // Hide the sheet
    [markSheet orderOut:sender];
    
    // Return to normal event handling
    [NSApp endSheet:markSheet returnCode:1];
    
    // Get the options
    if ([showMarkCheckbox state] == NSControlStateValueOn) {
        NSInteger index = [markUnitsCombo indexOfSelectedItem];
        if (index < 0 || index >= 3) {
            index = 0;
        }
        double val = [markValueText doubleValue];
        libxtide::Units::PredictionUnits units = [station predictUnits];
        libxtide::PredictionValue pv;
        if (index != 0 && ![station isCurrent]) {
            libxtide::Units::PredictionUnits altUnits = libxtide::Units::parse([[[XTStation unitsPrefMap] objectAtIndex:index] UTF8String]);
            pv = libxtide::PredictionValue(altUnits, val);
            if (units != altUnits) {
                pv.Units(units);
            }
        } else {
            pv = libxtide::PredictionValue(units, val);
        }
        [station markLevel:pv];
    }
    else {
        [station clearMarkLevel];
    }
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
   if ([notification object] == self.eventMaskPopover) {
        self.eventMaskPopover = nil;
    }
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
        XTSettings_ApplyMacResources();
        [self.station updateUnits];
    } else {
        NSAssert(0, @"Unhandled key %@ in %@", keyPath, [self className]);
    }
}

@end
