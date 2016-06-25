//
//  XTStation.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "XTStation.h"
#import "libxtide.hh"
#import "Station.hh"

@class XTTideEventsOrganizer;
@class XTCalendar;

@interface XTStation ()
{
   libxtide::Station *mStation;
	
	NSDateFormatter *timeFormatter;
	NSDateFormatter *dayFormatter;
}

- (instancetype)initUsingStationRef: (libxtide::StationRef *)aStationRef;

- (libxtide::Station *)adaptedStation;

- (XTCalendar *)loadCalendarFromStart: (NSDate *)startDate
								toEnd: (NSDate *)endDate;

- (NSString *)timeStringFromDate: (NSDate *)date;
- (NSString *)dayStringFromDate:(NSDate *)date;
- (double)aspect;
- (void)aspect: (double)anAspect;
- (libxtide::PredictionValue)markLevel;
- (void)markLevel: (libxtide::PredictionValue)aPredictionValue;
- (void)clearMarkLevel;

- (BOOL)isCurrent;
- (libxtide::Units::PredictionUnits)predictUnits;
- (void)setUnits: (libxtide::Units::PredictionUnits)units;
- (void)updateUnits;

- (NSString *)stationCalendarInfoFromDate:(NSDate *)startTime
                                   toDate:(NSDate *)endTime;
- (NSDictionary *)stationCalendarDataFromDate:(NSDate *)startTime
							  		   toDate: (NSDate *)endTime;
- (BOOL)hasMarkLevel;

  // The implementations given in Station are usable as-is for a
  // Reference Station but are overridden by SubordinateStation.
- (libxtide::PredictionValue)minLevel;
- (libxtide::PredictionValue)maxLevel;

- (void)predictTideEventsStart:(NSDate*)startTime
                           end:(NSDate*)endTime
                     organizer:(XTTideEventsOrganizer*)organizer
                        filter:(int)filter;

- (void)predictTideEventsStart:(NSDate*)startTime
                           end:(NSDate*)endTime
                     organizer:(XTTideEventsOrganizer*)organizer;

- (libxtide::PredictionValue)predictTideLevel:(NSDate *) predictTime;

@end
