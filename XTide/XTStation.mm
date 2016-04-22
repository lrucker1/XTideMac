//
//  XTStation.mm
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XTStationInt.h"
#import "XTCalendar.h"
#import "XTSettings.h"
#import "XTTideEventsOrganizer.h"
#import "XTUtils.h"
#import "PredictionValue.hh"

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

- (NSDateFormatter *)timeFormatter
{
	if (!timeFormatter) {
		timeFormatter = [[NSDateFormatter alloc] init];
		[timeFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[timeFormatter setDateStyle:NSDateFormatterNoStyle];
		[timeFormatter setTimeStyle:NSDateFormatterMediumStyle];
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
	}
	return dayFormatter;
}

- (NSString *)timeStringFromDate:(NSDate *)date
{
   return [[self timeFormatter] stringFromDate:date];
}

- (NSString *)dayStringFromDate:(NSDate *)date
{
   return [[self dayFormatter] stringFromDate:date];
}

- (void)predictTideEventsStart:(NSDate*)startTime
                           end:(NSDate*)endTime
                     organizer:(XTTideEventsOrganizer*)organizer
                        filter:(int)filter
{
   libxtide::Timestamp start = libxtide::Timestamp((time_t)[startTime timeIntervalSince1970]);
   libxtide::Timestamp end = libxtide::Timestamp((time_t)[endTime timeIntervalSince1970]);

   mStation->predictTideEvents(start,
                               end,
                               [organizer adaptedOrganizer],
                               (libxtide::Station::TideEventsFilter)filter);
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
}

- (libxtide::PredictionValue)predictTideLevel:(NSDate *)predictTime
{
   libxtide::Timestamp predict = libxtide::Timestamp((time_t)[predictTime timeIntervalSince1970]);
   return mStation->predictTideLevel(predict);
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
					encoding: NSISOLatin1StringEncoding]];
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

- (NSDictionary *)stationInfoDictionary
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
