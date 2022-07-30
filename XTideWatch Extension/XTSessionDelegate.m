//
//  XTSessionDelegate.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/5/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import "XTSessionDelegate.h"

@import WatchConnectivity;

NSString * const XTSessionReachabilityDidChangeNotification = @"XTSessionReachabilityDidChangeNotification";
NSString * const XTSessionAppContextNotification = @"XTSessionAppContextNotification";
NSString * const XTSessionUserInfoNotification = @"XTSessionUserInfoNotification";

@implementation XTSessionDelegate

+ (instancetype)sharedDelegate
{
    static XTSessionDelegate *sharedDelegate = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDelegate = [[self alloc] init];
        [WCSession defaultSession].delegate = sharedDelegate;
        [[WCSession defaultSession] activateSession];
    });
    return sharedDelegate;
}

- (void)requestUpdate
{
    if (   ![WCSession defaultSession].reachable
        || [WCSession defaultSession].activationState != WCSessionActivationStateActivated) {
        return;
    }

    CGRect bounds = [[WKInterfaceDevice currentDevice] screenBounds];
    CGFloat scale = [[WKInterfaceDevice currentDevice] screenScale];
    [[WCSession defaultSession] sendMessage:@{@"kind"   : @"requestImage",
                                              @"width"  : @(bounds.size.width),
                                              @"height" : @(bounds.size.height),
                                              @"scale"  : @(scale) }
                               replyHandler:nil
                               errorHandler:^(NSError *error){
                                   NSLog(@"requestUpdate: %@", error);
                               }];
}

- (void)sessionReachabilityDidChange:(WCSession *)session
{
    [[NSNotificationCenter defaultCenter]
                postNotificationName:XTSessionReachabilityDidChangeNotification
							  object:self];
}

- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error
{
    // TODO: figure out what they need.
}

- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary<NSString *,id> *)applicationContext
{
    [[NSNotificationCenter defaultCenter]
                postNotificationName:XTSessionAppContextNotification
							  object:self
                            userInfo:applicationContext];
}

// Warning Always test Watch Connectivity data transfers on paired devices
// The system doesn’t call the session:didReceiveUserInfo: method in Simulator.
- (void)session:(WCSession *)session didReceiveUserInfo:(NSDictionary<NSString *,id> *)userInfo
{
    [[NSNotificationCenter defaultCenter]
                postNotificationName:XTSessionUserInfoNotification
							  object:self
                            userInfo:userInfo];
}

@end
