//
//  XTStation.mm
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XTStationInt.h"
#import "XTStationRefInt.h"
#import "XTCalendar.h"
#import "XTSettings.h"
#import "XTTideEvent.h"
#import "XTTideEventsOrganizer.h"
#import "XTUtils.h"
#import "PredictionValue.hh"
#import "Graph.hh"
#import "SVGGraph.hh"

static NSArray *unitsPrefMap = nil;

@implementation XTStation

+ (NSArray *)unitsPrefMap
{
	if (unitsPrefMap == nil) {
		unitsPrefMap = [NSArray arrayWithObjects:@"x", @"ft", @"m", nil];
	}
	return unitsPrefMap;
}

- (id)initUsingStationRef: (libxtide::StationRef *)aStationRef
{
    if ((self = [super init])) {
        mStation = aStationRef->load();
        if (!mStation) {
            return nil;
        }
        [self updateUnits];
    }
    return self;
}

- (void)dealloc
{
   // Created and owned by self.
   delete mStation;
}

- (NSString *)name
{
    return DstrToNSString(mStation->name);
}

- (XTStationRef *)stationRef
{
    libxtide::StationRef &ref = (libxtide::StationRef &)mStation->getStationRef();
    return [[XTStationRef alloc] initWithStationRef:&ref];
}

- (void)updateUnits
{
	NSString *unitType = [[NSUserDefaults standardUserDefaults] objectForKey:XTide_units];
    if (!unitType) {
        unitType = @"ft";
    }
	if (![unitType isEqualToString:@"x"]) {
		libxtide::Units::PredictionUnits units = libxtide::Units::parse([unitType UTF8String]);
		[self setUnits:units];
	}
}

- (libxtide::Station *)adaptedStation
{
   return mStation;
}

// Time must be NSDateFormatterLongStyle to get timeZone.
- (NSDateFormatter *)timeFormatter
{
	if (!timeFormatter) {
		timeFormatter = [[NSDateFormatter alloc] init];
		[timeFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[timeFormatter setDateStyle:NSDateFormatterNoStyle];
		[timeFormatter setTimeStyle:NSDateFormatterLongStyle];
		[timeFormatter setTimeZone:[self timeZone]];
	}
	return timeFormatter;
}

- (NSDateFormatter *)dayFormatter
{
	if (!dayFormatter) {
		dayFormatter = [[NSDateFormatter alloc] init];
		[dayFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[dayFormatter setDateStyle:NSDateFormatterMediumStyle];
		[dayFormatter setTimeStyle:NSDateFormatterNoStyle];
		[dayFormatter setTimeZone:[self timeZone]];
    }
	return dayFormatter;
}

- (NSDateFormatter *)dateFormatter
{
	if (!dateFormatter) {
		dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
		[dateFormatter setTimeStyle:NSDateFormatterLongStyle];
		[dateFormatter setTimeZone:[self timeZone]];
	}
	return dateFormatter;
}

- (NSString *)timeStringFromDate:(NSDate *)date
{
   return [[self timeFormatter] stringFromDate:date];
}

- (NSString *)dayStringFromDate:(NSDate *)date
{
   return [[self dayFormatter] stringFromDate:date];
}

- (NSString *)dateStringFromDate:(NSDate *)date
{
   return [[self dateFormatter] stringFromDate:date];
}

// Generate an organizer with min/max events extending beyond the start/end dates.
- (XTTideEventsOrganizer *)populateOrganizerForWatchEventsStart:(NSDate *)startTime
                                                            end:(NSDate *)endTime
{
    static NSTimeInterval DAY = 60 * 60 * 24;
    libxtide::Station::TideEventsFilter filter = mStation->isCurrent ? libxtide::Station::knownTideEvents
                                                                     : libxtide::Station::maxMin;

    XTTideEventsOrganizer *organizer = [[XTTideEventsOrganizer alloc] init];
    // Generate min/max events, with at least one before and after the range for interpolation.
    [self predictTideEventsStart:[startTime dateByAddingTimeInterval:-DAY]
                             end:[endTime dateByAddingTimeInterval:DAY]
                       organizer:organizer
                          filter:filter];
    NSInteger paranoiaCount = 0;
    while ([[(XTTideEvent *)[[organizer standardEvents] firstObject] date] compare:startTime] != NSOrderedAscending) {
        [self extendRange:organizer
                direction:libxtide::Station::backward
                 interval:libxtide::Global::day
                   filter:filter];
        paranoiaCount++;
        if (paranoiaCount > 5) {
            break;
        }
    }
    paranoiaCount = 0;
    while ([[(XTTideEvent *)[[organizer standardEvents] lastObject] date] compare:startTime] != NSOrderedDescending) {
        [self extendRange:organizer
                direction:libxtide::Station::forward
                 interval:libxtide::Global::day
                   filter:filter];
        paranoiaCount++;
        if (paranoiaCount > 5) {
            break;
        }
    }
    return organizer;
}

/*
 * Return the tide events as dictionary objects for a watch:
 * min/max, plus level and angle at every hour.
 * Angle is in radians.
 */
- (NSArray *)generateWatchEventsStart:(NSDate *)startTime
                                  end:(NSDate *)endTime
{
    XTTideEventsOrganizer *organizer = [self populateOrganizerForWatchEventsStart:startTime end:endTime];
    libxtide::Timestamp currentTime = libxtide::Timestamp((time_t)[startTime timeIntervalSince1970]);
    libxtide::Timestamp endTimestamp = libxtide::Timestamp((time_t)[endTime timeIntervalSince1970]);
    NSArray *events = [organizer standardEvents];

    NSMutableArray *array = [NSMutableArray array];
    NSEnumerator *enumerator = [events objectEnumerator];
    XTTideEvent *prev = [enumerator nextObject];
    XTTideEvent *next = [enumerator nextObject];
    if (!next) {
        return nil;
    }
    // Find first pair.
    while (next && [next adaptedTideEvent].eventTime <= currentTime) {
        prev = next;
        next = [enumerator nextObject];
    }
    if (!next) {
        return nil;
    }
    BOOL isCurrent = mStation->isCurrent;
    // Size of the arc between each event: 1/12 radians.
    double arcDelta = M_PI / 6;
    // Number of "hours" (1/12th of clock) between each event.
    // Currents have 4 events per day, Tides have 2.
    int hours = isCurrent ? 3 : 6;
    // Go through all min/max events, compute intermediate rising/falling events with angle and level.
    while (next) {
        libxtide::TideEvent previousMaxOrMin = [prev adaptedTideEvent];
        libxtide::TideEvent nextMaxOrMin = [next adaptedTideEvent];
        if (previousMaxOrMin.eventTime > endTimestamp) {
            break;
        }
        BOOL isRising = previousMaxOrMin.eventType == libxtide::TideEvent::min;
        NSString *desc = nil;
        double angle = [prev clockAngle];
        if (isCurrent) {
            // Rising (up arrow) between min and max, Flood between slackrise/slackfall
            isRising |= previousMaxOrMin.eventType == libxtide::TideEvent::slackrise;
            BOOL flood =    previousMaxOrMin.eventType == libxtide::TideEvent::slackrise
                         || previousMaxOrMin.eventType == libxtide::TideEvent::max;
            desc = flood ? @"Flood" : @"Ebb";
        } else {
            desc = isRising ? @"Rising" : @"Falling";
        }
        // Add the tide event, if it's in range; we may have picked up some extras for interpolation.
        // Split the intervening time evenly between it and the next one.
        [array addObject:[prev eventDictionary]];
        libxtide::Interval timeDelta = (nextMaxOrMin.eventTime - previousMaxOrMin.eventTime) / hours;
        currentTime = previousMaxOrMin.eventTime;
        NSInteger i = 0;
        for (i = 0; i < hours-1; i++) {
            angle += arcDelta;
            currentTime += timeDelta;
            Dstr levelPrint;
            libxtide::PredictionValue prediction = mStation->predictTideLevel(currentTime);
            prediction.print(levelPrint);
            NSString *level = DstrToNSString(levelPrint);
            prediction.printnp(levelPrint);
            NSString *levelShort = DstrToNSString(levelPrint);
           
            NSDictionary *event = @{@"date"  : TimestampToNSDate(currentTime),
                                    @"angle" : @(angle),
                                    @"level" : level,
                                    @"levelShort" : levelShort,
                                    @"desc"     : desc,
                                    @"isRising" : @(isRising)};
            [array addObject:event];
        }
        prev = next;
        next = [enumerator nextObject];
    }
    return array;
}


- (void)predictTideEventsStart:(NSDate *)startTime
                           end:(NSDate *)endTime
                     organizer:(XTTideEventsOrganizer *)organizer
                        filter:(int)filter
{
   libxtide::Timestamp start = libxtide::Timestamp((time_t)[startTime timeIntervalSince1970]);
   libxtide::Timestamp end = libxtide::Timestamp((time_t)[endTime timeIntervalSince1970]);

   mStation->predictTideEvents(start,
                               end,
                               [organizer adaptedOrganizer],
                               (libxtide::Station::TideEventsFilter)filter);
    [organizer reloadData];
}

- (void)predictTideEventsStart:(NSDate*)startTime
                           end:(NSDate*)endTime
                     organizer:(XTTideEventsOrganizer*)organizer
{
   libxtide::Timestamp start = libxtide::Timestamp((time_t)[startTime timeIntervalSince1970]);
   libxtide::Timestamp end = libxtide::Timestamp((time_t)[endTime timeIntervalSince1970]);
   mStation->predictTideEvents(start,
                               end,
                               [organizer adaptedOrganizer]);
    [organizer reloadData];
}

- (libxtide::PredictionValue)predictTideLevel:(NSDate *)predictTime
{
   libxtide::Timestamp predict = libxtide::Timestamp((time_t)[predictTime timeIntervalSince1970]);
   return mStation->predictTideLevel(predict);
}

- (void)extendRange:(XTTideEventsOrganizer *)organizer
          direction:(libxtide::Station::Direction)direction
		   interval:(libxtide::Interval)howMuch
             filter:(libxtide::Station::TideEventsFilter)filter
{
    mStation->extendRange([organizer adaptedOrganizer], direction, howMuch, filter);
    [organizer reloadData];
}

- (void)markLevel: (libxtide::PredictionValue)aPredictionValue
{
   mStation->markLevel = aPredictionValue;
}

- (void)clearMarkLevel
{
   mStation->markLevel.makeNull();
}

- (void)aspect: (double)anAspect
{
   mStation->aspect = anAspect;
}

- (NSTimeZone *)timeZone
{
   char *tzName = mStation->timezone.aschar();
	//  Apparently these are the strings NSTimeZone groks, except they start with a ':'
   return [NSTimeZone timeZoneWithName:
				[NSString stringWithCString:&tzName[1] 
                                   encoding:NSISOLatin1StringEncoding]];
}

- (libxtide::PredictionValue)minLevel {return mStation->minLevelHeuristic();}
- (libxtide::PredictionValue)maxLevel {return mStation->maxLevelHeuristic();}

- (BOOL)hasMarkLevel
{
   return !mStation->markLevel.isNull();
}
- (double)aspect {return mStation->aspect;}
- (libxtide::PredictionValue)markLevel {return mStation->markLevel;}
- (BOOL)isCurrent {return mStation->isCurrent;}
- (libxtide::Units::PredictionUnits)predictUnits {return mStation->predictUnits();}

- (void)setUnits: (libxtide::Units::PredictionUnits)units
{
   mStation->setUnits(units);
}

- (NSString *)stationInfoAsHTML
{
	Dstr text_out;
	mStation->aboutMode(text_out, libxtide::Format::HTML, libxtide::Global::codeset);
	return DstrToNSString(text_out);
}


- (NSString *)stationCalendarInfoFromDate: (NSDate *)startTime
											  toDate: (NSDate *)endTime
{
	return [[self loadCalendarFromStart:startTime toEnd:endTime] generateHTML];
}

- (NSDictionary *)stationCalendarDataFromDate: (NSDate *)startTime
											      toDate: (NSDate *)endTime
{
	return [[self loadCalendarFromStart:startTime toEnd:endTime] generateDataSource];
}

- (XTCalendar *)loadCalendarFromStart: (NSDate *)startTime
										  toEnd: (NSDate *)endTime
{
    return [[XTCalendar alloc] initWithStation:self
                                     startTime:startTime
                                       endTime:endTime];
}

- (NSArray *)stationMetadata
{
	NSMutableArray *array = [NSMutableArray array];
	const libxtide::MetaFieldVector metadata = mStation->metadata();
	libxtide::MetaFieldVector::const_iterator it = metadata.begin();
    while (it != metadata.end()) {
        Dstr name (it->name), value (it->value);
        [array addObject:@{@"name" : DstrToNSString(name), @"value" : DstrToNSString(value)}];
		++it;
	}
	return array;
}

- (NSDictionary *)stationInfoDictionarys
{
	NSMutableDictionary *infoDict = [NSMutableDictionary dictionary];
	const libxtide::MetaFieldVector metadata = mStation->metadata();
	libxtide::MetaFieldVector::const_iterator it = metadata.begin();
    while (it != metadata.end()) {
      Dstr name (it->name), value (it->value);
		[infoDict setObject:DstrToNSString(value) forKey:DstrToNSString(name)];
		++it;
	}
	return infoDict;
}

@end
