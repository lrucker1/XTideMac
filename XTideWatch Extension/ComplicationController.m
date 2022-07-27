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

// Show predicted complication 30 minutes before the event happens.
static NSTimeInterval EVENT_OFFSET = -30 * 60;
static NSTimeInterval HOUR = 60 * 60;
static NSTimeInterval DAY = 60 * 60 * 24;

// We use "Simple" for complications that just draw an image, "Stack" otherwise - that's the area for the stack's image. The watch handles text layout.
// Dimensions are Simple unless specified otherwise.
static CGFloat circularSmall[3] = {32, 36, 40};
//static CGFloat extraLarge[3] = {182, 203, 224};
static CGFloat extraLargeStack[3] = {84, 90, 102}; // Stack
static CGFloat modularSmall[3] = {52, 58, 64};
static CGFloat graphicCorner[3] = {-1, 40, 44};
static CGFloat graphicCircular[3] = {-1, 84, 94};
static CGFloat graphicBezel[3] = {-1, 84, 94};
//static CGFloat graphicExtraLarge[3] = {206, 240, 264};
static CGFloat graphicExtraLargeStack[3] = {206, 240, 264};
//static CGFloat graphicRectWidth[3] = {-1, 300, 342};
//static CGFloat graphicRectHeight[3] = {-1, 94, 108};

// 38mm: (0.0, 0.0, 136.0, 170.0)
// 42mm: (0.0, 0.0, 156.0, 195.0)

typedef enum XTWatchSize {
    XTWatchSize_small,
    XTWatchSize_medium,
    XTWatchSize_large
} XTWatchSize;

@interface ComplicationController ()

@property (strong) NSArray *events;
@property (nonatomic) WCSession* watchSession;
@property XTWatchSize watchSize;
@property BOOL showingPlaceholder;
@property (nonatomic) XTSessionDelegate *sessionDelegate;
@property (strong) UIColor *tintColor;
@property (strong) NSDate *lastStartTime;
@property (strong) NSDate *lastAfterDate;
@property (strong) NSDate *requestedUpdateDate;
@property (strong) NSDate *earlyReload;
@property (strong) NSDate *expirationDate;
@property (strong) NSMutableArray *replyHandlers;
@property (strong) NSString *lastStation;

@end

@implementation ComplicationController

- (instancetype)init
{
    self = [super init];
    _watchSize = [self watchSizeCheck];
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


- (XTWatchSize)watchSizeCheck
{
    // The asset json file checks whether the width is <=145
// 38mm: (0.0, 0.0, 136.0, 170.0)
// 42mm: (0.0, 0.0, 156.0, 195.0)
// 44mm: ((x = 0, y = 0), size = (width = 184, height = 224))
    CGRect rect = [WKInterfaceDevice currentDevice].screenBounds;
    if (rect.size.width <= 145) {
        return XTWatchSize_small;
    }
    if (rect.size.width <= 156) {
        return XTWatchSize_medium;
    }
    return XTWatchSize_large;
}

- (void)reachabilityChanged:(NSNotification *)note
{
    if ([WCSession defaultSession].reachable && [self needsReload]) {
        [self requestComplicationsWithReplyHandler:nil];
    }
}

- (void)didReceiveUserInfo:(NSNotification *)note
{
    [self updateEvents:[note userInfo] forCallback:NO];
    [self scheduleNextComplicationBackgroundRefreshTask];
}

- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error
{
    if (activationState == WCSessionActivationStateActivated) {
        if ([self needsReload]) {
            [self requestComplicationsWithReplyHandler:nil];
        }
    }
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
- (NSDate *)lastEventTime
{
    // Add the same offset for all families.
    NSDictionary *event = [self.events lastObject];
    NSDate *date = [event objectForKey:@"date"];
    return [date dateByAddingTimeInterval:-EVENT_OFFSET];
}

// The last date for which we can supply data.
- (void)getTimelineEndDateForComplication:(CLKComplication *)complication withHandler:(void(^)(NSDate * __nullable date))handler
{
    // There are twice as many ring events, which sometimes pushes them over the limit.
    // With a max of 100 for 2 days, we should never run out of text events.
    if (self.expirationDate && [self isRingFamily:complication.family]) {
        handler([self.expirationDate dateByAddingTimeInterval:-EVENT_OFFSET]);
        return;
    }
        
    [self requestComplicationsWithReplyHandler:^(BOOL isReady) {
        if (isReady) {
            NSDate *date = self.expirationDate;
            if (date) {
                date = [date dateByAddingTimeInterval:-EVENT_OFFSET];
            } else {
                date = [self lastEventTime];
            }
            handler(date);
        } else {
            // Give it a date in the future to let it know that we can do that.
            handler([NSDate dateWithTimeIntervalSinceNow:DAY]);
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
        return;
    }
    BOOL stationChange = self.lastStation != nil && ![station isEqualToString:self.lastStation];
    // This is a station change. Dump everything if we had a previous station.
    if (stationChange) {
        self.events = nil;
        self.requestedUpdateDate = nil;
        self.lastAfterDate = nil;
        self.lastStartTime = nil;
        self.earlyReload = nil;
    }
    self.lastStation = station;
    if (![self processEvents:reply]) {
        return;
    }

    if (stationChange || !forCallback || self.showingPlaceholder) {
        self.showingPlaceholder = NO;
        self.earlyReload = nil;
        CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
        for (CLKComplication *complication in server.activeComplications) {
            [server reloadTimelineForComplication:complication];
        }
    } else {
        CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
        for (CLKComplication *complication in server.activeComplications) {
            [server extendTimelineForComplication:complication];
        }
    }
}

- (NSMutableArray *)validateEvents:(NSArray *)inEvents
{
    NSDate *earlyDate = [NSDate date];
    NSMutableArray *events = [NSMutableArray array];
    // Add events that are still valid.
    for (NSDictionary *oldEvent in inEvents) {
        if ([[oldEvent objectForKey:@"date"] compare:earlyDate] == NSOrderedDescending) {
            [events addObject:oldEvent];
        }
    }
    return events;
}


// Update the event array. Return YES if the events have changed.
- (BOOL)processEvents:(NSDictionary *)reply
{
    NSArray *newEvents = reply[@"events"];
    NSDate *startDate = reply[@"startDate"];
    if (![self.events count]) {
        self.events = [NSArray arrayWithArray:[self validateEvents:newEvents]];
        self.lastStartTime = startDate;
        self.lastAfterDate = reply[@"endDate"] ?: [NSDate date];
        return YES;
    }

    if ([startDate isEqualToDate:self.lastStartTime]) {
        // Same events; make sure they're still valid.
        NSInteger oldCount = [self.events count];
        self.events = [NSArray arrayWithArray:[self validateEvents:newEvents]];
        return oldCount != [self.events count];
    }

    // Either the date or the station have changed.
    NSMutableArray *events = [self validateEvents:self.events];
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
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    self.events = [events sortedArrayUsingDescriptors:@[descriptor]];
    self.lastStartTime = startDate;
//    [self scheduleNextComplicationBackgroundRefreshTask];
    return YES;
}

- (NSDictionary *)eventRequestDictionary
{
    NSDate *date = [NSDate date];
    return @{@"kind"  : @"requestEvents",
             @"first" : [date dateByAddingTimeInterval:-2 * HOUR],
             @"last"  : [date dateByAddingTimeInterval:3 * DAY]};
}

// Do we need to talk to the iPhone?
// Yes if the data is missing or out of date.
- (BOOL)needsReload
{
    if ([self.events count] == 0 || self.lastStartTime == nil || self.showingPlaceholder) {
        return YES;
    }
//    NSDate *date = self.lastAfterDate ? self.lastAfterDate : [NSDate date];
//    return [self.lastStartTime compare:date] == NSOrderedAscending;
    return YES;
}

- (void)callReplyHandlers
{
    @synchronized (self) {
        BOOL isReady = self.events != nil;
        for (id handler in self.replyHandlers) {
           ((void (^)(BOOL))handler)(isReady);
        }
        self.replyHandlers = nil;
    }
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
        if (replyHandler) {
            replyHandler([self.events count] != 0);
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
        [self callReplyHandlers];
    };

    [self.watchSession sendMessage:[self eventRequestDictionary]
                      replyHandler:defaultHandler
                      errorHandler:
        ^(NSError *error) {
            // The timeout "error" is a known bug.
            if (!([error.domain isEqualToString:@"WCErrorDomain"] && error.code == 7012)) {
                NSLog(@"requestComplicationsWithReplyHandler %@", error);
                // Call the handlers. We get extra data so there might be something they can use.
                [self callReplyHandlers];
            }
        }];
}

- (BOOL)isRingFamily:(CLKComplicationFamily)family
{
    switch (family) {
        case CLKComplicationFamilyModularSmall:
        case CLKComplicationFamilyCircularSmall:
        case CLKComplicationFamilyExtraLarge:
        case CLKComplicationFamilyGraphicCorner:
        case CLKComplicationFamilyGraphicBezel:
        case CLKComplicationFamilyGraphicCircular:
        case CLKComplicationFamilyGraphicExtraLarge:
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
    NSDictionary *lastEvent = [events lastObject];
    // Make sure it's still valid. Give it half an hour for normal events, 15 minutes for rings.
    NSTimeInterval endOffset = [self isRingFamily:complication.family] ? HOUR / 4 : HOUR / 2;
    NSDate *lastDateEnd = [[lastEvent objectForKey:@"date"] dateByAddingTimeInterval:endOffset];
    // if lastEvent.date < now, we need new events.
    if ([lastDateEnd compare:date] == NSOrderedAscending) {
        return nil;
    }
    NSDictionary *lastTestedEvent = [self.events firstObject];
    for (NSDictionary *event in events) {
        NSDate *testDate = [event objectForKey:@"date"];
        // if event.date > now, return the one just before it.
        if ([testDate compare:date] == NSOrderedDescending) {
            return lastTestedEvent;
        }
        lastTestedEvent = event;
    }
    return lastTestedEvent;
}

- (CLKComplicationTimelineEntry *)getCurrentTimelineEntryForComplication:(CLKComplication *)complication
{
    if (![self.events count]) {
        return nil;
    }
    NSDictionary *event = [self currentEventForComplication:complication];
    if (event) {
        return [self getEntryforComplication:complication withEvent:event];
    }
    return nil;
}

//- (NSArray *)getTimelineEntriesForComplication:(CLKComplication *)complication
//                                    beforeDate:(NSDate *)date
//                                         limit:(NSUInteger)limit
//{
//    NSMutableArray *array = [NSMutableArray array];
//    NSUInteger count = 0;
//    CLKComplicationFamily family = complication.family;
//    NSArray *events = [self eventsForFamily:complication.family];
//    for (NSDictionary *event in [events reverseObjectEnumerator]) {
//        NSDate *testDate = [self timeForEvent:event family:family];
//        if ([testDate compare:date] == NSOrderedAscending) {
//            [array insertObject:[self getEntryforComplication:complication withEvent:event] atIndex:0];
//            count++;
//            if (count == limit) {
//                break;
//            }
//        }
//    }
//    return array;
//}

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
                // Reload in a few hours when there will be space.
                NSDate *reload = [[NSDate date] dateByAddingTimeInterval:HOUR * 6];
                self.earlyReload = self.earlyReload ? [self.earlyReload earlierDate:reload] : reload;
                self.expirationDate = self.expirationDate ? [self.expirationDate earlierDate:testDate] : testDate;
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
        CLKComplicationTimelineEntry *entry = [self getCurrentTimelineEntryForComplication:complication];
        if (entry) {
            handler(entry);
        } else {
            // Icon-style complications use the asset image, but the text one needs text.
            handler([self getEntryforComplication:complication withEvent:nil]);
            self.showingPlaceholder = YES;
        }
    }];
}

- (void)getTimelineEntriesForComplication:(CLKComplication *)complication
                                afterDate:(NSDate *)date
                                    limit:(NSUInteger)limit
                              withHandler:(void(^)(NSArray<CLKComplicationTimelineEntry *> * __nullable entries))handler
{
    self.lastAfterDate = self.lastAfterDate ? [self.lastAfterDate laterDate:date] : date;
    // Call the handler with the timeline entries after the given date
    // First, see if we already have enough data. We like having extra.
    NSArray *array = [self getTimelineEntriesForComplication:complication afterDate:date limit:limit];
    if ([array count] == limit) {
        handler(array);
        return;
    }
    // OK, have to ask for more.
    [self requestComplicationsWithReplyHandler:^(BOOL isReady) {
        if (isReady) {
            handler ([self getTimelineEntriesForComplication:complication afterDate:date limit:limit]);
        } else {
            
            handler(nil);
        }
    }];
}

#pragma mark Update Scheduling

- (void)scheduleNextComplicationBackgroundRefreshTask {

    NSDictionary *backgroundRefreshUserInfo = @{@"reason": @"Background Complication Refresh"};
    // The server start/end dates are bound by local midnights so reload when they move.
    // If any complications didn't get enough entries, reload after a few hours so there's
    // a smaller time period to fill.
    if (    self.requestedUpdateDate == nil
        || [[NSDate date] compare:self.requestedUpdateDate] == NSOrderedDescending) {
        self.requestedUpdateDate = [[NSCalendar currentCalendar] startOfDayForDate:[NSDate date]];
    }

    //scheduling the refresh
    [[WKExtension sharedExtension] scheduleBackgroundRefreshWithPreferredDate:self.requestedUpdateDate userInfo:backgroundRefreshUserInfo scheduledCompletion:^(NSError *error){

        if (error == nil) {
            [self handleRequestedUpdate];
        } else {
            NSLog(@"unable to schedule background refresh task, error:%@", error);
        }
    }];
}

//- (void)getNextRequestedUpdateDateWithHandler:(void(^)(NSDate * __nullable updateDate))handler
//{
//    // The server start/end dates are bound by local midnights so reload when they move.
//    // If any complications didn't get enough entries, reload after a few hours so there's
//    // a smaller time period to fill.
//    if (    self.requestedUpdateDate == nil
//        || [[NSDate date] compare:self.requestedUpdateDate] == NSOrderedDescending) {
//        NSDate *tomorrow = [NSDate dateWithTimeIntervalSinceNow:DAY];
//        self.requestedUpdateDate = [[NSCalendar currentCalendar] startOfDayForDate:tomorrow];
//    }
//    NSDate *update = self.requestedUpdateDate;
//    if (self.earlyReload) {
//        update = [self.earlyReload earlierDate:self.requestedUpdateDate];
//    }
//    handler(update);
//}

- (void)handleRequestedUpdate
{
    self.requestedUpdateDate = nil;
    self.earlyReload = nil;
    self.expirationDate = nil;
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
    for (CLKComplication *complication in server.activeComplications) {
        [server extendTimelineForComplication:complication];
    }
}

- (void)handleBackgroundTasks:(NSSet <WKRefreshBackgroundTask *> *)backgroundTasks {
    for (WKRefreshBackgroundTask *task in backgroundTasks) {
        [self handleRequestedUpdate];
        [task setTaskCompletedWithSnapshot:NO];
    }
}

#pragma mark - Entry generator

- (CGFloat)angleForEvent:(NSDictionary *)event
{
    NSNumber *number = [event objectForKey:@"angle"];
    return number ? [number floatValue] : -1;
}

- (CLKSimpleTextProvider *)noEventTextProvider
{
    NSString *waiting = NSLocalizedString(@"No tide station", @"No tide station");
    NSString *waitingShort = NSLocalizedString(@"No station", @"No station");
    return [CLKSimpleTextProvider textProviderWithText:waiting shortText:waitingShort];
}

- (CLKSimpleTextProvider *)shortLevelTextProviderForEvent:(NSDictionary * _Nullable)event
{
    if (!event) {
        return [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Level", @"Level placeholder")];
    }
    NSString *levelShort = [event objectForKey:@"levelShort"];
    NSAssert(levelShort, @"has a levelShort");
    return [CLKSimpleTextProvider textProviderWithText:levelShort];
}

- (CLKSimpleTextProvider *)levelTextProviderForEvent:(NSDictionary * _Nullable)event
{
    if (!event) {
        return [CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Level", @"Level placeholder")];
    }
    NSString *level = [event objectForKey:@"level"];
    NSString *levelShort = [event objectForKey:@"levelShort"];
    NSAssert(level, @"has a level");
    NSAssert(levelShort, @"has a levelShort");
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
    NSAssert(desc, @"has a desc");
    if (descShort) {
        return [CLKSimpleTextProvider textProviderWithText:desc shortText:descShort];
    }
    return [CLKSimpleTextProvider textProviderWithText:desc];
}

- (UIImage *)utilImageForEvent:(NSDictionary * _Nullable)event {
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
    return image;
}

- (CLKImageProvider *)utilImageProviderForEvent:(NSDictionary * _Nullable)event
{
    // Only interpolated events have a "isRising" entry. Look in "type" for the icon name.
    UIImage *image = [self utilImageForEvent:event];
    if (image) {
        CLKImageProvider *imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:image];
        imageProvider.tintColor = self.tintColor;
        imageProvider.accessibilityLabel = [self imageAccessibilityLabelForEvent:event];
        return imageProvider;
    }
    NSLog(@"no image for event %@", event);
    return nil;
}


- (CLKFullColorImageProvider *)utilFullColorImageProviderForEvent:(NSDictionary * _Nullable)event
API_AVAILABLE(watchos(5.0)) {
    // Only interpolated events have a "isRising" entry. Look in "type" for the icon name.
    UIImage *image = [self utilImageForEvent:event];
    if (image) {
        CLKFullColorImageProvider *imageProvider = [CLKFullColorImageProvider providerWithFullColorImage:image];
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
    CGFloat rectSize = -1;
    CGFloat lineWidth = 4;
    if (family == CLKComplicationFamilyModularSmall) {
        rectSize = modularSmall[self.watchSize];
    } else if (family == CLKComplicationFamilyCircularSmall) {
        rectSize = circularSmall[self.watchSize];
        lineWidth = 2;
    } else if (family == CLKComplicationFamilyExtraLarge) {
        rectSize = extraLargeStack[self.watchSize];
        lineWidth = 6;
    } else {
        if (@available(watchOS 5.0, *)) {
            if (family == CLKComplicationFamilyGraphicCorner) {
                rectSize = graphicCorner[self.watchSize];
            } else if (family == CLKComplicationFamilyGraphicCircular) {
                rectSize = graphicCircular[self.watchSize];
            } else if (family == CLKComplicationFamilyGraphicBezel) {
                rectSize = graphicBezel[self.watchSize];
            }
        }
    }
    // else
    if (rectSize < 0) {
        if (@available(watchOS 7.0, *)) {
            if (family == CLKComplicationFamilyGraphicExtraLarge) {
                rectSize = graphicExtraLargeStack[self.watchSize];
                lineWidth = 6;
            }
        }
    }
    if (rectSize < 0) {
        // Not set or not supported.
        return nil;
    }
    CGFloat angle = [self angleForEvent:event]; // -1 for placeholders with nil events.
    UIImage *ring = [self ringWithRectSize:rectSize lineWidth:lineWidth];
    UIImage *hand = [self handWithRectSize:rectSize lineWidth:lineWidth angle:angle includeRing:NO];
    UIImage *bgImage = [self handWithRectSize:rectSize lineWidth:lineWidth angle:angle includeRing:YES];
    CLKImageProvider *imageProvider = [CLKImageProvider imageProviderWithOnePieceImage:bgImage twoPieceImageBackground:ring twoPieceImageForeground:hand];
    imageProvider.tintColor = self.tintColor;
    imageProvider.accessibilityLabel = [self imageAccessibilityLabelForEvent:event];
    return imageProvider;
}

- (CLKFullColorImageProvider *)ringFullColorImageProviderForEvent:(NSDictionary * _Nullable)event
                                                           family:(CLKComplicationFamily)family

API_AVAILABLE(watchos(5.0))
{
    if (@available(watchOS 5.0, *)) {
        CGFloat rectSize = -1;
        CGFloat lineWidth = 2;
        CGFloat inset = lineWidth + 4;
        if (family == CLKComplicationFamilyGraphicCorner) {
            rectSize = graphicCorner[self.watchSize];
        } else if (family == CLKComplicationFamilyGraphicCircular) {
            rectSize = graphicCircular[self.watchSize];
        } else if (family == CLKComplicationFamilyGraphicBezel) {
            rectSize = graphicBezel[self.watchSize];
        } else if (@available(watchOS 7.0, *)) {
            if (family == CLKComplicationFamilyGraphicExtraLarge) {
                rectSize = graphicExtraLargeStack[self.watchSize];
                lineWidth = 6;
                inset = 10;
            }
        }
        if (rectSize < 0) {
            // Not set or not supported.
            return nil;
        }
        CGFloat angle = [self angleForEvent:event]; // -1 for placeholders with nil events.
        UIImage *colorImage = [self handWithRectSize:rectSize lineWidth:lineWidth angle:angle includeRing:YES inset:inset color:[UIColor redColor] ringColor:[UIColor redColor]];
        CLKFullColorImageProvider *imageProvider = nil;
        if (@available(watchOS 6.0, *)) {
            imageProvider = [CLKFullColorImageProvider providerWithFullColorImage:colorImage tintedImageProvider:[self ringImageProviderForEvent:event family:family]];
        } else {
            imageProvider = [CLKFullColorImageProvider providerWithFullColorImage:colorImage];
        }
        imageProvider.accessibilityLabel = [self imageAccessibilityLabelForEvent:event];
        return imageProvider;
    } else {
        return nil;
    }
}


- (UIImage *)utilitarianIsRising:(BOOL)isRising
{
    return [UIImage imageNamed:isRising ? @"upArrowImage" : @"downArrowImage"];
}

- (void)drawRingInContext:(CGContextRef)context
             withRectSize:(CGFloat)rectSize
                lineWidth:(CGFloat)lineWidth
                    color:(UIColor *)color
{
}

- (UIImage *)ringWithRectSize:(CGFloat)rectSize
                    lineWidth:(CGFloat)lineWidth
                        color:(UIColor *)color
{
    CGRect rect = CGRectMake(0, 0, rectSize, rectSize);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetStrokeColorWithColor(context, [color CGColor]);
    CGContextSetLineWidth(context, lineWidth);

    CGRect edgeRect = CGRectInset(rect, lineWidth, lineWidth);
    CGContextStrokeEllipseInRect(context, edgeRect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (UIImage *)ringWithRectSize:(CGFloat)rectSize
                    lineWidth:(CGFloat)lineWidth
{
    return [self ringWithRectSize:rectSize lineWidth:lineWidth color:[UIColor blackColor]];
}

- (UIImage *)handWithRectSize:(CGFloat)rectSize
                    lineWidth:(CGFloat)lineWidth
                        angle:(CGFloat)radians  // -1 for placeholder with no angle data
                  includeRing:(BOOL)includeRing
                        inset:(CGFloat)inset
                        color:(UIColor *)color
                    ringColor:(UIColor *)ringColor
{
    CGRect outerRect = CGRectMake(0, 0, rectSize, rectSize);
    CGRect rect = CGRectInset(outerRect, inset, inset);
    CGFloat adjustedInset = lineWidth + inset;  

    CGFloat dotInset = (rectSize - lineWidth * 2) / 2;
    UIGraphicsBeginImageContext(outerRect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    // Debugging
    if (inset > 0) {
//        CGContextSetFillColorWithColor(context, [(includeRing ? [UIColor lightGrayColor] : [UIColor magentaColor]) CGColor]);
        CGContextSetFillColorWithColor(context, [self.tintColor CGColor]);
        CGContextFillRect(context, rect);
    }

    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextSetStrokeColorWithColor(context, [color CGColor]);
    CGFloat radius = rectSize / 2;
    CGPoint center = CGPointMake(radius, radius);
    CGContextSetLineWidth(context, lineWidth);

    CGRect dotRect = CGRectInset(outerRect, dotInset, dotInset);
    CGContextFillEllipseInRect(context, dotRect);

    if (radians >= 0) {
        UIBezierPath *arm = [UIBezierPath bezierPath];
        [arm moveToPoint:CGPointZero];
        [arm addLineToPoint:CGPointMake(0, -(radius - (adjustedInset * 2.5)))];
        arm.lineWidth = lineWidth;
        arm.lineCapStyle = kCGLineCapRound;
        CGAffineTransform position = CGAffineTransformMakeTranslation(center.x, center.y);
        position = CGAffineTransformRotate(position, radians);
        [arm applyTransform:position];
        [arm stroke];
    }

    if (includeRing) {
        CGContextSetFillColorWithColor(context, [ringColor CGColor]);
        CGContextSetStrokeColorWithColor(context, [ringColor CGColor]);
        CGContextSetLineWidth(context, adjustedInset);
        CGRect edgeRect = CGRectInset(rect, adjustedInset, adjustedInset);
        CGContextStrokeEllipseInRect(context, edgeRect);
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (UIImage *)handWithRectSize:(CGFloat)rectSize
                    lineWidth:(CGFloat)lineWidth
                        angle:(CGFloat)radians  // -1 for placeholder with no angle data
                  includeRing:(BOOL)includeRing
{
    return [self handWithRectSize:rectSize lineWidth:lineWidth angle:radians includeRing:includeRing inset:0 color:[UIColor blackColor] ringColor:[UIColor blackColor]];
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
    case CLKComplicationFamilyExtraLarge:
        {
        CLKComplicationTemplateExtraLargeStackImage *large =
            [[CLKComplicationTemplateExtraLargeStackImage alloc] init];
        large.line1ImageProvider = [self ringImageProviderForEvent:event family:complication.family];
        large.line2TextProvider = [self shortLevelTextProviderForEvent:event];
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
    case CLKComplicationFamilyUtilitarianSmallFlat:
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
    case CLKComplicationFamilyGraphicCorner:
        if (@available(watchOS 5.0, *)) {
            CLKComplicationTemplateGraphicCornerTextImage *graphic =
                [[CLKComplicationTemplateGraphicCornerTextImage alloc] init];
            graphic.imageProvider = [self ringFullColorImageProviderForEvent:event family:complication.family];
            graphic.textProvider = [self levelTextProviderForEvent:event];
            template = graphic;
        }
        break;
    case CLKComplicationFamilyGraphicBezel:
        if (@available(watchOS 5.0, *)) {
            CLKComplicationTemplateGraphicCircularImage *circularTemplate =
                [[CLKComplicationTemplateGraphicCircularImage alloc] init];
            circularTemplate.imageProvider = [self ringFullColorImageProviderForEvent:event family:complication.family];
            CLKComplicationTemplateGraphicBezelCircularText *graphic =
                [[CLKComplicationTemplateGraphicBezelCircularText alloc] init];
            graphic.circularTemplate = circularTemplate;
            graphic.textProvider = [self levelTextProviderForEvent:event];
            template = graphic;
        }
        break;
    case CLKComplicationFamilyGraphicCircular:
        if (@available(watchOS 5.0, *)) {
            CLKComplicationTemplateGraphicCircularImage *graphic =
                [[CLKComplicationTemplateGraphicCircularImage alloc] init];
            graphic.imageProvider = [self ringFullColorImageProviderForEvent:event family:complication.family];
            template = graphic;
        }
        break;
    case CLKComplicationFamilyGraphicRectangular:
        if (@available(watchOS 5.0, *)) {
            CLKComplicationTemplateGraphicRectangularStandardBody *large =
                [[CLKComplicationTemplateGraphicRectangularStandardBody alloc] init];
            large.headerImageProvider = [self utilFullColorImageProviderForEvent:event];
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
    case CLKComplicationFamilyGraphicExtraLarge:
//TODO
        break;
    }
    // Letting the OS do that means it happens after we've alreadyma
//    [template performSelector:@selector(validate) withObject:nil];

    return [CLKComplicationTimelineEntry entryWithDate:[self timeForEvent:event family:complication.family]
                                  complicationTemplate:template];
}

#pragma mark - Placeholder Templates

- (void)getLocalizableSampleTemplateForComplication:(CLKComplication *)complication
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
    case CLKComplicationFamilyExtraLarge:
        {
        CLKComplicationTemplateExtraLargeStackImage *large =
            [[CLKComplicationTemplateExtraLargeStackImage alloc] init];
        large.line1ImageProvider = [self ringImageProviderForEvent:nil family:complication.family];
        large.line2TextProvider = [self shortLevelTextProviderForEvent:nil];
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
    case CLKComplicationFamilyUtilitarianSmallFlat:
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
    case CLKComplicationFamilyGraphicCorner:
        if (@available(watchOS 5.0, *)) {
            CLKComplicationTemplateGraphicCornerTextImage *graphic =
            [[CLKComplicationTemplateGraphicCornerTextImage alloc] init];
            graphic.imageProvider = [self ringFullColorImageProviderForEvent:nil family:complication.family];
            graphic.textProvider = [self levelTextProviderForEvent:nil];
            template = graphic;
        }
        break;
    case CLKComplicationFamilyGraphicBezel:
        if (@available(watchOS 5.0, *)) {
            CLKComplicationTemplateGraphicCircularImage *circularTemplate =
                [[CLKComplicationTemplateGraphicCircularImage alloc] init];
            circularTemplate.imageProvider = [self ringFullColorImageProviderForEvent:nil family:complication.family];
            CLKComplicationTemplateGraphicBezelCircularText *graphic =
                [[CLKComplicationTemplateGraphicBezelCircularText alloc] init];
            graphic.circularTemplate = circularTemplate;
            graphic.textProvider = [self levelTextProviderForEvent:nil];
            template = graphic;
        }
        break;
    case CLKComplicationFamilyGraphicCircular:
        if (@available(watchOS 5.0, *)) {
            CLKComplicationTemplateGraphicCircularImage *graphic =
                [[CLKComplicationTemplateGraphicCircularImage alloc] init];
            graphic.imageProvider = [self ringFullColorImageProviderForEvent:nil family:complication.family];
            template = graphic;
        }
        break;
    case CLKComplicationFamilyGraphicRectangular:
        if (@available(watchOS 5.0, *)) {
            CLKComplicationTemplateGraphicRectangularStandardBody *large =
                [[CLKComplicationTemplateGraphicRectangularStandardBody alloc] init];
            large.headerTextProvider = [self descTextProviderForEvent:nil];
            large.headerImageProvider = [self utilFullColorImageProviderForEvent:nil];
            large.body1TextProvider = [self levelTextProviderForEvent:nil];
            large.body2TextProvider = [self dateProviderForEvent:nil];
            template = large;
        }
        break;
    case CLKComplicationFamilyGraphicExtraLarge:
//TODO
        break;
    }
    handler(template);
}

@end
