//
//  XTStation.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XTStation.h"
#import "libxtide.hh"
#import "Station.hh"

@class XTTideEventsOrganizer;
@class XTCalendar;

@interface XTStation ()
{
   libxtide::Station *mStation;
#if USE_HARMONICS == 0
   libxtide::StationRef *mStationRef;
#endif

	NSDateFormatter *timeFormatter;
	NSDateFormatter *dayFormatter;
	NSDateFormatter *dateFormatter;
}

#if USE_HARMONICS
- (instancetype)initUsingStationRef: (libxtide::StationRef *)aStationRef;
#else
- (instancetype)initUsingDictionary:(NSDictionary *)dict;
#endif

- (libxtide::Station *)adaptedStation;

#if USE_HARMONICS
- (XTCalendar *)loadCalendarFromStart: (NSDate *)startDate
								toEnd: (NSDate *)endDate;
#endif

- (libxtide::PredictionValue)markLevel;
- (void)markLevel: (libxtide::PredictionValue)aPredictionValue;
- (void)clearMarkLevel;

- (BOOL)isCurrent;
- (libxtide::Units::PredictionUnits)predictUnits;
- (void)setUnits: (libxtide::Units::PredictionUnits)units;
- (void)updateUnits;

#if USE_HARMONICS
- (NSString *)stationCalendarInfoFromDate:(NSDate *)startTime
                                   toDate:(NSDate *)endTime;
- (NSDictionary *)stationCalendarDataFromDate:(NSDate *)startTime
							  		   toDate: (NSDate *)endTime;
#endif
- (BOOL)hasMarkLevel;

  // The implementations given in Station are usable as-is for a
  // Reference Station but are overridden by SubordinateStation.
- (libxtide::PredictionValue)minLevel;
- (libxtide::PredictionValue)maxLevel;

- (libxtide::PredictionValue)predictTideLevel:(NSDate *) predictTime;

@end
