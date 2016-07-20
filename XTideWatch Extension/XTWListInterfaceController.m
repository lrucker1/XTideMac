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

    [self setTitle:@"Min/Max"];
    // The doc implies we could set up the table here, but all we can fix is the station name.
    NSDictionary *info = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentState"];
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(listUpdated:)
                                                 name:XTSessionUpdateReplyNotification
                                               object:nil];
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
    if (![WCSession defaultSession].reachable) {
        NSDictionary *info = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentState"];
        if (info) {
            [self updateContentsFromInfo:info];
        }
        return;
    }

    [self.sessionDelegate requestUpdate];
}

- (void)updateTimer
{
    if (![WCSession defaultSession].isReachable) {
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
    if ([WCSession defaultSession].reachable) {
        [self startTimer];
    } else {
        [self endTimer];
    }
}

- (void)updateContentsFromInfo:(NSDictionary *)info
{
    // Table behaves badly if configured while not active.
    // Set the label so it stops saying "Waiting for iPhone", and then bail.
    // TODO: file a bug.
    NSString *title = [info objectForKey:@"title"];
    if (title) {
        self.stationLabel.text = title;
    }

    if (!self.isActive) {
        return;
    }
    NSArray *events = [info objectForKey:@"clockEvents"];

    if ([events count] < 2) {
        return;
    }
    // If it's the same date and station, it's the same data.
    NSInteger numberOfRows = [self.eventTable numberOfRows];
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
    if (numberOfRows != 2) {
        // Don't change unnecessarily; it flickers.
        [self.eventTable setNumberOfRows:[events count] withRowType:@"listRow"];
    }
    
    [events enumerateObjectsUsingBlock:^(NSDictionary *event, NSUInteger idx, BOOL *stop) {
        XTWListTableRowController *row = [self.eventTable rowControllerAtIndex:idx];

        [row.descLabel setText:[event objectForKey:@"desc"]];
        [row.levelLabel setText:[event objectForKey:@"level"]];
        NSDate *date = [event objectForKey:@"date"];
        [row.timeLabel setText:[date localizedTimeAndRelativeDateString]];
        [row.image setImage:[UIImage imageNamed:[event objectForKey:@"type"]]];
        UIColor *color = nil;
        if ([date compare:[NSDate date]] == NSOrderedAscending) {
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self updateContentsFromInfo:[note userInfo]];
    });
}

- (void)listUpdated:(NSNotification *)note
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self updateContentsFromInfo:[note userInfo]];
    });
}

- (void)willActivate
{
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    self.isActive = YES;
    NSDictionary *info = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentState"];
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



