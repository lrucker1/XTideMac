//
//  InterfaceController.m
//  XTideWatch Extension
//
//  Created by Lee Ann Rucker on 7/2/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "InterfaceController.h"


@interface InterfaceController()

@property (nonatomic) WCSession* watchSession;

@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];

    // Configure interface objects here.
    if ([WCSession isSupported]) {
        self.watchSession = [WCSession defaultSession];
        self.watchSession.delegate = self;
        [self.watchSession activateSession];
        [self requestImage];
    }
    [self addMenuItemWithImageNamed:@"ReturnToNow"
                              title:NSLocalizedString(@"Update Chart", @"reload chart with current time")
                             action:@selector(requestImage)];
}


- (void)requestImage
{
    CGRect bounds = [[WKInterfaceDevice currentDevice] screenBounds];
    CGFloat scale = [[WKInterfaceDevice currentDevice] screenScale];
    [self.watchSession sendMessage:@{@"kind" : @"requestImage",
                                     @"width" : @(bounds.size.width),
                                     @"height" : @(bounds.size.height),
                                     @"scale" : @(scale) }
    replyHandler:^(NSDictionary *reply) {
        NSData *data = [reply objectForKey:@"clockImage"];
        if (data) {
            [self.chartImage setImage:[UIImage imageWithData:data]];
        }
    }
    errorHandler:nil];
}

- (void)sessionReachabilityDidChange:(WCSession *)session
{
    if (session.reachable) {
        [self requestImage];
    }
}

- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary<NSString *,id> *)applicationContext
{
    NSData *data = [applicationContext objectForKey:@"clockImage"];
    if (data) {
        [self.chartImage setImage:[UIImage imageWithData:data]];
    }
}

- (void)session:(WCSession *)session didReceiveUserInfo:(NSDictionary<NSString *,id> *)userInfo
{
    NSString *kind = [userInfo objectForKey:@"kind"];
    if (![kind isEqualToString:@"complication"]) {
        return;
    }
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

@end



