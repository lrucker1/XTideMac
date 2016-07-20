//
//  TideDataController.m
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 7/10/06.
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

#import "TideController.h"
#import "TideDataController.h"
#import "XTStationRef.h"
#import "XTStationInt.h"
#import "XTTideEventsOrganizer.h"
#import "XTTideEvent.h"
#import "XTGraph.h"

#include "config.h"

@interface TideDataController ()

@end

@implementation XTTideEventTableCellView
@end

@implementation TideDataController


- (id)initWith:(XTStationRef*)in_stationRef;
{
	return [super initWithWindowNibName:@"TideData" stationRef:in_stationRef];
}

- (void)windowWillClose:(NSNotification*)note
{
    tideTableView.delegate = nil;
    tideTableView.dataSource = nil;
    [super windowWillClose:note];
}


// Events and display
- (void)computeEvents
{
	XTTideEventsOrganizer *tempOrganizer =
      [[XTTideEventsOrganizer alloc] init];
	[station predictTideEventsStart:[[self startDate] dateByAddingTimeInterval:(-60)]
                                end:[[self endDate] dateByAddingTimeInterval:(60)]
                          organizer:tempOrganizer
                             filter:libxtide::Station::noFilter];
	self.organizer = tempOrganizer;
	[tideTableView reloadData];
}

- (IBAction)hideOptionSheet:(id)sender
{
    [super hideOptionSheet:sender];
    [self computeEvents];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    if (action == @selector(showDataForSelection:)) {
        return NO;
    }
    return YES;
}

// Table dataSource methods
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [self.organizer count];
}


- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)rowIndex
{
    if (rowIndex >= [self.organizer count]) return NO;
	return [[self.organizer objectAtIndex:rowIndex] isDateEvent];
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    XTTideEvent *tideEvent = [self.organizer objectAtIndex:row];
    XTTideEventTableCellView *view = nil;
    if ([tideEvent isDateEvent]) {
        view = [tableView makeViewWithIdentifier:@"header" owner:self];
        view.textField.stringValue = [tideEvent timeForStation:station];
    } else {
        view = [tableView makeViewWithIdentifier:@"event" owner:self];
        view.textField.stringValue = tideEvent.longDescriptionAndLevel;
        view.subtitleField.stringValue = [tideEvent timeForStation:station];
        NSString *imgString = tideEvent.eventTypeString;
        if ([imgString length] == 0) {
            imgString = @"blank";
        }
        view.imageView.image = [NSImage imageNamed:imgString];
    }
    return view;
}

// We make the "group rows" have a given height
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)rowIndex
{
	if ([[self.organizer objectAtIndex:rowIndex] isDateEvent]) {
        return 17.0;
    } else {
        return [tableView rowHeight];
    }
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
	NSString *str = [self stringWithIndexes:rowIndexes form:libxtide::Format::text mode:libxtide::Mode::plain];
	if (str == nil)
		return NO;
		
	[pboard declareTypes: [NSArray arrayWithObject:NSStringPboardType] owner:self];		
	[pboard setString:str forType:NSStringPboardType];
	return YES;
}

@end
