//
//  CalendarController.m
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 7/20/06.
//  Copyright 2006 . 
//
/*
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "CalendarController.h"
#import "XTStationRef.h"
#import "XTStationInt.h"


@implementation CalendarController

- (instancetype)initWith:(XTStationRef*)in_stationRef
{
	return [super initWithWindowNibName:@"TideCalendar" stationRef:in_stationRef];
}

- (void)dealloc
{
}

- (NSInteger)defaultDayRange
{
	return 30;
}

- (void)computeEvents
{
	// Get the calendar HTML
	NSString *calHTML = [station stationCalendarInfoFromDate:[self startDate]
                                                      toDate:[self endDate]];
	NSAttributedString *calString =
		[[NSAttributedString alloc] initWithHTML:[calHTML dataUsingEncoding:NSASCIIStringEncoding]
									 documentAttributes:NULL];
	[[textView textStorage] setAttributedString:calString];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    if (action == @selector(showCalendarForSelection:)) {
        return NO;
    }
    return YES;
}


@end
