//
//  XTStation.mm
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XTStationInt.h"
#if USE_HARMONICS
#import "XTStationRefInt.h"
#import "XTCalendar.h"
#else
#import "StationRef.hh"
#endif
#import "XTGraph.h"
#import "XTSettings.h"
#import "XTTideEvent.h"
#import "XTTideEventsOrganizer.h"
#import "XTUtils.h"
#import "PredictionValue.hh"
#import "Graph.hh"
#import "SVGGraph.hh"
#import "SubordinateStation.hh"
#import "Coordinates.hh"
#import "ConstituentSet.hh"
#import "Offsets.hh"
#import "CurrentBearing.hh"

static NSArray *unitsPrefMap = nil;
static NSTimeInterval DAY = 60 * 60 * 24;

namespace libxtide {

#if USE_HARMONICS == 0
const Dstr gFilename("");

float* get_float_array(NSArray *eqArray) {
    NSInteger count = [eqArray count];
    float *eqOut = (float *) calloc (count, sizeof (float));
    for (NSInteger i = 0; i < count; i++) {
        eqOut[i] = [eqArray[i] floatValue];
    }
    return eqOut;
}

// Get constituents from a TIDE_RECORD, adjusting if needed.
static const libxtide::ConstituentSet getConstituents (NSDictionary *dict) {
    //  assert (rec.header.record_type == REFERENCE_STATION);

    NSArray *conArray = dict[@"constituents"];

    Units::PredictionUnits amp_units = (Units::PredictionUnits)[dict[@"units"] intValue];
    SafeVector<libxtide::Constituent> constituents;

    // Null constituents should not be in the dictionary.
    int startYear = [dict[@"startYear"] intValue];
    int numberOfYears = [dict[@"numberOfYears"] intValue];
    float datum_offset = [dict[@"datumOffset"] floatValue];
    for (NSDictionary *con in conArray) {
        float *equilibriums = get_float_array(con[@"equilibriums"]);
        float *nodeFactors = get_float_array(con[@"nodeFactors"]);
        constituents.push_back (
                                Constituent ([con[@"speed"] doubleValue],
                                             startYear,
                                             numberOfYears,
                                             equilibriums,
                                             nodeFactors,
                                             Amplitude (amp_units, [con[@"amplitude"] doubleValue]),
                                             [con[@"phase"] floatValue]));
        free(equilibriums);
        free(nodeFactors);

    }
//    assert (!constituents.empty());

    PredictionValue datum (Units::flatten(amp_units), datum_offset);

    // We got the Constituents from a ConstituentSet, the adjustments have already happened.
    ConstituentSet cs (constituents, datum, SimpleOffsets());

    Dstr u (Global::settings["u"].s);
    if (u != "x")
        cs.setUnits (Units::parse (u));

    return cs;
}
#endif
}

@implementation XTStation

+ (NSArray *)unitsPrefMap
{
	if (unitsPrefMap == nil) {
		unitsPrefMap = [NSArray arrayWithObjects:@"x", @"ft", @"m", nil];
	}
	return unitsPrefMap;
}

#if USE_HARMONICS
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
#else
- (instancetype)initUsingDictionary:(NSDictionary *)dict
{
    if ((self = [super init])) {
/*
           const Dstr &name_,
           const Coordinates &coordinates,
           const Dstr &timezone,
           const ConstituentSet &constituents,
           const Dstr &note_,
           CurrentBearing minCurrentBearing_,
           CurrentBearing maxCurrentBearing_,
           const MetaFieldVector &metadata);

 */
        NSString *name = dict[@"name"];
        NSArray *conArray = dict[@"constituents"];
        if ([conArray count] == 0 || name == nil) {
            return nil;
        }

        NSNumber *latObj = dict[@"lat"];
        NSNumber *lngObj = dict[@"lng"];
        libxtide::Coordinates coordinates = libxtide::Coordinates();
        if (latObj != nil && lngObj != nil) {
            double lat = [latObj doubleValue];
            double lng = [lngObj doubleValue];
            coordinates = libxtide::Coordinates(lat, lng);
        }
        NSString *timezone = dict[@"timezone"];

        libxtide::CurrentBearing minCurrentBearing, maxCurrentBearing;
        libxtide::MetaFieldVector metadata;

        mStationRef = new libxtide::StationRef(libxtide::gFilename, 0, [name asDstr], coordinates, [timezone asDstr], [dict[@"isRef"] boolValue], [dict[@"isCurrent"] boolValue]);
        NSDictionary *hoDict = dict[@"hairyOffsets"];
        if (hoDict == nil) {
            mStation = new libxtide::Station([name asDstr],
                                   *mStationRef,
                                   libxtide::getConstituents(dict),
                                   Dstr(),
                                   minCurrentBearing,
                                   maxCurrentBearing,
                                   metadata
            );
        } else {
            int maxTimeAdd = [hoDict[@"maxTimeAdd"] intValue];
            int minTimeAdd = [hoDict[@"minTimeAdd"] intValue];
            double maxLevelMultiply = [hoDict[@"maxLevelMultiply"] doubleValue];
            double minLevelMultiply = [hoDict[@"minLevelMultiply"] doubleValue];
            NSDictionary *maxLevel = hoDict[@"maxLevelAdd"];
            int maxLU = [maxLevel[@"units"] intValue];
            double maxLevelAdd = [maxLevel[@"value"] doubleValue];

            NSDictionary *minLevel = hoDict[@"minLevelAdd"];
            int minLU = [minLevel[@"units"] intValue];
            double minLevelAdd = [minLevel[@"value"] doubleValue];

            NSNumber *floodObj = hoDict[@"floodBegins"];
            NSNumber *ebbObj = hoDict[@"ebbBegins"];

            libxtide::HairyOffsets ho (
                    libxtide::SimpleOffsets (libxtide::Interval(maxTimeAdd),
                                             libxtide::PredictionValue((libxtide::Units::PredictionUnits)maxLU, maxLevelAdd),
                                             maxLevelMultiply),
                    libxtide::SimpleOffsets (libxtide::Interval(minTimeAdd),
                                             libxtide::PredictionValue((libxtide::Units::PredictionUnits)minLU, minLevelAdd),
                                             minLevelMultiply),
                    floodObj == nil ? libxtide::NullableInterval() : libxtide::NullableInterval(libxtide::Interval([floodObj intValue])),
                    ebbObj == nil ? libxtide::NullableInterval() : libxtide::NullableInterval(libxtide::Interval([ebbObj intValue])));
            mStation = new libxtide::SubordinateStation([name asDstr],
                                   *mStationRef,
                                   libxtide::getConstituents(dict),
                                   Dstr(),
                                   minCurrentBearing,
                                   maxCurrentBearing,
                                   metadata,
                                   ho
            );
        }

        if (!mStation) {
            return nil;
        }
        [self updateUnits];
    }
    return self;
}
#endif

- (void)dealloc
{
   // Created and owned by self.
   delete mStation;
#if USE_HARMONICS == 0
    delete mStationRef;
#endif
}

- (NSString *)name
{
    return DstrToNSString(mStation->name);
}

#if USE_HARMONICS
- (XTStationRef *)stationRef
{
    libxtide::StationRef &ref = (libxtide::StationRef &)mStation->getStationRef();
    return [[XTStationRef alloc] initWithStationRef:&ref];
}
#endif

- (void)updateUnits
{
	NSString *unitType = XTSettings_ObjectForKey(XTide_units);
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

- (XTTideEvent *)nextMajorEventAfter:(NSDate *)startTime
{
    libxtide::Station::TideEventsFilter filter = mStation->isCurrent ? libxtide::Station::knownTideEvents
                                                                     : libxtide::Station::maxMin;
	XTTideEventsOrganizer *organizer = [[XTTideEventsOrganizer alloc] init];
    [self predictTideEventsStart:startTime
                             end:[startTime dateByAddingTimeInterval:DAY]
                       organizer:organizer
                          filter:(int)filter];
    return [[organizer standardEvents] firstObject];
}


// Generate an organizer with min/max events extending beyond the start/end dates.
- (XTTideEventsOrganizer *)populateOrganizerForWatchEventsStart:(NSDate *)startTime
                                                            end:(NSDate *)endTime
{
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
                          includeRing:(BOOL)includeRing
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
        Dstr levelPrint;
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
            desc = flood ? NSLocalizedString(@"Flood", @"Flood event")
                         : NSLocalizedString(@"Ebb", @"Ebb event");
        } else {
            desc = isRising ? NSLocalizedString(@"Rising", @"Rising event")
                            : NSLocalizedString(@"Falling", @"Falling event");
        }
        // Add the tide event, if it's in range; we may have picked up some extras for interpolation.
        // Split the intervening time evenly between it and the next one.
        [array addObject:[prev eventDictionary]];
        NSDictionary *nextShort = [next eventShortDictionary];
        libxtide::Interval timeDelta = (nextMaxOrMin.eventTime - previousMaxOrMin.eventTime) / hours;
        currentTime = previousMaxOrMin.eventTime;
        NSInteger i = 0;
        for (i = 0; i < hours-1; i++) {
            angle += arcDelta;
            currentTime += timeDelta;
            libxtide::PredictionValue prediction = mStation->predictTideLevel(currentTime);
            prediction.print(levelPrint);
            NSString *level = DstrToNSString(levelPrint);
            prediction.printnp(levelPrint);
            NSString *levelShort = DstrToNSString(levelPrint);

            NSDictionary *event = @{@"date"     : TimestampToNSDate(currentTime),
                                    @"angle"    : @(angle),
                                    @"level"    : level,
                                    @"levelShort" : levelShort,
                                    @"desc"     : desc,
                                    @"isRising" : @(isRising),
                                    @"next"     : nextShort};
            [array addObject:event];
            // Add extra ring events every 5 minutes.
            if (includeRing) {
                libxtide::Interval ringOffset = 0;
                libxtide::Interval ringDelta = 5 * 60;
                for (ringOffset = 0; ringOffset < timeDelta; ringOffset = ringOffset + ringDelta) {
                    libxtide::Timestamp ringTime = currentTime + ringOffset;
                    prediction = mStation->predictTideLevel(ringTime);
                    prediction.print(levelPrint);
                    level = DstrToNSString(levelPrint);
                    prediction.printnp(levelPrint);
                    levelShort = DstrToNSString(levelPrint);
                    NSDictionary *ringEvent = @{@"date"     : TimestampToNSDate(ringTime),
                                                @"angle"    : @(angle + (arcDelta/2)),
                                                @"level"    : level,
                                                @"levelShort" : levelShort,
                                                @"ringEvent" : @(YES)};
                    [array addObject:ringEvent];
                }
            }
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

- (void)setAspect: (double)anAspect
{
   mStation->aspect = anAspect;
}

- (NSTimeZone *)timeZone
{
   char *tzName = mStation->timezone.aschar();
	// Apparently these are the strings NSTimeZone groks, except they start with a ':'
   NSTimeZone *ret = [NSTimeZone timeZoneWithName:
				[NSString stringWithCString:&tzName[1] 
                                           encoding:NSISOLatin1StringEncoding]];
    // Custom tcd files may just use the name.
    if (ret == nil) {
        ret = [NSTimeZone timeZoneWithName:
				[NSString stringWithCString:tzName
                                           encoding:NSISOLatin1StringEncoding]];
    }
    if (ret == nil) {
        ret = [NSTimeZone systemTimeZone];
    }
    return ret;
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

- (NSData *)SVGImageWithWidth:(CGFloat)width
                       height:(CGFloat)height
                         date:(NSDate *)date
{
    Dstr text_out;
    libxtide::Timestamp time = libxtide::Timestamp((time_t)[date timeIntervalSince1970]);
    libxtide::SVGGraph g(width, height);
    g.drawTides(mStation, time);
    g.print(text_out);
    return [DstrToNSString(text_out) dataUsingEncoding:NSUTF8StringEncoding];
}

#if USE_HARMONICS
- (NSString *)stationCalendarInfoFromDate:(NSDate *)startTime
                                   toDate:(NSDate *)endTime
{
	return [[self loadCalendarFromStart:startTime toEnd:endTime] generateHTML];
}

- (NSDictionary *)stationCalendarDataFromDate:(NSDate *)startTime
                                       toDate:(NSDate *)endTime
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
#endif

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

#if USE_HARMONICS
- (NSDictionary *)stationValuesDictionary {
    XTStationRef *ref = self.stationRef;
    NSMutableDictionary *dict = [ref stationRefValuesDictionary];
    dict[@"name"] = [self name];
    libxtide::ConstituentSet consSet = mStation->getConstituentSet();
    dict[@"units"] = @(consSet.predictUnits());
    libxtide::SafeVector<libxtide::Constituent> cons = consSet.getConstituents();
    NSMutableArray *consArray = [NSMutableArray array];
    unsigned long length = cons.size();
    int startYear = cons[0].firstValidYear().val();
    int endYear = cons[0].lastValidYear().val();
    dict[@"startYear"] = @(startYear);
    dict[@"numberOfYears"] = @(endYear - startYear);
    dict[@"datumOffset"] = @(consSet.datum().val());

    for (int i=0;i<length;++i) {
        NSMutableDictionary *conObj = [NSMutableDictionary dictionary];
        double speedRPS = cons[i].speed.radiansPerSecond();
        conObj[@"speed"] = @(speedRPS / M_PI * 648000.0); // Constituent initializer expects degreesPerHour
        conObj[@"amplitude"] = @(cons[i].amplitude.val());
        conObj[@"phase"] = @(-cons[i].phase.getDegrees()); // Constituent initializer has negated the degrees; undo that.

        NSMutableArray *anglesArray = [NSMutableArray array];
        NSMutableArray *nodesArray = [NSMutableArray array];
        libxtide::SafeVector<libxtide::Angle> angles = cons[i].getEquilibriums();
        libxtide::SafeVector<double> nods = cons[i].getNodeFactors();

        for (libxtide::SafeVector<libxtide::Angle>::size_type i = 0; i < angles.size(); i++) {
           [anglesArray addObject:@(angles[i].getDegrees())];
        }

        for (libxtide::SafeVector<double>::size_type i = 0; i < nods.size(); i++) {
            [nodesArray addObject:@(nods[i])];
        }
        conObj[@"equilibriums"] = anglesArray;
        conObj[@"nodeFactors"] = nodesArray;
        [consArray addObject:conObj];
    }
    if (mStation->isSubordinateStation()) {
        libxtide::SubordinateStation *subStation = dynamic_cast<libxtide::SubordinateStation*>(mStation);
        if (subStation) {
            libxtide::HairyOffsets ho = subStation->getOffsets();
            NSMutableDictionary *hoDict = [NSMutableDictionary dictionary];
            [hoDict addEntriesFromDictionary:@{@"maxTimeAdd":@(ho.maxTimeAdd().s()),
                                               @"maxLevelMultiply":@(ho.maxLevelMultiply()),
                                               @"minTimeAdd":@(ho.minTimeAdd().s()),
                                               @"minLevelMultiply":@(ho.minLevelMultiply())}];
            // @"maxLevelAdd":@(ho.maxLevelAdd()),
            // @"minLevelAdd":@(ho.minLevelAdd()),
            [hoDict setObject:@{@"units":@(ho.maxLevelAdd().Units()), @"value":@(ho.maxLevelAdd().val())} forKey:@"maxLevelAdd"];
            [hoDict setObject:@{@"units":@(ho.minLevelAdd().Units()), @"value":@(ho.minLevelAdd().val())} forKey:@"minLevelAdd"];
            libxtide::NullableInterval floodBegins = ho.floodBegins();
            libxtide::NullableInterval ebbBegins = ho.ebbBegins();
            if (!floodBegins.isNull()) {
                [hoDict setObject:@(floodBegins.s()) forKey:@"floodBegins"];
            }
            if (!ebbBegins.isNull()) {
                [hoDict setObject:@(ebbBegins.s()) forKey:@"ebbBegins"];
            }
            dict[@"hairyOffsets"] = hoDict;
        }
    }
    dict[@"constituents"] = consArray;
    return dict;
}
#endif

#if TARGET_OS_IPHONE
- (NSDictionary *)clockInfoWithXSize:(CGFloat)xsize
                               ysize:(CGFloat)ysize
                               scale:(CGFloat)scale
{
    CGRect rect = CGRectMake(0, 0, xsize, ysize);
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, scale);

    XTTideEventsOrganizer *organizer = [[XTTideEventsOrganizer alloc] init];
    XTGraph *graph = [[XTGraph alloc] initClockModeWithXSize:xsize ysize:ysize scale:scale];
    [graph drawTides:self now:[NSDate date] organizer:organizer];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return @{@"clockImage" : image,
             @"clockEvents": [organizer eventsAsDictionary],
             @"title" : self.name
    };
}

// TODO: You know I want to do this to the Mac app icon...
- (NSDictionary *)iconInfoWithSize:(CGFloat)size
                             scale:(CGFloat)scale
                           forDate:(NSDate *)date
{
    CGRect rect = CGRectMake(0, 0, size, size);
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, scale);

    XTTideEventsOrganizer *organizer = [[XTTideEventsOrganizer alloc] init];
    XTGraph *graph = [[XTGraph alloc] initIconModeWithXSize:size ysize:size scale:scale];
    [graph drawTides:self now:date organizer:organizer];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return @{@"iconImage" : image,
             @"title" : self.name
    };
}

#else
- (NSDictionary *)clockInfoWithXSize:(CGFloat)xsize
                               ysize:(CGFloat)ysize
                               scale:(CGFloat)scale
{
    CGRect offscreenRect = CGRectMake(0, 0, xsize, ysize);
    NSSize size = offscreenRect.size;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextRef = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    NSGraphicsContext *graphicsContext = [NSGraphicsContext graphicsContextWithCGContext:contextRef flipped:YES];

    NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];
    [NSGraphicsContext setCurrentContext:graphicsContext];

    // translate/flip the graphics context (for transforming from CoreGraphics coordinates to default UI coordinates. The Y axis is flipped on regular coordinate systems)
    CGContextTranslateCTM(contextRef, 0.0, offscreenRect.size.height);
    CGContextScaleCTM(contextRef, 1.0, -1.0);

    XTTideEventsOrganizer *organizer = [[XTTideEventsOrganizer alloc] init];
    XTGraph *graph = [[XTGraph alloc] initClockModeWithXSize:xsize ysize:ysize scale:scale];
    [graph drawTides:self now:[NSDate date] organizer:organizer];

    CGColorSpaceRelease(colorSpace);
    CGImageRef imageRef = CGBitmapContextCreateImage(contextRef);
    [NSGraphicsContext setCurrentContext:currentContext];

    NSImage *image = [[NSImage alloc] initWithCGImage:imageRef size:NSZeroSize];

    return @{@"clockImage" : image,
             @"clockEvents": [organizer eventsAsDictionary] };
}

- (NSDictionary *)iconInfoWithSize:(CGFloat)size
                             scale:(CGFloat)scale
                           forDate:(NSDate *)date
{
// TODO: You know I want to do this to the Mac app icon...
    return nil;
}
#endif
@end
