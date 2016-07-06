//
//  XTSessionDelegate.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/5/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <Foundation/Foundation.h>

@import WatchConnectivity;

extern NSString * const XTSessionReachabilityDidChangeNotification;
extern NSString * const XTSessionAppContextNotification;
extern NSString * const XTSessionUserInfoNotification;

@interface XTSessionDelegate : NSObject <WCSessionDelegate>

+ (instancetype)sharedDelegate;

@end
