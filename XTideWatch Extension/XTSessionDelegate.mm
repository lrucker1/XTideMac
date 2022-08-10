//
//  XTSessionDelegate.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/5/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import "XTSessionDelegate.h"
#import "XTStationInt.h"
#import "XTSettings.h"

NSString * const XTSessionReachabilityDidChangeNotification = @"XTSessionReachabilityDidChangeNotification";
NSString * const XTSessionAppContextNotification = @"XTSessionAppContextNotification";
NSString * const XTSessionUserInfoNotification = @"XTSessionUserInfoNotification";
NSString * const XTDefaults_stationDict = @"stationDict";

static NSTimeInterval DAY = 60 * 60 * 24;
static NSTimeInterval HOUR = 60 * 60;

@interface XTSessionDelegate ()

@property (strong) NSDictionary *stationDict;
@property (strong) XTStation *currentStation;

@end

@implementation XTSessionDelegate

+ (instancetype)sharedDelegate
{
    static XTSessionDelegate *sharedDelegate = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDelegate = [[self alloc] init];
        [WCSession defaultSession].delegate = sharedDelegate;
        [[WCSession defaultSession] activateSession];
        [sharedDelegate loadDefaults];
    });
    return sharedDelegate;
}


- (void)loadDefaults {
    RegisterUserDefaults(nil);
    XTSettings_SetDefaults(@{@"em":@"pSsMm"}); // eventmask to exclude non-tide events

    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:XTDefaults_stationDict];
    if (dict == nil) {
       // The C++ object appears to be going poof. C++ lifespan...
        NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
        NSString *path = [thisBundle pathForResource:@"defaultStation" ofType:@"xml"];
        if (path != nil) {
            dict = [[NSDictionary alloc] initWithContentsOfFile:path];
        } else {
            NSLog(@"Missing station data resource");
        }
    }
    //NSLog(@"%@", dict);
    self.stationDict = dict;
}

- (XTStation *)station
{
    if (self.currentStation == nil) {
        if (self.stationDict) {
            self.currentStation = [[XTStation alloc] initUsingDictionary:self.stationDict];
        }
    }
    return self.currentStation;
}

- (void)requestUpdate
{
    XTStation *station = [self station];
    if (station) {
        CGRect bounds = [[WKInterfaceDevice currentDevice] screenBounds];
        self.info = [station clockInfoWithXSize:bounds.size.width ysize:bounds.size.height - 40 scale:2];
        self.image = self.info[@"clockImage"];
    }
}

- (UIImage *)complicationImageWithSize:(CGFloat)size forDate:(NSDate *)date
{
    XTStation *station = [self station];
    NSDictionary *info = [station iconInfoWithSize:size scale:2 forDate:date];
    return info[@"iconImage"];
}

// Generic events for all near-future complications.
- (NSDictionary *)complicationEvents
{
    // Start *before* now, because complications won't show future events.
    return [self complicationEventsAfterDate:[NSDate dateWithTimeIntervalSinceNow:-6 * HOUR] includeRing:YES];
}

- (NSDictionary *)complicationEventsAfterDate:(NSDate *)startDate
                                  includeRing:(BOOL)includeRing
{
    XTStation *station = [self station];
    if (!station) {
        return [NSDictionary dictionary];
    }
    // Return 1 day. Time travel is gone; we don't need the past, and we can generate on demand. Also the watch will keep asking until we hit the limit. Caller filters to limit, which depends on complication type.
    NSDate *endDate = [startDate dateByAddingTimeInterval:DAY];

    NSArray *events = [station generateWatchEventsStart:startDate
                                                    end:endDate
                                            includeRing:includeRing];
    if (events) {
        return @{@"events" : events,
                 @"startDate" : startDate,
                 @"endDate" : endDate,
                 @"station" : station.name};
    }
    return [NSDictionary dictionary];
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

- (void)updateStationDict:(NSDictionary *)dict {
    if (dict == nil) {
        return;
    }
    XTStation *station = [[XTStation alloc] initUsingDictionary:dict];
    if (station != nil && (self.stationDict == nil || ![station.name isEqualToString:self.stationDict[@"name"]])) {
        self.stationDict = dict;
        self.currentStation = station;
        [[NSUserDefaults standardUserDefaults] setObject:dict forKey:XTDefaults_stationDict];
        [[NSNotificationCenter defaultCenter]
            postNotificationName:XTSessionUserInfoNotification
            object:self];
    }
}

- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary<NSString *,id> *)applicationContext
{
    if (applicationContext) {
        [self updateStationDict:applicationContext];
    }
}

// Warning Always test Watch Connectivity data transfers on paired devices
// The system doesn’t call the session:didReceiveUserInfo: method in Simulator.
- (void)session:(WCSession *)session didReceiveUserInfo:(NSDictionary<NSString *,id> *)userInfo
{
    if (userInfo) {
        [self updateStationDict:userInfo];
    }
}


@end
