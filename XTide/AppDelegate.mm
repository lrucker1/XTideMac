//
//  AppDelegate.m
//  XTide
//
//  Created by Lee Ann Rucker on 4/11/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "AppDelegate.h"
#import "libxtide.hh"
#import "XTMapWindowController.h"
#import "XTStationIndex.h"
#import "XTGraph.h"
#import "XTSettings.h"
#import "PreferenceController.h"
#import "DisclaimerController.h"
#import "TideGraphController.h"
#import "TideDataController.h"
#import "CalendarController.h"

static NSString * const XTWindow_map = @"map";
static NSString * const XTWindow_graph = @"graph";
static NSString * const XTWindow_list = @"list";
static NSString * const XTWindow_calendar = @"calendar";
static NSString * const XTWindow_restorationName = @"name";

@interface AppDelegate ()

@property (retain) NSMutableSet *windowControllers;
@property (retain, nonatomic) XTMapWindowController *mapWindowController;
@property (readwrite, retain) NSArray *stationRefArray;
@property (readwrite, retain) PreferenceController *preferenceController;
@property (readwrite, retain) DisclaimerController *disclaimerController;

@end

@implementation AppDelegate

+ (void)initialize
{
   libxtide::Global::settings.setMacDefaults();
   libxtide::Global::settings.applyMacResources();
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    NSWindow *window = nil;
    if ([identifier isEqualToString:XTWindow_map]) {
        AppDelegate *appDelegate = [NSApp delegate];
        window = [[appDelegate mapWindowController] window];
    } else if ([identifier isEqualToString:XTWindow_graph]) {
        NSString *name = [state decodeObjectForKey:XTWindow_restorationName];
        if (name) {
            AppDelegate *appDelegate = [NSApp delegate];
            XTStationRef *ref = [[XTStationIndex sharedStationIndex] stationRefByName:name];
            if (ref) {
                window = [appDelegate showTideGraphForStation:ref];
            }
        }
    } else if ([identifier isEqualToString:XTWindow_list]) {
        NSString *name = [state decodeObjectForKey:XTWindow_restorationName];
        if (name) {
            AppDelegate *appDelegate = [NSApp delegate];
            XTStationRef *ref = [[XTStationIndex sharedStationIndex] stationRefByName:name];
            if (ref) {
                window = [appDelegate showTideDataForStation:ref];
            }
        }
    } else if ([identifier isEqualToString:XTWindow_calendar]) {
        NSString *name = [state decodeObjectForKey:XTWindow_restorationName];
        if (name) {
            AppDelegate *appDelegate = [NSApp delegate];
            XTStationRef *ref = [[XTStationIndex sharedStationIndex] stationRefByName:name];
            if (ref) {
                window = [appDelegate showTideDataForStation:ref];
            }
        }
    }
    completionHandler(window, nil);
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    self.windowControllers = [NSMutableSet set];
    // loading/processing stations might take a while -- do it asynchronously
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.stationRefArray = [[XTStationIndex sharedStationIndex] stationRefArray];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"XTideMapsLoadedNotification" object:self];
        });
    });
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Once only, show the disclaimer window at startup...
    if (![[NSUserDefaults standardUserDefaults] boolForKey:XTide_showdisclaimer]) {
        [self showDisclaimer:nil];
    }
    // Only if no windows were restored
    if ([[NSApp windows] count] == 0) {
        [self showStationMap:nil];
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication
                     hasVisibleWindows:(BOOL)flag
{
    if (!flag) {
        [self showStationMap:nil];
    }
    return YES;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication*)sender
{
	return NO;
}

- (XTMapWindowController *)mapWindowController
{
    if (!_mapWindowController) {
        _mapWindowController = [[XTMapWindowController alloc] init];
        _mapWindowController.window.restorable = YES;
        _mapWindowController.window.restorationClass = [self class];
        _mapWindowController.window.identifier = XTWindow_map;
    }
    return _mapWindowController;
}

- (IBAction)showStationMap: (id)sender
{
    [self.mapWindowController showWindow:nil];
}

- (IBAction)showPreferencePanel:(id)sender
{

	// Is PreferenceController nil?
	if (!self.preferenceController) {
		self.preferenceController = [[PreferenceController alloc] init];
	}
	[self.preferenceController showWindow:self];
}

- (IBAction)showDisclaimer:(id)sender
{
	// Also show it when requested
	if (!self.preferenceController) {
        self.disclaimerController = [[DisclaimerController alloc] init];
    }
    [self.disclaimerController showWindow: self];
}

- (void)windowWillClose:(NSNotification*)note
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSWindowWillCloseNotification
                                                  object:[note object]];
    [self.windowControllers removeObject:[[note object] windowController]];
}

- (void)configureRestorableWindowController: (NSWindowController *)wc
                                 identifier: (NSString *)identifier
{
    wc.window.restorable = YES;
    wc.window.restorationClass = [self class];
    wc.window.identifier = identifier;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(windowWillClose:)
               name:NSWindowWillCloseNotification
             object:wc.window];
    
    [self.windowControllers addObject:wc];
}


- (NSWindow *)showTideGraphForStation:(XTStationRef *)ref
{
    if (!ref) {
        return nil;
    }
	TideGraphController *tideController = [[TideGraphController alloc] initWith:ref];
    [self configureRestorableWindowController:tideController
                                   identifier:XTWindow_graph];
	[tideController showWindow:self];
    return tideController.window;
}

- (NSWindow *)showTideDataForStation:(XTStationRef *)ref
{
    if (!ref) {
        return nil;
    }
	TideDataController *tideController = [[TideDataController alloc] initWith:ref];
    [self configureRestorableWindowController:tideController
                                   identifier:XTWindow_list];
	[tideController showWindow:self];
    return tideController.window;
}

- (NSWindow *)showTideCalendarForStation:(XTStationRef *)ref
{
    if (!ref) {
        return nil;
    }
	CalendarController *tideController = [[CalendarController alloc] initWith:ref];
    [self configureRestorableWindowController:tideController
                                   identifier:XTWindow_calendar];
	[tideController showWindow:self];
    return tideController.window;
}


@end
