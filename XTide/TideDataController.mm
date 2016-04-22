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

@property (readwrite, retain) NSMutableDictionary *images;
@property (nonatomic, readwrite, retain) NSDictionary *detailAttributes;

@end

@implementation TideDataController

@synthesize images;
@synthesize detailAttributes;

- (id)initWith:(XTStationRef*)in_stationRef;
{
	return [super initWithWindowNibName:@"TideData" stationRef:in_stationRef];
}

- (void)dealloc
{
	self.images = nil;
	self.detailAttributes = nil;
}


- (void)windowWillClose:(NSNotification*)note
{
    tideTableView.delegate = nil;
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
    [organizer reloadData];
	[tideTableView noteNumberOfRowsChanged];
	[tideTableView reloadData];
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    if (action == @selector(showDataForSelection:)) {
        return NO;
    }
    return YES;
}

- (NSImage *)imageWithName: (NSString *)name
{
	if (!self.images) {
		self.images = [NSMutableDictionary dictionary];
	}
	NSImage *image = [self.images objectForKey:name];
	if (!image) {
		image = [NSImage imageNamed:name];
		[self.images setObject:image forKey:name];
	}
	return image;
}

- (NSDictionary *)detailAttributes
{
	if (!detailAttributes) {
		self.detailAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSColor grayColor], NSForegroundColorAttributeName,
			[NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
			nil];
	}
	return detailAttributes;
}

// Table dataSource methods
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [organizer count];
}


- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)rowIndex
{
	return [[organizer objectAtIndex:rowIndex] isDateEvent];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	XTTideEvent *tideEvent = [organizer objectAtIndex:rowIndex];
	if ([tideEvent isDateEvent]) {
		return [tideEvent timeForStation:station];
	}
	if ([[aTableColumn identifier] isEqualToString:@"data"]) {
		NSMutableAttributedString *text =
			[[NSMutableAttributedString alloc] initWithString:
					[NSString stringWithFormat:@"%@\n", tideEvent.longDescriptionAndLevel]];
		[text appendAttributedString:
			[[NSAttributedString alloc] initWithString:[tideEvent timeForStation:station]
				attributes:self.detailAttributes]];
		return text;
	}
	NSImage *image = nil;
	switch (tideEvent.eventType) {
		case libxtide::TideEvent::sunrise:
			image = [self imageWithName:@"sunrise"];
			break;
		case libxtide::TideEvent::sunset:
			image = [self imageWithName:@"sunset"];
			break;
		case libxtide::TideEvent::moonrise:
			image = [self imageWithName:@"moonrise"];
			break;
		case libxtide::TideEvent::moonset:
			image = [self imageWithName:@"moonset"];
			break;
		case libxtide::TideEvent::newmoon:
			image = [self imageWithName:@"newmoon"];
			break;
		case libxtide::TideEvent::firstquarter:
			image = [self imageWithName:@"firstquarter"];
			break;
		case libxtide::TideEvent::fullmoon:
			image = [self imageWithName:@"fullmoon"];
			break;
		case libxtide::TideEvent::lastquarter:
			image = [self imageWithName:@"lastquarter"];
			break;
		case libxtide::TideEvent::max:
			image = [self imageWithName:@"hightide"];
			break;
		case libxtide::TideEvent::min:
			image = [self imageWithName:@"lowtide"];
			break;
		case libxtide::TideEvent::slackrise:
		case libxtide::TideEvent::markrise:
			image = [self imageWithName:@"rising"];
			break;
		case libxtide::TideEvent::slackfall:
		case libxtide::TideEvent::markfall:
			image = [self imageWithName:@"falling"];
			break;
		default:
			image = [self imageWithName:@"blank"];
			break;
	}
	return image;
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    if (tableColumn != nil) {
        if ([[organizer objectAtIndex:rowIndex] isDateEvent]) {
            // Use a shared cell setup in IB via an IBOutlet
            return _sharedGroupTitleCell;
        } else {
            return [tableColumn dataCell];
        }
    } else {
       if ([[organizer objectAtIndex:rowIndex] isDateEvent]) {
         // A nil table column is for a "full width" table column
			return _sharedGroupTitleCell;
		}
		return nil;
    }
}


// We make the "group rows" have a given height
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)rowIndex
{
	if ([[organizer objectAtIndex:rowIndex] isDateEvent]) {
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
