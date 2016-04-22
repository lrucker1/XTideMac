//
//  XTTideEvent.mm
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "XTTideEvent.h"
#import "XTStationInt.h"
#import "XTUtils.h"

@implementation XTTideEvent


// companions to descriptionWithForm, generates any header info needed when
// generating a list of TideEvents
+ (NSString*)descriptionListHeadForm:(char)form
                                mode:(char)mode
                             station:(XTStation*)station
{
    NSString *str;
    if (form == 'i') {
        str = [NSString stringWithFormat:
               @"BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:%@\r\nCALSCALE:GREGORIAN\r\nMETHOD:PUBLISH\r\n",
               @"XTide 1.0"];
    }
    else
        str = @"";
    return str;
}

// companions to descriptionWithForm, generates any ending info needed when
// generating a list of TideEvents
+ (NSString*)descriptionListTailForm:(char)form
                                mode:(char)mode
                             station:(XTStation*)station
{
    if (form == 'i')
        return @"END:VCALENDAR\r\n";
    return @"";
}

- (id)initWithTideEvent: (libxtide::TideEvent *)aTideEvent
{
    if ((self = [super init])) {
        mTideEvent = aTideEvent;
    }
    return self;
}

- (id)initWithDate: (NSDate *)aDate
{
    if ((self = [super init])) {
        eventDate = aDate;
    }
    return self;
}

- (void)dealloc
{
    // Created and owned by the TideEventOrganizer
    mTideEvent = NULL;
    eventDate = nil;
}

- (NSDate *)date
{
    if (eventDate) {
        return eventDate;
    }
    return TimestampToNSDate(mTideEvent->eventTime);
}


- (NSString *)timeForStation: (XTStation *)station
{
    if (eventDate) {
        return [station dayStringFromDate:eventDate];
    }
    return [station timeStringFromDate:TimestampToNSDate(mTideEvent->eventTime)];
}

- (NSString *)longDescription
{
    if (eventDate) {
        return @"";
    }
    return DstrToNSString(mTideEvent->longDescription());
}

- (NSString *)longDescriptionAndLevel
{
    if (eventDate) {
        return @"";
    }
    NSString *longDesc = DstrToNSString(mTideEvent->longDescription());
    Dstr levelPrint;
    NSString *displayLevel = @"";
    if (!mTideEvent->isSunMoonEvent()) {
        mTideEvent->eventLevel.print(levelPrint);
        displayLevel = DstrToNSString(levelPrint);
    }
    return [NSString stringWithFormat:@"%@ %@", longDesc, displayLevel];
}

// Generate one line of text output, applying global formatting
// rules and so on.
// Legal forms are c (CSV), t (text) or i (iCalendar).
// Legal modes are p (plain), r (raw), or m (medium rare).
// Line is not newline terminated.
- (NSString*)descriptionWithForm:(char)form
                            mode:(char)mode
                         station:(XTStation*)station
{
    if (eventDate) {
        return @"";
    }
    Dstr text_out;
    libxtide::Station *aStation = [station adaptedStation];
    mTideEvent->print(text_out, (libxtide::Mode::Mode)mode, (libxtide::Format::Format)form, *aStation);
    return DstrToNSString(text_out);
}

- (NSString *)description
{
    if (eventDate) {
        return [eventDate description];
    }
    NSDate *date = TimestampToNSDate(mTideEvent->eventTime);
    return [NSString stringWithFormat:@"%@ %@", date, [self longDescription]];
}

- (BOOL)isDateEvent
{
    return (eventDate != nil);
}

- (libxtide::TideEvent::EventType)eventType
{
    if (eventDate) {
        return libxtide::TideEvent::rawreading;
    }
    return mTideEvent->eventType;
}


@end
