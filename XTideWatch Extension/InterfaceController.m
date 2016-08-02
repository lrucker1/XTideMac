//
//  InterfaceController.m
//  XTideWatch Extension
//
//  Created by Lee Ann Rucker on 7/2/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "InterfaceController.h"
#import "XTSessionDelegate.h"
#import "NSDate+NSDate_XTWAdditions.h"

@interface InterfaceController()

@property (nonatomic) WCSession *watchSession;
@property (nonatomic) XTSessionDelegate *sessionDelegate;
@property (strong) NSTimer *timer;

@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];

    // Configure interface objects here.
    self.sessionDelegate = [XTSessionDelegate sharedDelegate];
    self.watchSession = [WCSession defaultSession];

    NSDictionary *info = [self.watchSession receivedApplicationContext];
    if (info) {
        [self updateContentsFromInfo:info];
    } else {
        [self.group setBackgroundImageNamed:@"watchBackground"];
        [self.sessionDelegate requestUpdate];
    }
    BOOL noStation = (!info && !self.watchSession.isReachable);
    [self.noStationLabel setHidden:!noStation];
    [self setTitle:NSLocalizedString(@"Forecast", @"Title: Chart forecast page")];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:XTSessionReachabilityDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveApplicationContext:)
                                                 name:XTSessionAppContextNotification
                                               object:nil];


    [self addMenuItemWithImageNamed:@"ReturnToNow"
                              title:NSLocalizedString(@"Update Info", @"update the chart and list")
                             action:@selector(requestImage)];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:XTSessionReachabilityDidChangeNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:XTSessionAppContextNotification
                                                  object:nil];
}

- (void)startTimer
{
    if (self.timer) {
        return;
    }
    [self requestImage];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:60
                                                  target:self
                                                selector:@selector(requestImage)
                                                userInfo:nil
                                                 repeats:YES];
    self.timer.tolerance = 10;
}

- (void)endTimer
{
    [self.timer invalidate];
    self.timer = nil;
}

// The AX string will be local time even though the image shows station time.
- (NSString *)axDescriptionFromInfo:(NSDictionary *)info
{
    NSArray *events = [info objectForKey:@"clockEvents"];
    NSMutableArray *axStrings = [NSMutableArray array];
    [axStrings addObject:@"Tide Chart Graph"];
    for (NSDictionary *event in events) {
        NSString *desc = [event objectForKey:@"desc"];
        NSDate *date = [event objectForKey:@"date"];
        NSString *dateString = [date localizedTimeAndRelativeDateString];
        [axStrings addObject:[NSString stringWithFormat:@"%@ %@", desc, dateString]];
    }
    if ([axStrings count]) {
        return [axStrings componentsJoinedByString:@", "];
    }
    return @"";
}


- (void)updateContentsFromInfo:(NSDictionary *)info
{
    [self.noStationLabel setHidden:YES];
    NSData *data = [info objectForKey:@"clockImage"];
    NSString *axString = [self axDescriptionFromInfo:info];
    if (data) {
        [self.group setBackgroundImageData:data];
    }
    if (axString) {
        [self.group setAccessibilityLabel:axString];
    }
}


- (void)requestImage
{
    if (!self.watchSession.reachable) {
        return;
    }

    [self.sessionDelegate requestUpdate];
}

- (void)reachabilityChanged:(NSNotification *)note
{
    if (self.watchSession.reachable) {
        [self startTimer];
    } else {
        [self endTimer];
    }
}

- (void)didReceiveApplicationContext:(NSNotification *)note
{
    NSDictionary *applicationContext = [note userInfo];
    NSData *data = [applicationContext objectForKey:@"clockImage"];
    if (data) {
        [self updateContentsFromInfo:applicationContext];
    } else {
        [self requestImage];
    }
}

- (void)imageUpdated:(NSNotification *)note
{
    NSDictionary *reply = [note userInfo];
    if (reply) {
        [self updateContentsFromInfo:reply];
    }
}

- (void)willActivate
{
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    // Update from last info so there's something while we wait for the latest update.
    NSDictionary *info = [self.watchSession receivedApplicationContext];
    if (info) {
        [self updateContentsFromInfo:info];
    }
    if (self.watchSession.isReachable) {
        // Calls requestUpdate.
        [self startTimer];
    }
}

- (void)didDeactivate
{
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
    [self endTimer];
}

@end



