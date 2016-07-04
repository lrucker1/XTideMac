//
//  ComplicationController.m
//  XTideWatch Extension
//
//  Created by Lee Ann Rucker on 7/2/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "ComplicationController.h"

@import WatchConnectivity;

static NSTimeInterval HOUR = 60 * 60;
//static NSTimeInterval MINUTE = 60;
static NSTimeInterval DAY = 60 * 60 * 24;

@interface ComplicationController ()

@property (strong) NSArray *events;
@property (nonatomic) WCSession* watchSession;

@end

@implementation ComplicationController


- (UIImage *)modularSmallDot
{
    CGRect rect = CGRectMake(0, 0, 32, 32);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, [[UIColor blackColor] CGColor]);
    CGContextSetStrokeColorWithColor(context, [[UIColor blackColor] CGColor]);

    CGRect dotRect = CGRectInset(rect, 14, 14);
    CGContextFillEllipseInRect(context, dotRect);

    CGRect edgeRect = CGRectInset(rect, 2, 2);
    CGContextSetLineWidth(context, 2);
    CGContextStrokeEllipseInRect(context, edgeRect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}


- (UIImage *)modularSmallDotWithAngle:(CGFloat)radians
{
    CGRect rect = CGRectMake(0, 0, 32, 32);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, [[UIColor blackColor] CGColor]);
    CGContextSetStrokeColorWithColor(context, [[UIColor blackColor] CGColor]);
    CGFloat radius = rect.size.width / 2;
    CGPoint center = CGPointMake(radius, radius);
    CGContextSetLineWidth(context, 2);

    CGRect dotRect = CGRectInset(rect, 14, 14);
    CGContextFillEllipseInRect(context, dotRect);

    // TODO: Yes, this is inefficient, and having a line with end caps would be prettier.
    // Debugging it is a pain.
    UIBezierPath *arm = [UIBezierPath bezierPathWithRect:CGRectMake(-1, 0, 2, radius - 6)];
    CGAffineTransform position = CGAffineTransformMakeTranslation(center.x, center.y);
    position = CGAffineTransformRotate(position, M_PI + radians);
    [arm applyTransform:position];
    [arm fill];

    CGRect edgeRect = CGRectInset(rect, 2, 2);
    CGContextStrokeEllipseInRect(context, edgeRect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}


- (void)requestComplicationsWithReplyHandler:(void (^)(NSDictionary<NSString *,id> *replyMessage))replyHandler
{
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
    if (!self.watchSession) {
        self.watchSession = [WCSession defaultSession];
        self.watchSession.delegate = self;
        [self.watchSession activateSession];
    }

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
            self.events = [reply objectForKey:@"events"];
            NSLog(@"%@", self.events);
            }];
    }
}


- (void)sessionReachabilityDidChange:(WCSession *)session
{
    if (session.reachable) {
        [self loadEvents];
    }
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
    handler([NSDate dateWithTimeIntervalSinceNow:DAY]);
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
            self.events = [reply objectForKey:@"events"];
            handler ([self getCurrentTimelineEntryForComplication:complication]);
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
            self.events = [reply objectForKey:@"events"];
            handler ([self getTimelineEntriesForComplication:complication beforeDate:date limit:limit]);
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
            self.events = [reply objectForKey:@"events"];
            handler ([self getTimelineEntriesForComplication:complication afterDate:date limit:limit]);
        }];
        return;
    }
    handler ([self getTimelineEntriesForComplication:complication afterDate:date limit:limit]);
}

#pragma mark Update Scheduling

- (void)getNextRequestedUpdateDateWithHandler:(void(^)(NSDate * __nullable updateDate))handler
{
    // Call the handler with the date when you would next like to be given the opportunity to update your complication content
    // Every 12 hours should be enough to pick up new events.
    handler ([NSDate dateWithTimeIntervalSinceNow:HOUR * 12]);
}

- (void)requestedUpdateDidBegin
{
    self.events = nil;
    [self requestComplicationsWithReplyHandler:^(NSDictionary *reply) {
        self.events = [reply objectForKey:@"events"];
        CLKComplicationServer *server = [CLKComplicationServer sharedInstance];

        for (CLKComplication *complication in server.activeComplications) {
            [server extendTimelineForComplication:complication];
        }
    }];
}

#pragma mark - Placeholder Templates

- (CLKComplicationTimelineEntry *)getEntryforComplication: (CLKComplication *)complication
                                                withEvent: (NSDictionary *)event
{
    CLKComplicationTemplate *template = nil;
    NSDate *date = [event objectForKey:@"date"];
    switch (complication.family) {
    case CLKComplicationFamilyModularLarge:
        {
        CLKComplicationTemplateModularLargeStandardBody *large =
            [[CLKComplicationTemplateModularLargeStandardBody alloc] init];
        large.headerTextProvider = [CLKTimeTextProvider textProviderWithDate:date];
        large.body1TextProvider = [CLKSimpleTextProvider textProviderWithText:[event objectForKey:@"desc"]];
        large.body2TextProvider = [CLKSimpleTextProvider textProviderWithText:[event objectForKey:@"level"]];
        template = large;
        }
        break;
    case CLKComplicationFamilyModularSmall:
        {
        CLKComplicationTemplateModularSmallSimpleImage *small =
            [[CLKComplicationTemplateModularSmallSimpleImage alloc] init];
        NSNumber *angleObj = [event objectForKey:@"angle"];
        CGFloat angle = 0;
        if (angleObj) {
            angle = [angleObj floatValue];
        } else {
            NSString *type = [event objectForKey:@"type"];
            if ([type isEqualToString:@"lowtide"]) {
                angle = M_PI;
            }
        }
        small.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[self modularSmallDotWithAngle:angle]];
        template = small;
        }
        break;
    case CLKComplicationFamilyUtilitarianLarge:
    case CLKComplicationFamilyUtilitarianSmall:
    case CLKComplicationFamilyCircularSmall:
        break;
    }
    return [CLKComplicationTimelineEntry entryWithDate:date complicationTemplate:template];
}


- (void)getPlaceholderTemplateForComplication:(CLKComplication *)complication
                                  withHandler:(void(^)(CLKComplicationTemplate * __nullable complicationTemplate))handler
{
    self.watchSession = [WCSession defaultSession];
    self.watchSession.delegate = self;
    [self.watchSession activateSession];
    if (self.watchSession.reachable) {
        [self loadEvents];
    }

    // This method will be called once per supported complication, and the results will be cached
    CLKComplicationTemplate *template = nil;
    switch (complication.family) {
    case CLKComplicationFamilyModularLarge:
        {
        CLKComplicationTemplateModularLargeStandardBody *large =
            [[CLKComplicationTemplateModularLargeStandardBody alloc] init];
        large.headerTextProvider = [CLKTimeTextProvider textProviderWithDate:[NSDate date]];
        large.body1TextProvider = [CLKSimpleTextProvider textProviderWithText:@"Tide Event"];
        large.body2TextProvider = [CLKSimpleTextProvider textProviderWithText:@"Level"];
        template = large;
        }
        break;
    case CLKComplicationFamilyModularSmall:
        {
        CLKComplicationTemplateModularSmallSimpleImage *small =
            [[CLKComplicationTemplateModularSmallSimpleImage alloc] init];
        small.imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:[self modularSmallDot]];
        template = small;
        }
        break;
    case CLKComplicationFamilyUtilitarianLarge:
    case CLKComplicationFamilyUtilitarianSmall:
    case CLKComplicationFamilyCircularSmall:
        break;
    }
    handler(template);
}

@end
