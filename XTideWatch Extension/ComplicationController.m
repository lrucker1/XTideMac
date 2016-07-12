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
//static NSTimeInterval MINUTE = 60;
static NSTimeInterval DAY = 60 * 60 * 24;

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
    _tintColor = [UIColor colorWithRed:0 green:255 blue:128 alpha:1];

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

/*
 * SmallSimpleImage:
 *  Modular:  58 : 52
 *  Circular: 36 : 32
 * Utilitarian:
 *  Flat:     20 : 18
 *  Square:   50 : 46
 */

- (UIImage *)utilitarianIsRising:(BOOL)isRising
{
    return [UIImage imageNamed:isRising ? @"upArrowImage" : @"downArrowImage"];
}

- (UIImage *)modularSmallDotWithAngle:(CGFloat)radians
{
    return [self dotWithRectSize:self.isBigWatch ? 58 : 52
                       lineWidth:4
                           angle:radians];
}


- (UIImage *)circularSmallDotWithAngle:(CGFloat)radians
{
    return [self dotWithRectSize:self.isBigWatch ? 36 : 32
                       lineWidth:2
                           angle:radians];
}

- (UIImage *)dotWithRectSize:(CGFloat)rectSize
                   lineWidth:(CGFloat)lineWidth
                       angle:(CGFloat)radians
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

    // TODO: Use a two-part image with these two lines as the background part (and only built once per size)
    // so that we have a tinted ring with a white indicator.
    CGRect edgeRect = CGRectInset(rect, 2, 2);
    CGContextStrokeEllipseInRect(context, edgeRect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}


- (void)requestComplicationsWithReplyHandler:(void (^)(NSDictionary<NSString *,id> *replyMessage))replyHandler
{
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];

    [self.watchSession sendMessage:@{@"kind" : @"requestEvents",
                                     @"first" : [server earliestTimeTravelDate],
                                     @"last" : [server latestTimeTravelDate] }
                      replyHandler:replyHandler
                      errorHandler:nil];
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


- (void)getSupportedTimeTravelDirectionsForComplication:(CLKComplication *)complication withHandler:(void(^)(CLKComplicationTimeTravelDirections directions))handler
{
    handler(CLKComplicationTimeTravelDirectionForward|CLKComplicationTimeTravelDirectionBackward);
}

- (void)getTimelineStartDateForComplication:(CLKComplication *)complication withHandler:(void(^)(NSDate * __nullable date))handler
{
    handler([NSDate dateWithTimeIntervalSinceNow:-DAY]);
}

- (void)getTimelineEndDateForComplication:(CLKComplication *)complication withHandler:(void(^)(NSDate * __nullable date))handler
{
    handler([NSDate dateWithTimeIntervalSinceNow:DAY * 2]);
}

- (void)getPrivacyBehaviorForComplication:(CLKComplication *)complication withHandler:(void(^)(CLKComplicationPrivacyBehavior privacyBehavior))handler
{
    handler(CLKComplicationPrivacyBehaviorShowOnLockScreen);
}

#pragma mark - Timeline Population

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
        NSDate *testDate = [event objectForKey:@"date"];
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
        NSDate *testDate = [event objectForKey:@"date"];
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
    // Call the handler with the date when you would next like to be given the opportunity to update your complication content
    // Every 12 hours should be enough to pick up new events.
    handler([NSDate dateWithTimeIntervalSinceNow:HOUR * 12]);
}

- (void)requestedUpdateDidBegin
{
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];

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

- (CLKImageProvider *)utilImageProviderForEvent:(NSDictionary *)event
{
    // min/max events have no "isRising" entry. Look in "type" for "hightide" and "lowtide"
    NSNumber *risingObj = [event objectForKey:@"isRising"];
    UIImage *image = nil;
    if (risingObj) {
        image = [self utilitarianIsRising:[risingObj boolValue]];
    } else {
        NSString *imgType = [event objectForKey:@"type"];
        if (imgType) {
            image = [UIImage imageNamed:imgType];
        }
    }
    if (image) {
        return [CLKImageProvider imageProviderWithOnePieceImage:image];
    }
    // slackrise/fall have no image because the text is long.
    //NSLog(@"no image for event %@", event);
    return nil;
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
        large.headerImageProvider.tintColor = self.tintColor;
        large.body1TextProvider = [self levelTextProviderForEvent:event];
        large.body2TextProvider = [CLKTimeTextProvider textProviderWithDate:date];
        template = large;
        }
        break;
    case CLKComplicationFamilyModularSmall:
        {
        CLKComplicationTemplateModularSmallSimpleImage *small =
            [[CLKComplicationTemplateModularSmallSimpleImage alloc] init];
        CGFloat angle = [self angleForEvent:event];
        small.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[self modularSmallDotWithAngle:angle]];
        small.imageProvider.tintColor = self.tintColor;
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
        large.imageProvider.tintColor = self.tintColor;
        template = large;
        }
        break;
    case CLKComplicationFamilyUtilitarianSmall:
         {
        CLKComplicationTemplateUtilitarianSmallFlat *small =
            [[CLKComplicationTemplateUtilitarianSmallFlat alloc] init];
        small.imageProvider = [self utilImageProviderForEvent:event];
        small.imageProvider.tintColor = self.tintColor;
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
        CGFloat angle = [self angleForEvent:event];
        small.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[self circularSmallDotWithAngle:angle]];
        small.imageProvider.tintColor = self.tintColor;
        template = small;
        }
        break;
    }
    return [CLKComplicationTimelineEntry entryWithDate:date complicationTemplate:template];
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
        large.headerImageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"hightide"]];
        large.body1TextProvider = [CLKSimpleTextProvider textProviderWithText:@"Level"];
        large.body2TextProvider = [CLKTimeTextProvider textProviderWithDate:[NSDate date]];
        template = large;
        }
        break;
    case CLKComplicationFamilyModularSmall:
        {
        CLKComplicationTemplateModularSmallSimpleImage *small =
            [[CLKComplicationTemplateModularSmallSimpleImage alloc] init];
        small.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[self modularSmallDotWithAngle:0]];
        small.imageProvider.tintColor = self.tintColor;
        template = small;
        }
        break;
    case CLKComplicationFamilyUtilitarianLarge:
        {
        CLKComplicationTemplateUtilitarianLargeFlat *large =
            [[CLKComplicationTemplateUtilitarianLargeFlat alloc] init];
        large.textProvider = [CLKSimpleTextProvider textProviderWithText:@"Tide Event"];
        large.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"hightide"]];
        large.imageProvider.tintColor = self.tintColor;
        template = large;
        }
        break;
    case CLKComplicationFamilyUtilitarianSmall:
        {
        CLKComplicationTemplateUtilitarianSmallFlat *small =
            [[CLKComplicationTemplateUtilitarianSmallFlat alloc] init];
        small.textProvider = [CLKSimpleTextProvider textProviderWithText:@"Tide Event" shortText:@"Tide"];
        small.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[UIImage imageNamed:@"hightide"]];
        small.imageProvider.tintColor = self.tintColor;
        template = small;
        }
        break;
    case CLKComplicationFamilyCircularSmall:
        {
        CLKComplicationTemplateCircularSmallSimpleImage *small =
            [[CLKComplicationTemplateCircularSmallSimpleImage alloc] init];
        small.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[self circularSmallDotWithAngle:0]];
        small.imageProvider.tintColor = self.tintColor;
        template = small;
        }
        break;
    }
    handler(template);
}

@end
