//
//  ComplicationController.m
//  WatchTide WatchKit Extension
//
//  Created by Lee Ann Rucker on 8/4/22.
//

@import WatchKit;
#import "ComplicationController.h"
#import "XTSessionDelegate.h"

// Show predicted complication 30 minutes before the event happens.
static NSTimeInterval EVENT_OFFSET = -30 * 60;
static NSTimeInterval HOUR = 60 * 60;
//static NSTimeInterval DAY = 60 * 60 * 24;

// These are the px dimensions, double the pt. Note that the full-color dial draws in scale=2 and needs pt. TODO: update everything to draw in scale=2.
// http://www.glimsoft.com/02/18/watchos-complications/ for numbers in a nice chart.
static CGFloat circularSmall[5] = {32, 36, 38, 40, 43};
//static CGFloat extraLarge[5] = {182, 203, 215, 224, 242};
static CGFloat extraLargeStack[5] = {84, 90, 95, 102, 107}; // Stack
static CGFloat modularSmall[5] = {52, 58, 61, 64, 69};
static CGFloat graphicCorner[5] = {-1, 40, 42, 44, 48};
static CGFloat graphicCircular[5] = {-1, 84, 89, 94, 100};
static CGFloat graphicBezel[5] = {-1, 84, 89, 94, 100};
static CGFloat graphicExtraLarge[5] = {-1, 120, 127, 132, 143};
//static CGFloat graphicRectWidth[3] = {-1, 300, 318, 342. 357};
//static CGFloat graphicRectHeight[3] = {-1, 94, 100, 108, 112};

typedef enum XTWatchSize {
    XTWatchSize_38mm,
    XTWatchSize_40mm,
    XTWatchSize_41mm,
    XTWatchSize_44mm,
    XTWatchSize_45mm
} XTWatchSize;

typedef enum XTColorDialMode {
    dial_normal,
    dial_onepiece,
    dial_background,
    dial_foreground
} XTColorDialMode;

@interface ComplicationController ()

@property (strong) NSArray *events;
@property XTWatchSize watchSize;
@property (nonatomic) XTSessionDelegate *sessionDelegate;
@property (strong) UIColor *tintColor;
@property (strong) NSDate *lastStartTime;
@property (strong) NSDate *lastAfterDate;
@property (strong) NSDate *expirationDate;
@property (strong) NSString *lastStation;

@end

@implementation ComplicationController

- (instancetype)init
{
    self = [super init];
    _watchSize = [self watchSizeCheck];
    // 02B0CB, dot 0268CB
    _tintColor = [UIColor colorWithRed:0x02/255.0 green:0xB0/255.0 blue:0xCB/255.0 alpha:1.0];

    _sessionDelegate = [XTSessionDelegate sharedDelegate];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveUserInfo:)
                                                 name:XTSessionUserInfoNotification
                                               object:nil];
    return self;
}

- (void)didReceiveUserInfo:(NSNotification *)note
{
    // Station change; dump everything.
    CLKComplicationServer *server = [CLKComplicationServer sharedInstance];
    for (CLKComplication *comp in [server activeComplications]) {
        [server reloadTimelineForComplication:comp];
    }
}

- (XTWatchSize)watchSizeCheck
{
    CGFloat screenHeight = [WKInterfaceDevice currentDevice].screenBounds.size.height;
    if (screenHeight >= 242) {
        return XTWatchSize_45mm;
    }
    else if (screenHeight >= 224) {
        return XTWatchSize_44mm;
    }
    else if (screenHeight >= 215) {
        return XTWatchSize_41mm;
    }
    else if (screenHeight >= 197) {
        return XTWatchSize_40mm;
    }
    else if (screenHeight >= 170) {
        return XTWatchSize_38mm;
    }
    return XTWatchSize_40mm; // Because 40mm is the one drawn at 100%, if the watch ends up scaling.
}

- (NSArray *)sortedEventsFromDictionary:(NSDictionary *)reply
{
    NSArray *newEvents = reply[@"events"];

    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES];
    return [newEvents sortedArrayUsingDescriptors:@[descriptor]];
}

- (void)updateEventsIfNeeded
{
    // if lastEvent.date < now, we need new events.
    if (self.lastAfterDate == nil || [self.lastAfterDate compare:[NSDate now]] == NSOrderedAscending) {
        NSDictionary *reply = [self.sessionDelegate complicationEvents];
        self.events = [self sortedEventsFromDictionary:reply];
        self.lastStartTime = reply[@"startDate"];
        self.lastAfterDate = reply[@"endDate"];
    }
}

#pragma mark - Complication Configuration

// "ring" includes everything that wants interpolated events.
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
    // if lastEvent.date < now, we need new events. Which should not happen, because we make our own just before we call this.
    if ([lastDateEnd compare:date] == NSOrderedAscending) {
        return [events lastObject];
    }
    NSDictionary *lastTestedEvent = [events firstObject];
    for (NSDictionary *event in events) {
        NSDate *testDate = [event objectForKey:@"date"];
        // if event.date > now, return the one just before it. Text events will show upcoming from "next".
        if ([testDate compare:date] == NSOrderedDescending) {
            return lastTestedEvent;
        }
        lastTestedEvent = event;
    }
    return lastTestedEvent;
}


- (CLKComplicationTimelineEntry *)getCurrentTimelineEntryForComplication:(CLKComplication *)complication
{
    [self updateEventsIfNeeded];
    if (![self.events count]) {
        return nil;
    }
    NSDictionary *event = [self currentEventForComplication:complication];
    if (event) {
        return [self getEntryforComplication:complication withEvent:event];
    }
    return nil;
}

- (NSArray *)getTimelineEntriesForComplication:(CLKComplication *)complication
                                     afterDate:(NSDate *)date
                                         limit:(NSUInteger)limit
{
    // This extends the complications. Don't update the local cache; that's for near-future.
    NSDictionary *dict = [self.sessionDelegate complicationEventsAfterDate:date includeRing:[self isRingFamily:complication.family]];

    NSMutableArray *array = [NSMutableArray array];
    NSUInteger count = 0;
    NSArray *events = [self sortedEventsFromDictionary:dict];
    for (NSDictionary *event in events) {
        [array addObject:[self getEntryforComplication:complication withEvent:event]];
        count++;
        if (count == limit) {
            break;
        }
    }
    return array;
}

- (void)getComplicationDescriptorsWithHandler:(void (^)(NSArray<CLKComplicationDescriptor *> * _Nonnull))handler {
    NSArray<CLKComplicationDescriptor *> *descriptors = @[
        [[CLKComplicationDescriptor alloc] initWithIdentifier:@"complication"
                                                  displayName:@"XTide"
                                            supportedFamilies:CLKAllComplicationFamilies()]
        // Multiple complication support can be added here with more descriptors
    ];

    // Call the handler with the currently supported complication descriptors
    handler(descriptors);
}

- (void)handleSharedComplicationDescriptors:(NSArray<CLKComplicationDescriptor *> *)complicationDescriptors {
    // Do any necessary work to support these newly shared complication descriptors
}

#pragma mark - Timeline Configuration

- (void)getTimelineEndDateForComplication:(CLKComplication *)complication withHandler:(void(^)(NSDate * __nullable date))handler {
    // Call the handler with the last entry date you can currently provide or nil if you can't support future timelines
    [self updateEventsIfNeeded];
    handler(self.lastAfterDate);
}

- (void)getPrivacyBehaviorForComplication:(CLKComplication *)complication withHandler:(void(^)(CLKComplicationPrivacyBehavior privacyBehavior))handler {
    // Call the handler with your desired behavior when the device is locked
    handler(CLKComplicationPrivacyBehaviorShowOnLockScreen);
}

#pragma mark - Timeline Population

- (void)getCurrentTimelineEntryForComplication:(CLKComplication *)complication withHandler:(void(^)(CLKComplicationTimelineEntry * __nullable))handler {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Call the handler with the current timeline entry
        CLKComplicationTimelineEntry *entry = [self getCurrentTimelineEntryForComplication:complication];
        if (entry) {
            // It's the current entry. If it's a future event, we still want it now.
            if ([entry.date compare:[NSDate now]] == NSOrderedAscending) {
                entry.date = [NSDate now];
            }
            handler(entry);
        } else {
            // Icon-style complications use the asset image, but the text one needs text.
            handler([self getEntryforComplication:complication withEvent:nil]);
        }
    });
}

- (void)getTimelineEntriesForComplication:(CLKComplication *)complication afterDate:(NSDate *)date limit:(NSUInteger)limit withHandler:(void(^)(NSArray<CLKComplicationTimelineEntry *> * __nullable entries))handler {
    // Call the handler with the timeline entries after the given date
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *array = [self getTimelineEntriesForComplication:complication afterDate:date limit:limit];
        handler(array);
    });
}


#pragma mark - Entry generator

- (CGFloat)angleForEvent:(NSDictionary *)event
{
    NSNumber *number = [event objectForKey:@"angle"];
    return number ? [number floatValue] : 0.78; // Now that placeholders never appear on the watch face, use a real number
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

// A date for the placeholder image so it's consistent.
- (NSDate *)canonicalPlaceholderDate {
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    dateComponents.day = 22;
    dateComponents.month = 1;
    dateComponents.year = 1984;
    dateComponents.hour = 6;
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    return [gregorianCalendar dateFromComponents:dateComponents];
}

- (CLKFullColorImageProvider *)extraLargeImageProviderForEvent:(NSDictionary * _Nullable)event
API_AVAILABLE(watchos(5.0)) {
    CGFloat size = graphicExtraLarge[self.watchSize];
    NSDate *date = event ? [event objectForKey:@"date"] : [self canonicalPlaceholderDate];
    UIImage *image = [[XTSessionDelegate sharedDelegate] complicationImageWithSize:size forDate:date];
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

- (void)dimensionsForFamiy:(CLKComplicationFamily)family rectSize:(CGFloat *)outRectSize lineWidth:(CGFloat *)outLineWidth {
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
    *outRectSize = rectSize;
    *outLineWidth = lineWidth;
}

- (CLKImageProvider *)ringImageProviderForEvent:(NSDictionary * _Nullable)event
                                         family:(CLKComplicationFamily)family
{
    CGFloat rectSize = -1;
    CGFloat lineWidth = 4;
    [self dimensionsForFamiy:family rectSize:&rectSize lineWidth:&lineWidth];
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
        CGFloat lineWidth = 1;
        [self dimensionsForFamiy:family rectSize:&rectSize lineWidth:&lineWidth];

        if (rectSize < 0) {
            // Not set or not supported.
            return nil;
        }
        rectSize = rectSize / 2; // colorImageWithRect is aware of the scale.
        // Adjust if we use for other families.
        CGFloat ringInset = 2;
        CGFloat imgSize = 8;
        CGFloat handInset = 3;
        CGFloat angle = [self angleForEvent:event];
        UIImage *colorImage = [self colorImageWithRectSize:rectSize angle:angle mode:dial_normal ringInset:ringInset handInset:handInset dialImageSize:imgSize];
        CLKFullColorImageProvider *imageProvider = nil;
        if (@available(watchOS 6.0, *)) {
            UIImage *tintedImage = [self colorImageWithRectSize:rectSize angle:angle mode:dial_onepiece ringInset:ringInset handInset:handInset dialImageSize:imgSize];
            UIImage *bgImage = [self colorImageWithRectSize:rectSize angle:angle mode:dial_background ringInset:ringInset handInset:handInset dialImageSize:imgSize];
            UIImage *fgImage = [self colorImageWithRectSize:rectSize angle:angle mode:dial_foreground ringInset:ringInset handInset:handInset dialImageSize:imgSize];
            imageProvider = [CLKFullColorImageProvider providerWithFullColorImage:colorImage tintedImageProvider:[CLKImageProvider imageProviderWithOnePieceImage:tintedImage twoPieceImageBackground:bgImage twoPieceImageForeground:fgImage]];
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

- (UIImage *)colorImageWithRectSize:(CGFloat)rectSize
                              angle:(CGFloat)radians
                               mode:(XTColorDialMode)mode
                          ringInset:(CGFloat)ringInset
                          handInset:(CGFloat)handInset
                      dialImageSize:(CGFloat)imgSize
{
    BOOL tinted = mode != dial_normal;
    CGFloat lineWidth = 1;
    CGRect rect = CGRectMake(0, 0, rectSize, rectSize);
    UIGraphicsBeginImageContextWithOptions(rect.size, !tinted, 2);
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIColor *armColor = tinted ? [UIColor whiteColor] : [UIColor orangeColor];
    UIColor *iconColor = tinted ? [UIColor whiteColor] : self.tintColor;

    if (mode != dial_foreground) {
        CGContextSetFillColorWithColor(context, [[UIColor colorWithWhite:(tinted ? 0.8 : 0.1) alpha:(tinted ? 0.2 : 1)] CGColor]);
        CGContextFillRect(context, rect);
    }

    CGContextSetStrokeColorWithColor(context, [armColor CGColor]);
    CGContextSetLineWidth(context, 0.5);

    CGFloat iconMin = ringInset + 3;
    CGFloat radius = rectSize / 2;
    CGFloat realRadius = (radius - ringInset);
    CGFloat tickInset = (rectSize > 126) ? 8 : 5;
    CGPoint center = CGPointMake(radius, radius);
    //
#if 0     /* This is how to get the ring, if we want it. Watch clips a surprising amount of the image :( */
    CGFloat ringInset = 25;
    CGRect edgeRect = CGRectInset(rect, ringInset, ringInset);
    UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:edgeRect];
    ring.lineWidth = 0.5;
    [ring stroke];
 //   CGContextStrokeRect(context, edgeRect);
   // CGContextStrokeEllipseInRect(context, edgeRect);
#endif

    if (mode != dial_background) {
        if (radians >= 0) {
            UIBezierPath *arm = [UIBezierPath bezierPath];
            [arm moveToPoint:CGPointZero];
            [arm addLineToPoint:CGPointMake(0, -(realRadius - handInset))];
            arm.lineWidth = lineWidth;
            arm.lineCapStyle = kCGLineCapRound;
            CGAffineTransform position = CGAffineTransformMakeTranslation(center.x, center.y);
            position = CGAffineTransformRotate(position, radians);
            [arm applyTransform:position];
            [arm stroke];
        }
        CGContextSetFillColorWithColor(context, [armColor CGColor]);
        CGFloat dotInset = (rectSize - 4) / 2;
        CGRect dotRect = CGRectInset(rect, dotInset, dotInset);
        UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:dotRect];
        [dot fill];
    }

    if (mode != dial_foreground) {
        radians = 0;
        CGFloat pi_12 = M_PI_2 / 3;
        CGFloat imgHalf = imgSize / 2;
        CGContextSetFillColorWithColor(context, [iconColor CGColor]);
        CGContextSetStrokeColorWithColor(context, [[UIColor lightGrayColor] CGColor]);
        for (NSInteger i = 0, j = 0; i < 12; i++) {
            BOOL quarter = (i % 3) == 0;
            if (quarter) {
               // hightide lowtide downArrowImage upArrowImage
                UIImage *image;
                UIGraphicsPushContext(context);
                CGFloat iconMax = rectSize - iconMin;
                CGFloat x = iconMin;
                CGFloat y = iconMin;
                switch (j) {
                    case 0: x = center.x; image = [UIImage imageNamed:@"hightide"]; break;
                    case 1: y = center.y; image = [UIImage imageNamed:@"upArrowImage"]; break;
                    case 2: x = center.x; y = iconMax; image = [UIImage imageNamed:@"lowtide"]; break;
                    case 3: x = iconMax; y = center.y; image = [UIImage imageNamed:@"downArrowImage"]; break;
                }

                // drawing code comes here- look at CGContext reference
                // for available operations
                // this example draws the inputImage into the context
                [image drawInRect:CGRectMake(x - imgHalf, y - imgHalf, imgSize, imgSize)];

                // pop context
                UIGraphicsPopContext();
                j++;
            } else {
                UIBezierPath *tick = [UIBezierPath bezierPath];
                [tick moveToPoint:CGPointMake(0, -(realRadius - tickInset))];
                [tick addLineToPoint:CGPointMake(0, -realRadius)];
                tick.lineWidth = 1;
                CGAffineTransform position = CGAffineTransformMakeTranslation(center.x, center.y);
                position = CGAffineTransformRotate(position, radians);
                [tick applyTransform:position];
                [tick stroke];
            }

            radians += pi_12;
        }
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
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
        CGContextSetFillColorWithColor(context, [[UIColor lightGrayColor] CGColor]);
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

// The actual placeholder text shows up in Customize and should be meaningful.
- (CLKComplicationTimelineEntry *)getEntryforComplication:(CLKComplication *)complication
                                                withEvent:(NSDictionary * _Nullable)event
{
    CLKComplicationTemplate *template = nil;
    switch (complication.family) {
    case CLKComplicationFamilyModularLarge:
        {
        if (event) {
            template =
                [CLKComplicationTemplateModularLargeStandardBody templateWithHeaderImageProvider:[self utilImageProviderForEvent:event]
                    headerTextProvider:[self descTextProviderForEvent:event]
                                                                          body1TextProvider:[self levelTextProviderForEvent:event]
                                                                          body2TextProvider:[self dateProviderForEvent:event]];
        } else {
            template = [CLKComplicationTemplateModularLargeStandardBody templateWithHeaderImageProvider:[self utilImageProviderForEvent:event] headerTextProvider:[self noEventTextProvider] body1TextProvider:[CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Waiting for station information", @"Waiting for station information")]];
            // body1 will overflow into body2 if it needs to.
        }
        }
        break;
    case CLKComplicationFamilyExtraLarge:
        {
        template =
            [CLKComplicationTemplateExtraLargeStackImage templateWithLine1ImageProvider:[self ringImageProviderForEvent:event family:complication.family] line2TextProvider:[self shortLevelTextProviderForEvent:event]];
        }
        break;
    case CLKComplicationFamilyModularSmall:
        {
        template =
            [CLKComplicationTemplateModularSmallSimpleImage templateWithImageProvider:[self ringImageProviderForEvent:event family:complication.family]];
        }
        break;
    case CLKComplicationFamilyUtilitarianLarge:
        {
        CLKTextProvider *textProvider;
        if (event) {
            textProvider = [CLKTextProvider textProviderWithFormat:@"%@ %@",
                                                    [self descTextProviderForEvent:event],
                                                    [self levelTextProviderForEvent:event]];
        } else {
            textProvider = [self noEventTextProvider];
        }
        CLKComplicationTemplateUtilitarianLargeFlat *large =
            [CLKComplicationTemplateUtilitarianLargeFlat templateWithTextProvider:textProvider];
        large.imageProvider = [self utilImageProviderForEvent:event];
        template = large;
        }
        break;
    case CLKComplicationFamilyUtilitarianSmall:
    case CLKComplicationFamilyUtilitarianSmallFlat:
        {
        if (event) {
            template = [CLKComplicationTemplateUtilitarianSmallFlat templateWithTextProvider:[self levelTextProviderForEvent:event] imageProvider:[self utilImageProviderForEvent:event]];
        } else {
            template = [CLKComplicationTemplateUtilitarianSmallFlat templateWithTextProvider:[self noEventTextProvider] imageProvider:[self utilImageProviderForEvent:event]];
        }
        }
       break;
    case CLKComplicationFamilyCircularSmall:
        {
        template = [CLKComplicationTemplateCircularSmallSimpleImage templateWithImageProvider:[self ringImageProviderForEvent:event family:complication.family]];
        }
        break;
    case CLKComplicationFamilyGraphicCorner:
        if (@available(watchOS 5.0, *)) {
            template =
                [CLKComplicationTemplateGraphicCornerTextImage templateWithTextProvider:[self levelTextProviderForEvent:event] imageProvider:[self ringFullColorImageProviderForEvent:event family:complication.family]];
        }
        break;
    case CLKComplicationFamilyGraphicBezel:
        if (@available(watchOS 5.0, *)) {
            CLKComplicationTemplateGraphicCircularImage *circularTemplate =
                [CLKComplicationTemplateGraphicCircularImage templateWithImageProvider:[self ringFullColorImageProviderForEvent:event family:complication.family]];
            template =
                [CLKComplicationTemplateGraphicBezelCircularText templateWithCircularTemplate:circularTemplate textProvider:[self levelTextProviderForEvent:event]];
        }
        break;
    case CLKComplicationFamilyGraphicCircular:
        if (@available(watchOS 5.0, *)) {
            template =
                [CLKComplicationTemplateGraphicCircularImage templateWithImageProvider:[self ringFullColorImageProviderForEvent:event family:complication.family]];
        }
        break;
    case CLKComplicationFamilyGraphicRectangular:
        if (@available(watchOS 5.0, *)) {
            if (event) {
                template =
                [CLKComplicationTemplateGraphicRectangularStandardBody templateWithHeaderImageProvider:[self utilFullColorImageProviderForEvent:event] headerTextProvider:[self descTextProviderForEvent:event] body1TextProvider:[self levelTextProviderForEvent:event] body2TextProvider:[self dateProviderForEvent:event]];
            } else {
                template = [CLKComplicationTemplateGraphicRectangularStandardBody templateWithHeaderImageProvider:[self utilFullColorImageProviderForEvent:event] headerTextProvider:[self noEventTextProvider] body1TextProvider:[CLKSimpleTextProvider textProviderWithText:NSLocalizedString(@"Waiting for station information", @"Waiting for station information")]];
                // body1 will overflow into body2 if it needs to.
            }
        }
        break;
    case CLKComplicationFamilyGraphicExtraLarge:
         if (@available(watchOS 7.0, *)) {
            // It needs the event time for drawing, plus the rest for the ax text. Otherwise we could just fake it up by generating events with just the time.
            template =
                [CLKComplicationTemplateGraphicExtraLargeCircularImage templateWithImageProvider:[self extraLargeImageProviderForEvent:event]];
        }
        break;
    }

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
        template = [CLKComplicationTemplateModularLargeStandardBody templateWithHeaderImageProvider:[self utilImageProviderForEvent:nil] headerTextProvider:[self descTextProviderForEvent:nil] body1TextProvider:[self levelTextProviderForEvent:nil] body2TextProvider:[self dateProviderForEvent:nil]];
        }
        break;
    case CLKComplicationFamilyExtraLarge:
        {
        template =
            [CLKComplicationTemplateExtraLargeStackImage templateWithLine1ImageProvider:[self ringImageProviderForEvent:nil family:complication.family] line2TextProvider:[self shortLevelTextProviderForEvent:nil]];
        }
        break;
    case CLKComplicationFamilyModularSmall:
        {
        template =
            [CLKComplicationTemplateModularSmallSimpleImage templateWithImageProvider:[self ringImageProviderForEvent:nil family:complication.family]];
        }
        break;
    case CLKComplicationFamilyUtilitarianLarge:
        {
        template =
            [CLKComplicationTemplateUtilitarianLargeFlat templateWithTextProvider:[self descTextProviderForEvent:nil] imageProvider:[self utilImageProviderForEvent:nil]];
        }
        break;
    case CLKComplicationFamilyUtilitarianSmall:
    case CLKComplicationFamilyUtilitarianSmallFlat:
        {
        template =
            [CLKComplicationTemplateUtilitarianSmallFlat templateWithTextProvider:[self descTextProviderForEvent:nil] imageProvider:[self utilImageProviderForEvent:nil]];
        }
        break;
    case CLKComplicationFamilyCircularSmall:
        {
        template =
            [CLKComplicationTemplateCircularSmallSimpleImage templateWithImageProvider:[self ringImageProviderForEvent:nil family:complication.family]];
        }
        break;
    case CLKComplicationFamilyGraphicCorner:
        if (@available(watchOS 5.0, *)) {
            template =
                [CLKComplicationTemplateGraphicCornerTextImage templateWithTextProvider:[self levelTextProviderForEvent:nil] imageProvider:[self ringFullColorImageProviderForEvent:nil family:complication.family]];
        }
        break;
    case CLKComplicationFamilyGraphicBezel:
        if (@available(watchOS 5.0, *)) {
            CLKComplicationTemplateGraphicCircularImage *circularTemplate =
                [CLKComplicationTemplateGraphicCircularImage templateWithImageProvider:[self ringFullColorImageProviderForEvent:nil family:complication.family]];
            template =
                [CLKComplicationTemplateGraphicBezelCircularText templateWithCircularTemplate:circularTemplate textProvider:[self levelTextProviderForEvent:nil]];
        }
        break;
    case CLKComplicationFamilyGraphicCircular:
        if (@available(watchOS 5.0, *)) {
            template =
                [CLKComplicationTemplateGraphicCircularImage templateWithImageProvider:[self ringFullColorImageProviderForEvent:nil family:complication.family]];
        }
        break;
    case CLKComplicationFamilyGraphicRectangular:
        if (@available(watchOS 5.0, *)) {
            template =
                [CLKComplicationTemplateGraphicRectangularStandardBody templateWithHeaderImageProvider:[self utilFullColorImageProviderForEvent:nil] headerTextProvider:[self descTextProviderForEvent:nil] body1TextProvider:[self levelTextProviderForEvent:nil] body2TextProvider:[self dateProviderForEvent:nil]];
        }
        break;
    case CLKComplicationFamilyGraphicExtraLarge:
         if (@available(watchOS 7.0, *)) {
            template =
                [CLKComplicationTemplateGraphicExtraLargeCircularImage templateWithImageProvider:[self extraLargeImageProviderForEvent:nil]];
        }
        break;
    }
    handler(template);
}

@end
