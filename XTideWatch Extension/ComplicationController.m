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
@property (nonatomic) WCSession* watchSession;
@property BOOL isBigWatch;
@property (nonatomic) XTSessionDelegate *sessionDelegate;
@property (strong) UIColor *tintColor;

@end

@implementation ComplicationController

- (instancetype)init
{
    self = [super init];
    _isBigWatch = [self isBigWatchCheck];
    _watchSession = [WCSession defaultSession];
    _tintColor = [UIColor colorWithRed:24/255.0 green:215/255.0 blue:222/255.0 alpha:1.0];

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
        [self requestComplicationsWithReplyHandler:^(NSDictionary *reply) {
            if (reply) {
                self.events = [reply objectForKey:@"events"];
            }
        }];
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
                self.events = [reply objectForKey:@"events"];
                handler([self firstEventTime]);
            } else {
                // TODO: get a "no station" placeholder.
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
                self.events = [reply objectForKey:@"events"];
                handler([self lastEventTime]);
            } else {
                // TODO: get a "no station" placeholder.
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

- (void)requestComplicationsWithReplyHandler:(void (^)(NSDictionary<NSString *,id> *replyMessage))replyHandler
{
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];

    [self.watchSession sendMessage:@{@"kind" : @"requestEvents",
                                     @"first" : [server earliestTimeTravelDate],
                                     @"last" : [server latestTimeTravelDate] }
                      replyHandler:replyHandler
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
                self.events = [reply objectForKey:@"events"];
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
                self.events = [reply objectForKey:@"events"];
                handler([self getTimelineEntriesForComplication:complication beforeDate:date limit:limit]);\
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
                self.events = [reply objectForKey:@"events"];
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
    // Get updates every 24 hours. The server start/end dates are bound by local midnights
    // and we get the max possible, so anything more frequent is pointless.
    handler([NSDate dateWithTimeIntervalSinceNow:HOUR * 24]);
}

- (void)requestedUpdateDidBegin
{
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
 
    self.events = nil;

    // "extend" might be more appropriate than "reload", but the Organizer is long gone
    // so we'd have to do the checks to detect duplicates at the boundary time ourselves.
    // We shouldn't update that often, since we get complications for the max allowed range.
    // We also only get a max of ~24 events per day.
    for (CLKComplication *complication in server.activeComplications) {
        [server reloadTimelineForComplication:complication];
    }
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
    // min/max events have no "isRising" entry. Look in "type" for "hightide" and "lowtide"
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
    // slackrise/fall have no image because the text is long.
    //NSLog(@"no image for event %@", event);
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

    // TODO: Having a line with end caps would be prettier.
    UIBezierPath *arm = [UIBezierPath bezierPathWithRect:
            CGRectMake(-lineWidth / 2, 0, lineWidth, -(radius - (lineWidth * 2)))];
    CGAffineTransform position = CGAffineTransformMakeTranslation(center.x, center.y);
    position = CGAffineTransformRotate(position, radians);
    [arm applyTransform:position];
    [arm fill];

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
