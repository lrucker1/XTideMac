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

@interface XTWListInterfaceController ()
@property (nonatomic) XTSessionDelegate *sessionDelegate;
@property (strong) NSTimer *timer;
@property (strong) NSDate *fireDate;

@end

@implementation XTWListTableRowController
@end

@implementation XTWListInterfaceController

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];

    self.sessionDelegate = [XTSessionDelegate sharedDelegate];

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
    NSDictionary *info = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentState"];
    if (info) {
        [self updateContentsFromInfo:info];
    }
    [self setTitle:@"Min/Max"];
}

- (void)startTimer
{
    if (self.timer || !self.fireDate || ![WCSession defaultSession].reachable) {
        return;
    }
    // Set the repeat for 6 hours. We'll update it when we get new data.
    self.timer = [[NSTimer alloc] initWithFireDate:self.fireDate
                                          interval:6 * 60 * 60
                                            target:self
                                          selector:@selector(requestUpdate)
                                          userInfo:nil
                                           repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)requestUpdate
{
    if (![WCSession defaultSession].reachable) {
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

- (UIImage *)imageForEvent:(NSDictionary *)event
{
    // min/max events have no "isRising" entry. Look in "type" for "hightide" and "lowtide"
    NSNumber *risingObj = [event objectForKey:@"isRising"];
    if (risingObj) {
        return [UIImage imageNamed:[risingObj boolValue] ? @"upArrowImage" : @"downArrowImage"];
    } else {
        NSString *imgType = [event objectForKey:@"type"];
        if (imgType) {
            return [UIImage imageNamed:imgType];
        }
    }
    NSLog(@"no image for event %@", event);
    return nil;
}


- (void)updateContentsFromInfo:(NSDictionary *)info
{
    // Run this before setting title because it uses that to see if this is the same data.
    NSString *title = [info objectForKey:@"title"];
    NSArray *events = [info objectForKey:@"clockEvents"];
    NSDictionary *firstEvent = [events firstObject];

    if (!firstEvent) {
        return;
    }
    // If it's the same date and station, it's the same data.
    NSInteger numberOfRows = [self.eventTable numberOfRows];
    NSDate *date = [[firstEvent objectForKey:@"date"] dateByAddingTimeInterval:60];
    // Set a timer to go off after the next minmax event.
    self.fireDate = date;
    [self updateTimer];
    if (numberOfRows != 2) {
        [self.eventTable setNumberOfRows:[events count] withRowType:@"listRow"];
    }
    
    [events enumerateObjectsUsingBlock:^(NSDictionary *event, NSUInteger idx, BOOL *stop) {
        XTWListTableRowController *row = [self.eventTable rowControllerAtIndex:idx];

        [row.descLabel setText:[event objectForKey:@"desc"]];
        [row.levelLabel setText:[event objectForKey:@"level"]];
        NSString *dateString = [NSDateFormatter localizedStringFromDate:[event objectForKey:@"date"] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterLongStyle];
        [row.timeLabel setText:dateString];
        [row.image setImage:[self imageForEvent:event]];
    }];

    if (title) {
        // Title will always be truncated. The flashing is annoying. Maybe both views should turn it off.
        //[self setTitle:title];
        self.stationLabel.text = title;
    }
}

- (void)didReceiveApplicationContext:(NSNotification *)note
{
    [self updateContentsFromInfo:[note userInfo]];
}

- (void)listUpdated:(NSNotification *)note
{
    [self updateContentsFromInfo:[note userInfo]];
}

- (void)willActivate
{
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
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
    [self endTimer];
}

@end



