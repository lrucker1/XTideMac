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
#import "PrintPanelAccessoryController.h"
#import "PrintingTextView.h"


@implementation CalendarController

- (instancetype)initWith:(XTStationRef*)in_stationRef
{
	return [super initWithWindowNibName:@"TideCalendar" stationRef:in_stationRef];
}


- (NSString *)titleFormat
{
    return NSLocalizedString(@"%@ (Calendar)", @"Calendar window title");
}

- (NSDate *)defaultStartDate
{
    // Start at the beginning of the month.
    NSCalendar *currentCalendar = [NSCalendar currentCalendar];
    NSDate *first = [currentCalendar dateBySettingUnit:NSCalendarUnitDay value:1 ofDate:[NSDate date] options:0];
    return [currentCalendar startOfDayForDate:first];
}

- (NSAttributedString *)eventsString
{
	// Get the calendar HTML
	NSString *calHTML = [station stationCalendarInfoFromDate:[self startDate]
                                                      toDate:[self endDate]];
	return [[NSAttributedString alloc] initWithHTML:[calHTML dataUsingEncoding:NSASCIIStringEncoding]
                                 documentAttributes:NULL];
}

- (void)computeEvents
{
	[[textView textStorage] setAttributedString:[self eventsString]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    if (action == @selector(showCalendarForSelection:)) {
        return NO;
    }
    return YES;
}

#pragma mark print

- (IBAction)printTideView:(id)sender
{
    PrintingTextView *printingView = [PrintingTextView new];   // PrintingTextView is a simple subclass of NSTextView. Creating the view this way creates rest of the text system, which it will release when dealloc'ed (since the print panel will be releasing this, we want to hand off the responsibility of release everything)
    NSLayoutManager *layoutManager = [[printingView textContainer] layoutManager];
    NSTextStorage *printingTextStorage = [layoutManager textStorage];
    [printingTextStorage setAttributedString:[self eventsString]];
    [printingView setLayoutOrientation:[textView layoutOrientation]];
    [printingView setOriginalSize:[textView frame].size];

    NSPrintOperation *printOp = [self printOperationWithView:printingView];
    PrintPanelAccessoryController *accessoryController = [[[printOp printPanel] accessoryControllers] lastObject];
    accessoryController.showsWrappingToFit = YES;
    [printingView setPrintPanelAccessoryController:accessoryController];

    [printOp runOperation];
}

@end
