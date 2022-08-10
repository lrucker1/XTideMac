//
//  XTSessionDelegate.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/5/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WatchConnectivity/WatchConnectivity.h>

extern NSString * const XTSessionReachabilityDidChangeNotification;
extern NSString * const XTSessionAppContextNotification;
extern NSString * const XTSessionUserInfoNotification;

@interface XTSessionDelegate : NSObject <WCSessionDelegate>

@property (strong) UIImage *image;
@property (strong) NSDictionary *info;

+ (instancetype)sharedDelegate;

- (void)requestUpdate;
- (NSDictionary *)complicationEvents;
- (NSDictionary *)complicationEventsAfterDate:(NSDate *)startDate includeRing:(BOOL)includeRing;
- (UIImage *)complicationImageWithSize:(CGFloat)size forDate:(NSDate *)date;

@end
