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

static NSTimeInterval HOUR = 60 * 60;
// Show the complication 10 minutes before the event happens.
static NSTimeInterval EVENT_OFFSET = -10 * 60;
//static NSTimeInterval DAY = 60 * 60 * 24;

@interface ComplicationController ()

@property (strong) NSArray *events;
@property (strong) NSArray *oldEvents;
@property (nonatomic) WCSession* watchSession;
@property BOOL isBigWatch;
@property (nonatomic) XTSessionDelegate *sessionDelegate;
@property (strong) UIColor *tintColor;
@property (strong) NSDate *lastEndTime;
@property (strong) NSMutableArray *replyHandlers;

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

- (void)loadEvents
{
    if (!self.events) {
        [self requestComplicationsWithReplyHandler:nil];
    }
}


- (void)reachabilityChanged:(NSNotification *)note
{
    if ([WCSession defaultSession].reachable) {
        [self loadEvents];
    }
}

- (void)didReceiveUserInfo:(NSNotification *)note
{
    NSDictionary *userInfo = [note userInfo];
    self.events = [userInfo objectForKey:@"events"];
}

#pragma mark - Timeline Configuration

// The time to show the event; offset to a few minutes before it happens.
- (NSDate *)timeForEvent:(NSDictionary *)event
{
    return [[event objectForKey:@"date"] dateByAddingTimeInterval:EVENT_OFFSET];
}

- (NSDate *)firstEventTime
{
    return [self timeForEvent:[self.events firstObject]];
}

// The time when the last event should dim, if we don't have any new ones.
- (NSDate *)lastEventTime
{
    NSDictionary *event = [self.events lastObject];
    NSDate *date = [event objectForKey:@"date"];
    return [date dateByAddingTimeInterval:HOUR];
}


- (void)getSupportedTimeTravelDirectionsForComplication:(CLKComplication *)complication withHandler:(void(^)(CLKComplicationTimeTravelDirections directions))handler
{
    handler(CLKComplicationTimeTravelDirectionForward|CLKComplicationTimeTravelDirectionBackward);
}

- (void)getTimelineStartDateForComplication:(CLKComplication *)complication withHandler:(void(^)(NSDate * __nullable date))handler
{
    if (!self.events) {
        [self requestComplicationsWithReplyHandler:^(NSDictionary *reply) {
            if (reply) {
                handler([self firstEventTime]);
            } else {
                handler(nil);
            }
        }];
        return;
    }
    handler([self firstEventTime]);
}

// The last date for which we currently have data. It will dim after this if it doesn't update.
- (void)getTimelineEndDateForComplication:(CLKComplication *)complication withHandler:(void(^)(NSDate * __nullable date))handler
{
    if (!self.events) {
        [self requestComplicationsWithReplyHandler:^(NSDictionary *reply) {
            if (reply) {
                handler([self lastEventTime]);
            } else {
                handler(nil);
            }
        }];
        return;
    }
    handler([self lastEventTime]);
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

- (void)updateEvents:(NSArray *)newEvents
{
    if (!self.oldEvents) {
        self.events = newEvents;
        return;
    }

    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
    NSDate *earlyDate = [server earliestTimeTravelDate];
    NSMutableArray *events = [NSMutableArray array];
    // Add events that are still valid.
    for (NSDictionary *oldEvent in self.oldEvents) {
        if ([[self timeForEvent:oldEvent] compare:earlyDate] == NSOrderedDescending) {
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
    self.oldEvents = nil;
}

// We want only one sendMessage in flight.
- (void)requestComplicationsWithReplyHandler:(void (^)(NSDictionary<NSString *,id> *replyMessage))replyHandler
{
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
    // Default handler sets the "events" array and merges it with any previous events.
    id defaultHandler = ^(NSDictionary *reply) {
        if (reply) {
            [self updateEvents:[reply objectForKey:@"events"]];
        }
        @synchronized (self) {
            for (id handler in self.replyHandlers) {
               ((void (^)(NSDictionary<NSString *,id> *replyMessage))handler)(reply);
            }
            self.replyHandlers = nil;
        }
    };

    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
    NSDate *earlyDate = [server earliestTimeTravelDate];

    // If the last update happened before the current window, clear the old data.
    if ([self.lastEndTime compare:earlyDate] == NSOrderedAscending) {
        self.lastEndTime = nil;
        self.oldEvents = nil;
    }
    NSDate *startTime = self.lastEndTime ? self.lastEndTime: earlyDate;
    self.lastEndTime = [server latestTimeTravelDate];

    // TODO: make sure start and end aren't the same.
    [self.watchSession sendMessage:@{@"kind" : @"requestEvents",
                                     @"first" : startTime,
                                     @"last" : self.lastEndTime }
                      replyHandler:defaultHandler
                      errorHandler:nil];
}

- (NSDictionary *)currentEventForComplication:(CLKComplication *)complication
{
    NSDate *date = [NSDate date];
    NSDictionary *lastEvent = [self.events firstObject];
    for (NSDictionary *event in self.events) {
        NSDate *testDate = [event objectForKey:@"date"];
        if ([testDate compare:date] == NSOrderedDescending) {
            return lastEvent;
        }
        lastEvent = event;
    }
    return [self.events lastObject];
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
    for (NSDictionary *event in [self.events reverseObjectEnumerator]) {
        NSDate *testDate = [self timeForEvent:event];
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
    for (NSDictionary *event in self.events) {
        NSDate *testDate = [self timeForEvent:event];
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
    if (!self.events) {
        [self requestComplicationsWithReplyHandler:^(NSDictionary *reply) {
            if (reply) {
                handler([self getCurrentTimelineEntryForComplication:complication]);
            } else {
                // TODO: get a "no station" placeholder.
                handler(nil);
            }
        }];
        return;
    }
    // Call the handler with the current timeline entry
    handler ([self getCurrentTimelineEntryForComplication:complication]);
}

- (void)getTimelineEntriesForComplication:(CLKComplication *)complication
                               beforeDate:(NSDate *)date
                                    limit:(NSUInteger)limit
                              withHandler:(void(^)(NSArray<CLKComplicationTimelineEntry *> * __nullable entries))handler
{
    // Call the handler with the timeline entries prior to the given date
    if (!self.events) {
        [self requestComplicationsWithReplyHandler:^(NSDictionary *reply) {
            if (reply) {
                handler([self getTimelineEntriesForComplication:complication beforeDate:date limit:limit]);
            } else {
                handler(nil);
            }
        }];
        return;
    }
    handler ([self getTimelineEntriesForComplication:complication beforeDate:date limit:limit]);
}

- (void)getTimelineEntriesForComplication:(CLKComplication *)complication
                                afterDate:(NSDate *)date
                                    limit:(NSUInteger)limit
                              withHandler:(void(^)(NSArray<CLKComplicationTimelineEntry *> * __nullable entries))handler
{
    // Call the handler with the timeline entries prior to the given date
    if (!self.events) {
        [self requestComplicationsWithReplyHandler:^(NSDictionary *reply) {
            if (reply) {
                handler ([self getTimelineEntriesForComplication:complication afterDate:date limit:limit]);
            } else {
                handler(nil);
            }
        }];
        return;
    }
    handler([self getTimelineEntriesForComplication:complication afterDate:date limit:limit]);
}

#pragma mark Update Scheduling

- (void)getNextRequestedUpdateDateWithHandler:(void(^)(NSDate * __nullable updateDate))handler
{
    // Get updates when there's 1 day left to go.
    // The server start/end dates are bound by local midnights
    // and we get the max possible, so anything more frequent is pointless.
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
    NSDate *next = [[server latestTimeTravelDate] dateByAddingTimeInterval:-HOUR * 24];
    // For the odd chance that we've already passed "next".
    NSDate *datePlus6 = [[NSDate date] dateByAddingTimeInterval:HOUR * 6];
    handler([datePlus6 laterDate:next]);
}

- (void)requestedUpdateDidBegin
{
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];

    self.oldEvents = self.events;
    self.events = nil;

    for (CLKComplication *complication in server.activeComplications) {
        [server extendTimelineForComplication:complication];
    }
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

- (CLKSimpleTextProvider *)levelTextProviderForEvent:(NSDictionary *)event
{
    NSString *level = [event objectForKey:@"level"];
    NSString *levelShort = [event objectForKey:@"levelShort"];
    return [CLKSimpleTextProvider textProviderWithText:level shortText:levelShort];
}

- (CLKSimpleTextProvider *)descTextProviderForEvent:(NSDictionary *)event
{
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
        return imageProvider;
    }
    NSLog(@"no image for event %@", event);
    return nil;
}

/*
 * SmallSimpleImage:
 *  Modular:  58 : 52
 *  Circular: 36 : 32
 * Utilitarian:
 *  Flat:     20 : 18
 *  Square:   50 : 46
 */

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

// TODO: if event is nil, provide "Waiting" placeholder text.
// The actual placeholder text shows up in Customize and should be meaningful.
- (CLKComplicationTimelineEntry *)getEntryforComplication:(CLKComplication *)complication
                                                withEvent:(NSDictionary *)event
{
    CLKComplicationTemplate *template = nil;
    NSDate *date = [event objectForKey:@"date"];
    switch (complication.family) {
    case CLKComplicationFamilyModularLarge:
        {
        CLKComplicationTemplateModularLargeStandardBody *large =
            [[CLKComplicationTemplateModularLargeStandardBody alloc] init];
        large.headerTextProvider = [self descTextProviderForEvent:event];
        large.headerImageProvider = [self utilImageProviderForEvent:event];
        large.body1TextProvider = [self levelTextProviderForEvent:event];
        large.body2TextProvider = [CLKTimeTextProvider textProviderWithDate:date];
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
        NSString *desc = [event objectForKey:@"desc"];
        NSString *descShort = [event objectForKey:@"descShort"];
        // Level starts with spaces.
        NSString *level = [event objectForKey:@"level"];
        NSString *levelShort = [event objectForKey:@"levelShort"];
        NSString *combo = [NSString stringWithFormat:@"%@%@", desc, level];
        NSString *comboShort = [NSString stringWithFormat:@"%@%@", descShort, levelShort];
        
        large.textProvider = [CLKSimpleTextProvider textProviderWithText:combo shortText:comboShort];
        large.imageProvider = [self utilImageProviderForEvent:event];
        template = large;
        }
        break;
    case CLKComplicationFamilyUtilitarianSmall:
        {
        CLKComplicationTemplateUtilitarianSmallFlat *small =
            [[CLKComplicationTemplateUtilitarianSmallFlat alloc] init];
        small.imageProvider = [self utilImageProviderForEvent:event];
        if (small.imageProvider) {
            // It's a level event.
            small.textProvider = [self levelTextProviderForEvent:event];
        } else {
            // It's a min/max event.
            small.textProvider = [self descTextProviderForEvent:event];
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

    // Show the complication a few minutes before the event.
    return [CLKComplicationTimelineEntry entryWithDate:[self timeForEvent:event]
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
        large.headerTextProvider = [CLKSimpleTextProvider textProviderWithText:@"Tide Event"];
        large.headerImageProvider = [self utilImageProviderForEvent:nil];
        large.body1TextProvider = [CLKSimpleTextProvider textProviderWithText:@"Level"];
        large.body2TextProvider = [CLKTimeTextProvider textProviderWithDate:[NSDate date]];
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
        large.textProvider = [CLKSimpleTextProvider textProviderWithText:@"Tide Event"];
        large.imageProvider = [self utilImageProviderForEvent:nil];
        template = large;
        }
        break;
    case CLKComplicationFamilyUtilitarianSmall:
        {
        CLKComplicationTemplateUtilitarianSmallFlat *small =
            [[CLKComplicationTemplateUtilitarianSmallFlat alloc] init];
        small.textProvider = [CLKSimpleTextProvider textProviderWithText:@"Tide Event" shortText:@"Tide"];
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
