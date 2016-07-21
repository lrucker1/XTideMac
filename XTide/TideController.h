//
//  TideController.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 7/15/06.
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

#import <Cocoa/Cocoa.h>

@class XTStationRef;
@class XTStation;
@class XTTideEventsOrganizer;

@interface TideController : NSWindowController <NSWindowDelegate, NSPopoverDelegate>
{
	XTStationRef *stationRef;
	XTStation *station;
	IBOutlet NSTextField *timeZoneFromLabel;
	IBOutlet NSDatePicker *dateFromPicker;
	
	// Sheet
	IBOutlet NSWindow *markSheet;
	IBOutlet NSButton *showMarkCheckbox;
	IBOutlet NSTextField *markValueText;
	IBOutlet NSComboBox *markUnitsCombo;
	IBOutlet NSTextField *aspectValueText;
}

@property (readwrite, retain) XTTideEventsOrganizer *organizer;

- (IBAction)showPopoverAction:(id)sender;
- (IBAction)showGraphForSelection:(id)sender;
- (IBAction)showDataForSelection:(id)sender;
- (IBAction)showCalendarForSelection:(id)sender;

- (IBAction)showOptionSheet:(id)sender;
- (IBAction)hideOptionSheet:(id)sender;

- (instancetype)initWithWindowNibName:(NSString*)nibName stationRef:(XTStationRef *)in_stationRef;
- (instancetype)initWith:(XTStationRef *)in_stationRef;

- (XTStation*)station;
// Set the window title to "station name - date"
- (void)setWindowTitleDate:(NSDate *)date;
- (void)updateLabels;

// Generate a text representation, even for graphic views
- (NSString*)stringWithIndexes:(NSIndexSet *)rowIndexes form:(char)form mode:(char)mode;

- (void)removeObservers;

- (void)popoverDidClose:(NSNotification *)notification;

@end
