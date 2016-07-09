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
    } else {
        [self.sessionDelegate requestUpdate];
    }
}

- (void)startTimer
{
    if (self.timer || !self.fireDate || ![WCSession defaultSession].reachable) {
        return;
    }
    // Set the repeat for 6 hours. We'll update it when we get new data.
    self.timer = [[NSTimer alloc] initWithFireDate:self.fireDate
                                          interval:6 * 60 * 60
                                            target:self.sessionDelegate
                                          selector:@selector(requestUpdate)
                                          userInfo:nil
                                           repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
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

- (void)loadTableDataFromEvents:(NSArray *)events
{
    // Set a timer to go off after the next minmax event.
    NSDictionary *firstEvent = [events firstObject];
    if (firstEvent) {
        NSDate *date = [[firstEvent objectForKey:@"date"] dateByAddingTimeInterval:60];
        if (![date isEqual:self.fireDate]) {
            self.fireDate = date;
            [self updateTimer];
        }
    }
    [self.eventTable setNumberOfRows:[events count] withRowType:@"listRow"];
    
    [events enumerateObjectsUsingBlock:^(NSDictionary *event, NSUInteger idx, BOOL *stop) {
        XTWListTableRowController *row = [self.eventTable rowControllerAtIndex:idx];

        [row.descLabel setText:[event objectForKey:@"desc"]];
        [row.levelLabel setText:[event objectForKey:@"level"]];
        NSString *dateString = [NSDateFormatter localizedStringFromDate:[event objectForKey:@"date"] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterLongStyle];
        [row.timeLabel setText:dateString];
    }];
}

- (void)updateContentsFromInfo:(NSDictionary *)info
{
    NSString *title = [info objectForKey:@"title"];
    if (title) {
        // Title will always be truncated. stationLabel is 2 lines and usually fits.
        //[self setTitle:title];
        self.stationLabel.text = title;
    }
    [self loadTableDataFromEvents:[info objectForKey:@"clockEvents"]];
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



