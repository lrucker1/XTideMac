//
//  XTWListInterfaceController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/8/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTWListInterfaceController.h"
#import "InterfaceController.h"
#import "XTSessionDelegate.h"
#import "NSDate+NSDate_XTWAdditions.h"

static NSTimeInterval DEFAULT_TIMEOUT = 6 * 60 * 60;

@interface XTWListInterfaceController ()

@property (nonatomic) WCSession *watchSession;
@property (nonatomic) XTSessionDelegate *sessionDelegate;
@property (strong) NSTimer *timer;
@property (strong) NSDate *fireDate;
@property BOOL isActive;

@end

@implementation XTWListTableRowController
@end

@implementation XTWListInterfaceController

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];

    self.sessionDelegate = [XTSessionDelegate sharedDelegate];
    self.watchSession = [WCSession defaultSession];


    [self setTitle:NSLocalizedString(@"Min/Max", @"Title: Min/Max page")];
    /*
     * There is a bug which is hard to isolate: if we update the contents between now and
     * willActivate, layout never happens and the contents can't be seen.
     * Provide placeholder info if we don't have contents.
     * It does not seem to be related to which thread we're on.
     * Oh, fun - sometimes it happens anyway, but only on the watch, not the sim.
     */
    NSArray *events = @[@{@"desc":NSLocalizedString(@"High Tide", @"High Tide"),
                          @"level":@" ...",
                          @"type":@"hightide"},
                        @{@"desc":NSLocalizedString(@"Low Tide", @"Low Tide"),
                          @"level":@" ...",
                          @"type":@"lowtide"}];
    [self updateContentsFromInfo:@{@"clockEvents":events}];
    NSDictionary *info = [self.watchSession receivedApplicationContext];
    if (info) {
        [self updateContentsFromInfo:info];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:XTSessionReachabilityDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveApplicationContext:)
                                                 name:XTSessionAppContextNotification
                                               object:nil];


    // TODO: Might want this to apply to complications.
    [self addMenuItemWithImageNamed:@"ReturnToNow"
                              title:NSLocalizedString(@"Update Info", @"update the chart and list")
                             action:@selector(requestUpdate)];
}

// This timer runs even when the watch is not reachable so the contents will dim when we pass them.
- (void)startTimer
{
    if (self.timer || !self.fireDate) {
        return;
    }
    // Set the repeat for 6 hours. We'll update it when we get new data.
    self.timer = [[NSTimer alloc] initWithFireDate:self.fireDate
                                          interval:DEFAULT_TIMEOUT
                                            target:self
                                          selector:@selector(requestUpdate)
                                          userInfo:nil
                                           repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)requestUpdate
{
    if (!self.watchSession.reachable) {
        NSDictionary *info = [self.watchSession receivedApplicationContext];
        if (info) {
            [self updateContentsFromInfo:info];
        }
        return;
    }

    [self.sessionDelegate requestUpdate];
}

- (void)updateTimer
{
    if (!self.watchSession.isReachable) {
        return;
    }
    if (self.timer) {
        if (![self.timer.fireDate isEqual:self.fireDate]) {
            self.timer.fireDate = self.fireDate;
        }
    } else {
        [self startTimer];
    }
}

- (void)endTimer
{
    [self.timer invalidate];
    self.timer = nil;
}

- (void)reachabilityChanged:(NSNotification *)note
{
    if (self.watchSession.reachable) {
        [self startTimer];
    } else {
        [self endTimer];
    }
}

- (void)updateContentsFromInfo:(NSDictionary *)info
{
    // Table behaves badly if configured while not active.
    // Set the label so it stops saying "Waiting for iPhone", and then bail.
    NSString *title = [info objectForKey:@"title"];
    BOOL placeholder = title == nil;
    if (!placeholder) {
        self.stationLabel.text = title;
    }

    // Being on the main thread does not help.
    //NSAssert([NSThread isMainThread], @"is on main thread");
    NSArray *events = [info objectForKey:@"clockEvents"];

    if ([events count] < 2) {
        return;
    }
    // If it's the same date and station, it's the same data.
    NSInteger numberOfRows = [self.eventTable numberOfRows];
    if (self.isActive) {
        NSDate *nextFire = [[[events firstObject] objectForKey:@"date"] dateByAddingTimeInterval:60];
        // Set a timer to go off after the next minmax event, unless it's in the past.
        // Then try the last minmax so we can dim it.
        // Finally give it the default timeout.
        if ([nextFire compare:[NSDate date]] == NSOrderedAscending) {
            nextFire = [[[events lastObject] objectForKey:@"date"] dateByAddingTimeInterval:60];
            if ([nextFire compare:[NSDate date]] == NSOrderedAscending) {
                nextFire = [NSDate dateWithTimeIntervalSinceNow:DEFAULT_TIMEOUT];
            }
        }
        self.fireDate = nextFire;
        [self updateTimer];
    }
    if (numberOfRows != 2) {
        // Don't change unnecessarily; it flickers.
        [self.eventTable setNumberOfRows:[events count] withRowType:@"listRow"];
    }
    
    [events enumerateObjectsUsingBlock:^(NSDictionary *event, NSUInteger idx, BOOL *stop) {
        XTWListTableRowController *row = [self.eventTable rowControllerAtIndex:idx];

        [row.descLabel setText:[event objectForKey:@"desc"]];
        [row.levelLabel setText:[event objectForKey:@"level"]];
        NSDate *date = [event objectForKey:@"date"];
        // For placeholders, show localized "Today" with no time.
        [row.timeLabel setText:date ? [date localizedTimeAndRelativeDateString]
                                    : [[NSDate date] localizedRelativeDateString]];
        [row.image setImage:[UIImage imageNamed:[event objectForKey:@"type"]]];
        UIColor *color = nil;
        if (date && ([date compare:[NSDate date]] == NSOrderedAscending)) {
            // Dim everything when the date is in the past.
            // Doc says setTextColor:nil resets; it doesn't. rdar://27389249
            color = [UIColor darkGrayColor];
        }
//        [row.descLabel setTextColor:color];
//        [row.levelLabel setTextColor:color];
//        [row.timeLabel setTextColor:color];
        [row.image setTintColor:color];
        
    }];

    [self.eventTable scrollToRowAtIndex:0];
}

- (void)didReceiveApplicationContext:(NSNotification *)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateContentsFromInfo:[note userInfo]];
    });
}

- (void)willActivate
{
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    self.isActive = YES;
    NSDictionary *info = [self.watchSession receivedApplicationContext];
    if (info) {
        [self updateContentsFromInfo:info];
    }
    [self.sessionDelegate requestUpdate];
    [self startTimer];
}

- (void)didDeactivate
{
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
    self.isActive = NO;
    [self endTimer];
}

@end



