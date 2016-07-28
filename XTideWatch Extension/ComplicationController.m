//
//  ComplicationController.m
//  XTideWatch Extension
//
//  Created by Lee Ann Rucker on 7/2/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "ComplicationController.h"
#import "XTSessionDelegate.h"

@import WatchConnectivity;
@import WatchKit;

//static NSTimeInterval HOUR = 60 * 60;
// Show predicted complication 30 minutes before the event happens.
static NSTimeInterval EVENT_OFFSET = -30 * 60;
static NSTimeInterval DAY = 60 * 60 * 24;

@interface ComplicationController ()

@property (strong) NSArray *events;
@property (nonatomic) WCSession* watchSession;
@property BOOL isBigWatch;
@property (nonatomic) XTSessionDelegate *sessionDelegate;
@property (strong) UIColor *tintColor;
@property (strong) NSDate *lastStartTime;
@property (strong) NSMutableArray *replyHandlers;
@property (strong) NSString *lastStation;
// Set this when we're asking the phone for an extension.
// This will trigger an extendTimeline signal once the data arrives,
// whether it's sendMessage or transferRequest.
@property BOOL extendRequest;

@end

@implementation ComplicationController

- (instancetype)init
{
    self = [super init];
    _isBigWatch = [self isBigWatchCheck];
    _watchSession = [WCSession defaultSession];
    // 02B0CB
    _tintColor = [UIColor colorWithRed:0x02/255.0 green:0xB0/255.0 blue:0xCB/255.0 alpha:1.0];

    _sessionDelegate = [XTSessionDelegate sharedDelegate];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:XTSessionReachabilityDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveUserInfo:)
                                                 name:XTSessionUserInfoNotification
                                               object:nil];
    return self;
}


- (BOOL)isBigWatchCheck
{
    // The asset json file checks whether the width is <=145
    CGRect rect = [WKInterfaceDevice currentDevice].screenBounds;
    if (rect.size.height == 195.0) {
        return YES;
    } else if (rect.size.height == 170.0) {
        return NO;
    }
    // Assume it's big. It'll get scaled.
    NSLog(@"Unexpected Watch Size %f", rect.size.height);
    return YES;
}

- (void)reachabilityChanged:(NSNotification *)note
{
    if ([WCSession defaultSession].reachable && !self.events) {
        [self requestComplicationsWithReplyHandler:nil];
    }
}

- (void)didReceiveUserInfo:(NSNotification *)note
{
    [self updateEvents:[note userInfo] forCallback:NO];
}

#pragma mark - Timeline Configuration

// The time to show the event. Show it before the actual prediction by some reasonable offset.
- (NSDate *)timeForEvent:(NSDictionary * _Nullable)event
                  family:(CLKComplicationFamily)family
{
    if (!event) {
        return [NSDate date];
    }
    // Rings update at the event time. The others bracket the event.
    if ([self isRingFamily:family]) {
        return [event objectForKey:@"date"];
    }
    return [[event objectForKey:@"date"] dateByAddingTimeInterval:EVENT_OFFSET];
}

- (NSDate *)firstEventTimeForFamily:(CLKComplicationFamily)family
{
    return [self timeForEvent:[self firstEventForFamily:family] family:family];
}

// The time when the last event should dim, if we don't have any new ones,
// which should only happen if the phone was out of reach for 24 hours!
// This may be past latestTimeTravelDate; hopefully it won't complain.
- (NSDate *)lastEventTime
{
    // Add the same offset for all families.
    NSDictionary *event = [self.events lastObject];
    NSDate *date = [event objectForKey:@"date"];
    return [date dateByAddingTimeInterval:-EVENT_OFFSET];
}


- (void)getSupportedTimeTravelDirectionsForComplication:(CLKComplication *)complication withHandler:(void(^)(CLKComplicationTimeTravelDirections directions))handler
{
    handler(CLKComplicationTimeTravelDirectionForward|CLKComplicationTimeTravelDirectionBackward);
}

- (void)getTimelineStartDateForComplication:(CLKComplication *)complication withHandler:(void(^)(NSDate * __nullable date))handler
{
    [self requestComplicationsWithReplyHandler:^(BOOL isReady) {
        if (isReady) {
            handler([self firstEventTimeForFamily:complication.family]);
        } else {
            // Show the placeholder contents forever, or until the user picks a station.
            // It won't ask for anything else if you return "now"
            handler([[CLKComplicationServer sharedInstance] earliestTimeTravelDate]);
        }
    }];
}

// The last date for which we can supply data.
- (void)getTimelineEndDateForComplication:(CLKComplication *)complication withHandler:(void(^)(NSDate * __nullable date))handler
{
    [self requestComplicationsWithReplyHandler:^(BOOL isReady) {
        if (isReady) {
            handler([self lastEventTime]);
        } else {
            // Show the placeholder contents forever, or until the user picks a station.
            // Once it has a start and end date, it'll ask for Current and use it forever.
            handler([[CLKComplicationServer sharedInstance] latestTimeTravelDate]);
        }
    }];
}

- (void)getPrivacyBehaviorForComplication:(CLKComplication *)complication withHandler:(void(^)(CLKComplicationPrivacyBehavior privacyBehavior))handler
{
    handler(CLKComplicationPrivacyBehaviorShowOnLockScreen);
}

#pragma mark - Timeline Population

// isEqual or contains won't do; the prediction times might be slightly different.
- (BOOL)isEvent:(NSDictionary *)eventA matchingEvent:(NSDictionary *)eventB
{
    NSDate *dateA = [eventA objectForKey:@"date"];
    NSDate *dateB = [eventB objectForKey:@"date"];
    // Common code says the tolerance is 15 minutes, but we may have interpolated levels
    // that are closer.
    return (fabs([dateA timeIntervalSinceDate:dateB]) < (5 * 60));
}

- (void)updateEvents:(NSDictionary *)reply
         forCallback:(BOOL)forCallback
{
    NSString *station = [reply objectForKey:@"station"];
    if (!station) {
        // sendMessage doesn't call the callback if it gets a nil reply;
        // apparently it's assuming it's handling the no-callback version.
        return;
    }
    BOOL stationChange = self.lastStation != nil && ![station isEqualToString:self.lastStation];
    // This is a station change. Dump everything if we had a previous station.
    if (stationChange) {
        self.events = nil;
    }
    self.lastStation = station;
    [self processEvents:reply];

    // We don't want to reloadTimeline if there are handlers waiting to be called.
    if (self.extendRequest) {
        CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
        for (CLKComplication *complication in server.activeComplications) {
            [server extendTimelineForComplication:complication];
        }
    } else if (stationChange && !forCallback) {
        CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
        for (CLKComplication *complication in server.activeComplications) {
            [server reloadTimelineForComplication:complication];
        }
    }
    self.extendRequest = NO;
}

// Update the event array. Return YES if the events have changed.
- (BOOL)processEvents:(NSDictionary *)reply
{
    NSArray *newEvents = [reply objectForKey:@"events"];
    NSDate *startDate = [reply objectForKey:@"startDate"];
    if (!self.events) {
        self.events = newEvents;
        self.lastStartTime = startDate;
        return YES;
    }

    if ([startDate isEqualToDate:self.lastStartTime]) {
        // Same events, do nothing.
        return NO;
    }

    // Either the date or the station have changed.
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
    NSDate *earlyDate = [server earliestTimeTravelDate];
    NSMutableArray *events = [NSMutableArray array];
    // Add events that are still valid.
    for (NSDictionary *oldEvent in self.events) {
        if ([[oldEvent objectForKey:@"date"] compare:earlyDate] == NSOrderedDescending) {
            [events addObject:oldEvent];
        }
    }
    // Add new events that aren't already included.
    for (NSDictionary *newEvent in newEvents) {
        NSUInteger matchIndex = [events indexOfObjectPassingTest:^BOOL(id event, NSUInteger idx, BOOL *stop) {
            if ([self isEvent:event matchingEvent:newEvent]) {
                *stop = YES;
                return YES;
            }
            return NO;
        }];
        if (matchIndex == NSNotFound) {
            [events addObject:newEvent];
        }
    }
    self.events = events;
    self.lastStartTime = startDate;
    return YES;
}

- (NSDictionary *)eventRequestDictionary
{
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];

    // Always ask for the full range plus 1 day. It makes it easier to know when
    // we need to reload. We can't be sure in what order the requests will come.
    return @{@"kind" : @"requestEvents",
             @"first" : [server earliestTimeTravelDate],
             @"last" : [[server latestTimeTravelDate] dateByAddingTimeInterval:DAY]};
}

- (void)requestUserInfo
{
    // Cancel any pending requests; they may be out of date
    NSArray *oldRequests = [self.watchSession outstandingUserInfoTransfers];
    for (WCSessionUserInfoTransfer *xfer in oldRequests) {
        [xfer cancel];
    }
    self.extendRequest = YES;
    [self.watchSession transferUserInfo:[self eventRequestDictionary]];
}

- (BOOL)needsReload
{
    if (self.events == nil) {
        return YES;
    }
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
    NSDate *earlyDate = [server earliestTimeTravelDate];
    return [self.lastStartTime compare:earlyDate] == NSOrderedAscending;
}


/*
 * If the phone is reachable, send a message now.
 * If not, post a userInfo request for updates and reply with nil now.
 *
 * We want only one sendMessage in flight, so consolidate replyHandlers.
 */
- (void)requestComplicationsWithReplyHandler:(void (^)(BOOL isReady))replyHandler
{
    if (![self needsReload]) {
        if (replyHandler) {
            replyHandler(YES);
        }
        return;
    }

    if (!self.watchSession.reachable) {
        [self requestUserInfo];
        if (replyHandler) {
            replyHandler(self.events != nil);
        }
        return;
    }

    @synchronized (self) {
        if (self.replyHandlers) {
            if (replyHandler) {
                [self.replyHandlers addObject:[replyHandler copy]];
            }
            return;
        }
        self.replyHandlers = [NSMutableArray array];
        if (replyHandler) {
            [self.replyHandlers addObject:[replyHandler copy]];
        }
    }
    // Default handler merges the reply with the existing events.
    id defaultHandler = ^(NSDictionary *reply) {
        [self updateEvents:reply forCallback:[self.replyHandlers count] != 0];
        // If the reply was empty, we'll still have the old events. Old data is better than none.
        BOOL isReady = self.events != nil;
        @synchronized (self) {
            for (id handler in self.replyHandlers) {
               ((void (^)(BOOL))handler)(isReady);
            }
            self.replyHandlers = nil;
        }
    };

    [self.watchSession sendMessage:[self eventRequestDictionary]
                      replyHandler:defaultHandler
                      errorHandler:
        ^(NSError *error) {
            // If it timed out, do a userInfo request.
            if ([error.domain isEqualToString:@"WCErrorDomain"] && error.code == 7012) {
                [self requestUserInfo];
            }
            NSLog(@"%@", error);
            // Tell any handlers there's no data.
            @synchronized (self) {
                for (id handler in self.replyHandlers) {
                   ((void (^)(BOOL))handler)(NO);
                }
                self.replyHandlers = nil;
            }
        }];
}

- (BOOL)isRingFamily:(CLKComplicationFamily)family
{
    switch (family) {
        case CLKComplicationFamilyModularSmall:
        case CLKComplicationFamilyCircularSmall:
            return YES;
        default:
            return NO;
    }
}

// Although the event generator always starts with a standard event,
// we might lose it when we filter against earliestTime.
- (NSDictionary *)firstEventForFamily:(CLKComplicationFamily)family
{
    if ([self isRingFamily:family]) {
        return [self.events firstObject];
    }
    // A ringEvent only has date and angle.
    NSDictionary *dict = [self.events firstObject];
    if ([dict objectForKey:@"ringEvent"]) {
        if ([self.events count] > 1) {
            return [self.events objectAtIndex:1];
        }
        return nil;
    }
    return dict;
}

- (NSDictionary *)lastEventForFamily:(CLKComplicationFamily)family
{
    if ([self isRingFamily:family]) {
        return [self.events lastObject];
    }
    NSDictionary *dict = [self.events lastObject];
    if ([dict objectForKey:@"ringEvent"]) {
        if ([self.events count] > 1) {
            return [self.events objectAtIndex:[self.events count] - 2];
        }
        return nil;
    }
    return dict;
}

- (NSArray *)eventsForFamily:(CLKComplicationFamily)family
{
    if ([self isRingFamily:family]) {
        return self.events;
    }
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ringEvent == nil"];
    NSArray *results = [self.events filteredArrayUsingPredicate:predicate];
    return results;
}

- (NSDictionary *)currentEventForComplication:(CLKComplication *)complication
{
    NSDate *date = [NSDate date];
    NSArray *events = [self eventsForFamily:complication.family];
    NSDictionary *lastEvent = [self lastEventForFamily:complication.family];
    NSDictionary *lastTestedEvent = lastEvent;
    for (NSDictionary *event in events) {
        NSDate *testDate = [event objectForKey:@"date"];
        if ([testDate compare:date] == NSOrderedDescending) {
            return lastTestedEvent;
        }
        lastTestedEvent = event;
    }
    return lastEvent;
}

- (CLKComplicationTimelineEntry *)getCurrentTimelineEntryForComplication:(CLKComplication *)complication
{
    if (!self.events) {
        return nil;
    }
    NSDictionary *event = [self currentEventForComplication:complication];
    if (event) {
        return [self getEntryforComplication:complication withEvent:event];
    }
    return nil;
}

- (NSArray *)getTimelineEntriesForComplication:(CLKComplication *)complication
                                    beforeDate:(NSDate *)date
                                         limit:(NSUInteger)limit
{
    NSMutableArray *array = [NSMutableArray array];
    NSUInteger count = 0;
    CLKComplicationFamily family = complication.family;
    NSArray *events = [self eventsForFamily:complication.family];
    for (NSDictionary *event in [events reverseObjectEnumerator]) {
        NSDate *testDate = [self timeForEvent:event family:family];
        if ([testDate compare:date] == NSOrderedAscending) {
            [array addObject:[self getEntryforComplication:complication withEvent:event]];
            count++;
            if (count == limit) {
                break;
            }
        }
    }
    return array;
}

- (NSArray *)getTimelineEntriesForComplication:(CLKComplication *)complication
                                     afterDate:(NSDate *)date
                                         limit:(NSUInteger)limit
{
    NSMutableArray *array = [NSMutableArray array];
    NSUInteger count = 0;
    CLKComplicationFamily family = complication.family;
    NSArray *events = [self eventsForFamily:complication.family];
    for (NSDictionary *event in events) {
        NSDate *testDate = [self timeForEvent:event family:family];
        if ([testDate compare:date] == NSOrderedDescending) {
            [array addObject:[self getEntryforComplication:complication withEvent:event]];
            count++;
            if (count == limit) {
                break;
            }
        }
    }
    return array;
}

- (void)getCurrentTimelineEntryForComplication:(CLKComplication *)complication
                                   withHandler:(void(^)(CLKComplicationTimelineEntry * __nullable))handler
{
    // Call the handler with the current timeline entry
    [self requestComplicationsWithReplyHandler:^(BOOL isReady) {
        if (isReady) {
            handler([self getCurrentTimelineEntryForComplication:complication]);
        } else {
            // Icon-style complications use the asset image, but the text one needs text.
            handler([self getEntryforComplication:complication withEvent:nil]);
        }
    }];
}

- (void)getTimelineEntriesForComplication:(CLKComplication *)complication
                               beforeDate:(NSDate *)date
                                    limit:(NSUInteger)limit
                              withHandler:(void(^)(NSArray<CLKComplicationTimelineEntry *> * __nullable entries))handler
{
    // Call the handler with the timeline entries prior to the given date
    [self requestComplicationsWithReplyHandler:^(BOOL isReady) {
        if (isReady) {
            handler([self getTimelineEntriesForComplication:complication beforeDate:date limit:limit]);
        } else {
            handler(nil);
        }
    }];
}

- (void)getTimelineEntriesForComplication:(CLKComplication *)complication
                                afterDate:(NSDate *)date
                                    limit:(NSUInteger)limit
                              withHandler:(void(^)(NSArray<CLKComplicationTimelineEntry *> * __nullable entries))handler
{
    // Call the handler with the timeline entries after the given date
    [self requestComplicationsWithReplyHandler:^(BOOL isReady) {
        if (isReady) {
            handler ([self getTimelineEntriesForComplication:complication afterDate:date limit:limit]);
        } else {
            handler(nil);
        }
    }];
}

#pragma mark Update Scheduling

- (void)getNextRequestedUpdateDateWithHandler:(void(^)(NSDate * __nullable updateDate))handler
{
    // The server start/end dates are bound by local midnights
    // and we get the max possible, so anything more frequent is pointless.
    // We get one extra day, so we can update at the end of the current range.
    handler([[CLKComplicationServer sharedInstance] latestTimeTravelDate]);
}

- (void)requestedUpdateDidBegin
{
    // Our timeline always extends. Unlike the complications, we don't need to reply
    // immediately; we wait until the data arrives. So we don't pass a callback,
    // just set a flag.
    self.extendRequest = YES;
    [self requestComplicationsWithReplyHandler:nil];
}

- (void)requestedUpdateBudgetExhausted
{
    NSLog(@"requestedUpdateBudgetExhausted");
}

#pragma mark - Entry generator

- (CGFloat)angleForEvent:(NSDictionary *)event
{
    return [[event objectForKey:@"angle"] floatValue];
}

- (CLKSimpleTextProvider *)noEventTextProvider
{
    NSString *waiting = NSLocalizedString(@"No tide station", @"No tide station");
    NSString *waitingShort = NSLocalizedString(@"No station", @"No station");
    return [CLKSimpleTextProvider textProviderWithText:waiting shortText:waitingShort];
}

- (CLKSimpleTextProvider *)levelTextProviderForEvent:(NSDictionary * _Nullable)event
{
    if (!event) {
        return [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Level", @"Level placeholder")];
    }
    NSString *level = [event objectForKey:@"level"];
    NSString *levelShort = [event objectForKey:@"levelShort"];
    return [CLKSimpleTextProvider textProviderWithText:level shortText:levelShort];
}

- (CLKSimpleTextProvider *)descTextProviderForEvent:(NSDictionary * _Nullable)event
{
    if (!event) {
        return [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Tide Event", @"Tide event placeholder")
                                                 shortText:NSLocalizedString(@"Tide", @"Short Tide event placeholder")];
    }
    NSString *desc = [event objectForKey:@"desc"];
    NSString *descShort = [event objectForKey:@"descShort"];
    if (descShort) {
        return [CLKSimpleTextProvider textProviderWithText:desc shortText:descShort];
    }
    return [CLKSimpleTextProvider textProviderWithText:desc];
}

- (CLKImageProvider *)utilImageProviderForEvent:(NSDictionary * _Nullable)event
{
    // Only interpolated events have a "isRising" entry. Look in "type" for the icon name.
    UIImage *image = nil;
    if (event) {
        NSNumber *risingObj = [event objectForKey:@"isRising"];
        if (risingObj) {
            image = [self utilitarianIsRising:[risingObj boolValue]];
        } else {
            NSString *imgType = [event objectForKey:@"type"];
            if (imgType) {
                image = [UIImage imageNamed:imgType];
            }
        }
    } else {
        image = [UIImage imageNamed:@"hightide"];
    }
    if (image) {
        CLKImageProvider *imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:image];
        imageProvider.tintColor = self.tintColor;
        imageProvider.accessibilityLabel = [self imageAccessibilityLabelForEvent:event];
        return imageProvider;
    }
    NSLog(@"no image for event %@", event);
    return nil;
}

/*
 * SmallSimpleImage:
 *  Modular:  58 : 52
 *  Circular: 36 : 32
 * Utilitarian
 *  Flat:     20 : 18
 *  Square:   50 : 46
 */

- (NSString *)imageAccessibilityLabelForEvent:(NSDictionary * _Nullable)event
{
    if (!event) {
        return @"";
    }
    return [NSString stringWithFormat:@"%@%@", [event objectForKey:@"desc"], [event objectForKey:@"level"]];
}

- (CLKImageProvider *)ringImageProviderForEvent:(NSDictionary * _Nullable)event
                                         family:(CLKComplicationFamily)family

{
    CGFloat rectSize = 0;
    CGFloat lineWidth = 4;
    if (family == CLKComplicationFamilyModularSmall) {
        rectSize = self.isBigWatch ? 58 : 52;
    } else if (family == CLKComplicationFamilyCircularSmall) {
        rectSize = self.isBigWatch ? 36 : 32;
        lineWidth = 2;
    } else {
        return nil;
    }
    CGFloat angle = [self angleForEvent:event]; // Zero for placeholders with nil events.
    UIImage *ring = [self ringWithRectSize:rectSize lineWidth:lineWidth];
    UIImage *hand = [self handWithRectSize:rectSize lineWidth:lineWidth angle:angle includeRing:NO];
    UIImage *bgImage = [self handWithRectSize:rectSize lineWidth:lineWidth angle:angle includeRing:YES];
    CLKImageProvider *imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:bgImage twoPieceImageBackground:ring twoPieceImageForeground:hand];
    imageProvider.tintColor = self.tintColor;
    imageProvider.accessibilityLabel = [self imageAccessibilityLabelForEvent:event];
    return imageProvider;
}


- (UIImage *)utilitarianIsRising:(BOOL)isRising
{
    return [UIImage imageNamed:isRising ? @"upArrowImage" : @"downArrowImage"];
}

- (UIImage *)ringWithRectSize:(CGFloat)rectSize
                    lineWidth:(CGFloat)lineWidth
{
    CGRect rect = CGRectMake(0, 0, rectSize, rectSize);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetStrokeColorWithColor(context, [[UIColor blackColor] CGColor]);
    CGContextSetLineWidth(context, lineWidth);

    CGRect edgeRect = CGRectInset(rect, 2, 2);
    CGContextStrokeEllipseInRect(context, edgeRect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (UIImage *)handWithRectSize:(CGFloat)rectSize
                    lineWidth:(CGFloat)lineWidth
                        angle:(CGFloat)radians
                  includeRing:(BOOL)includeRing
{
    CGFloat dotInset = (rectSize - lineWidth * 2) / 2;
    CGRect rect = CGRectMake(0, 0, rectSize, rectSize);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, [[UIColor blackColor] CGColor]);
    CGContextSetStrokeColorWithColor(context, [[UIColor blackColor] CGColor]);
    CGFloat radius = rectSize / 2;
    CGPoint center = CGPointMake(radius, radius);
    CGContextSetLineWidth(context, lineWidth);

    CGRect dotRect = CGRectInset(rect, dotInset, dotInset);
    CGContextFillEllipseInRect(context, dotRect);

    UIBezierPath *arm = [UIBezierPath bezierPath];
    [arm moveToPoint:CGPointZero];
    [arm addLineToPoint:CGPointMake(0, -(radius - lineWidth - 4))];
    arm.lineWidth = lineWidth;
    arm.lineCapStyle = kCGLineCapRound;
    CGAffineTransform position = CGAffineTransformMakeTranslation(center.x, center.y);
    position = CGAffineTransformRotate(position, radians);
    [arm applyTransform:position];
    [arm stroke];

    if (includeRing) {
        CGRect edgeRect = CGRectInset(rect, 2, 2);
        CGContextStrokeEllipseInRect(context, edgeRect);
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (CLKTextProvider *)dateProviderForEvent:(NSDictionary * _Nullable)event
{
    if (!event) {
        // Using a relative date here makes it show the date relative to when the
        // placeholder was made. It's weird.
        return [CLKTimeTextProvider textProviderWithDate:[NSDate date]];
    }
    // For level events, show the upcoming event with a relative date.
    // For predicted events, just show the event's relative date.
    NSDictionary *next = [event objectForKey:@"next"];
    if (next) {
        CLKSimpleTextProvider *nextDesc = [self descTextProviderForEvent:next];
        CLKRelativeDateTextProvider *dateText =
            [CLKRelativeDateTextProvider textProviderWithDate:[next objectForKey:@"date"]
                                                        style:CLKRelativeDateStyleNatural
                                                        units:NSCalendarUnitHour | NSCalendarUnitMinute];
        return [CLKTextProvider textProviderWithFormat:@"%@ %@", nextDesc, dateText];
    }
    return [CLKTimeTextProvider textProviderWithDate:[event objectForKey:@"date"]];
}

// The actual placeholder text shows up in Customize and should be meaningful.
- (CLKComplicationTimelineEntry *)getEntryforComplication:(CLKComplication *)complication
                                                withEvent:(NSDictionary * _Nullable)event
{
    CLKComplicationTemplate *template = nil;
    switch (complication.family) {
    case CLKComplicationFamilyModularLarge:
        {
        CLKComplicationTemplateModularLargeStandardBody *large =
            [[CLKComplicationTemplateModularLargeStandardBody alloc] init];
        large.headerImageProvider = [self utilImageProviderForEvent:event];
        if (event) {
            large.headerTextProvider = [self descTextProviderForEvent:event];
            large.body1TextProvider = [self levelTextProviderForEvent:event];
            large.body2TextProvider = [self dateProviderForEvent:event];
        } else {
            large.headerTextProvider = [self noEventTextProvider];
            large.body1TextProvider =
                [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Waiting for station information", @"Waiting for station information")];
            // body1 will overflow into body2 if it needs to.
        }
        template = large;
        }
        break;
    case CLKComplicationFamilyModularSmall:
        {
        CLKComplicationTemplateModularSmallSimpleImage *small =
            [[CLKComplicationTemplateModularSmallSimpleImage alloc] init];
        small.imageProvider = [self ringImageProviderForEvent:event family:complication.family];
        template = small;
        }
        break;
    case CLKComplicationFamilyUtilitarianLarge:
        {
        CLKComplicationTemplateUtilitarianLargeFlat *large =
            [[CLKComplicationTemplateUtilitarianLargeFlat alloc] init];
        if (event) {
            large.textProvider = [CLKTextProvider textProviderWithFormat:@"%@ %@",
                                                    [self descTextProviderForEvent:event],
                                                    [self levelTextProviderForEvent:event]];
        } else {
            large.textProvider = [self noEventTextProvider];
        }
        large.imageProvider = [self utilImageProviderForEvent:event];
        template = large;
        }
        break;
    case CLKComplicationFamilyUtilitarianSmall:
        {
        CLKComplicationTemplateUtilitarianSmallFlat *small =
            [[CLKComplicationTemplateUtilitarianSmallFlat alloc] init];
        small.imageProvider = [self utilImageProviderForEvent:event];
        if (event) {
            small.textProvider = [self levelTextProviderForEvent:event];
        } else {
            small.textProvider = [self noEventTextProvider];
        }
        template = small;
        }
       break;
    case CLKComplicationFamilyCircularSmall:
        {
        CLKComplicationTemplateCircularSmallSimpleImage *small =
            [[CLKComplicationTemplateCircularSmallSimpleImage alloc] init];
        small.imageProvider = [self ringImageProviderForEvent:event family:complication.family];
        template = small;
        }
        break;
    }

    return [CLKComplicationTimelineEntry entryWithDate:[self timeForEvent:event family:complication.family]
                                  complicationTemplate:template];
}

#pragma mark - Placeholder Templates

- (void)getPlaceholderTemplateForComplication:(CLKComplication *)complication
                                  withHandler:(void(^)(CLKComplicationTemplate * __nullable complicationTemplate))handler
{
    // This method will be called once per supported complication, and the results will be cached
    CLKComplicationTemplate *template = nil;
    switch (complication.family) {
    case CLKComplicationFamilyModularLarge:
        {
        CLKComplicationTemplateModularLargeStandardBody *large =
            [[CLKComplicationTemplateModularLargeStandardBody alloc] init];
        large.headerTextProvider = [self descTextProviderForEvent:nil];
        large.headerImageProvider = [self utilImageProviderForEvent:nil];
        large.body1TextProvider = [self levelTextProviderForEvent:nil];
        large.body2TextProvider = [self dateProviderForEvent:nil];
        template = large;
        }
        break;
    case CLKComplicationFamilyModularSmall:
        {
        CLKComplicationTemplateModularSmallSimpleImage *small =
            [[CLKComplicationTemplateModularSmallSimpleImage alloc] init];
        small.imageProvider = [self ringImageProviderForEvent:nil family:complication.family];
        template = small;
        }
        break;
    case CLKComplicationFamilyUtilitarianLarge:
        {
        CLKComplicationTemplateUtilitarianLargeFlat *large =
            [[CLKComplicationTemplateUtilitarianLargeFlat alloc] init];
        large.textProvider = [self descTextProviderForEvent:nil];
        large.imageProvider = [self utilImageProviderForEvent:nil];
        template = large;
        }
        break;
    case CLKComplicationFamilyUtilitarianSmall:
        {
        CLKComplicationTemplateUtilitarianSmallFlat *small =
            [[CLKComplicationTemplateUtilitarianSmallFlat alloc] init];
        small.textProvider = [self descTextProviderForEvent:nil];
        small.imageProvider = [self utilImageProviderForEvent:nil];
        template = small;
        }
        break;
    case CLKComplicationFamilyCircularSmall:
        {
        CLKComplicationTemplateCircularSmallSimpleImage *small =
            [[CLKComplicationTemplateCircularSmallSimpleImage alloc] init];
        small.imageProvider = [self ringImageProviderForEvent:nil family:complication.family];
        template = small;
        }
        break;
    }
    handler(template);
}

@end
