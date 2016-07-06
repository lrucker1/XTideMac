//
//  InterfaceController.m
//  XTideWatch Extension
//
//  Created by Lee Ann Rucker on 7/2/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "InterfaceController.h"
#import "XTSessionDelegate.h"

#define DEBUG 1

NSString * const XTWatchAppContextNotification = @"XTWatchAppContextNotification";

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

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:XTSessionReachabilityDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveApplicationContext:)
                                                 name:XTSessionAppContextNotification
                                               object:nil];

#if DEBUG
    [self addMenuItemWithImageNamed:@"ReturnToNow"
                              title:NSLocalizedString(@"Update Chart", @"reload chart with current time")
                             action:@selector(requestImage)];
    [self addMenuItemWithImageNamed:@"StationInfoIcon"
                              title:NSLocalizedString(@"Show in iPhone", @"show the chart in the iPhone")
                             action:@selector(showTidesOnPhone)];
#endif
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

- (void)updateImageFromInfo:(NSDictionary *)info
{
    NSData *data = [info objectForKey:@"clockImage"];
    NSString *axString = [info objectForKey:@"axDescription"];
    if (data) {
        [self.group setBackgroundImageData:data];
    }
    if (axString) {
        [self.group setAccessibilityLabel:axString];
    }
}


- (void)requestImage
{
    CGRect bounds = [[WKInterfaceDevice currentDevice] screenBounds];
    CGFloat scale = [[WKInterfaceDevice currentDevice] screenScale];
    [self.watchSession sendMessage:@{@"kind"   : @"requestImage",
                                     @"width"  : @(bounds.size.width),
                                     @"height" : @(bounds.size.height),
                                     @"scale"  : @(scale) }
    replyHandler:^(NSDictionary *reply) {
        if (reply) {
            [self updateImageFromInfo:reply];
        }
    }
    errorHandler:^(NSError *error){
        NSLog(@"%@", error);
    }];
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
    [self updateImageFromInfo:applicationContext];
    NSArray *coordObj = [applicationContext objectForKey:@"coordinate"];
    NSString *title = [applicationContext objectForKey:@"stationName"];
    if (coordObj) {
        [[NSUserDefaults standardUserDefaults] setObject:coordObj forKey:@"coordinate"];
        [[NSUserDefaults standardUserDefaults] setObject:title forKey:@"stationName"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (IBAction)showTidesOnPhone
{
    NSDictionary *applicationDict = @{@"test":@"test"}; // Create a dict of application data
    [[WCSession defaultSession] transferUserInfo:applicationDict];
}

- (void)willActivate
{
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
    if (self.watchSession.isReachable) {
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



