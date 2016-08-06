//
//  PreferenceController.h
//  XTide-Cocoa
//
//  Created by Lee Ann Rucker on 7/9/06.
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


@interface PreferenceController : NSWindowController {
	// @lar Aw, there's got to be a way to find these by their tags and build an array...
	IBOutlet NSColorWell *colorWell_daycolor;
	IBOutlet NSColorWell *colorWell_nightcolor;
	IBOutlet NSColorWell *colorWell_ebbcolor;
	IBOutlet NSColorWell *colorWell_floodcolor;
	IBOutlet NSColorWell *colorWell_markcolor;
	IBOutlet NSColorWell *colorWell_datumcolor;
	IBOutlet NSColorWell *colorWell_mslcolor;
	IBOutlet NSColorWell *colorWell_currentdotcolor;
	IBOutlet NSColorWell *colorWell_tidedotcolor;
	IBOutlet NSColorWell *colorWell_foreground;

	IBOutlet NSButton *checkBox_extralines;
	IBOutlet NSButton *checkBox_toplines;

	IBOutlet NSTextField *textfield_deflwidth;

	IBOutlet NSTextField *harmonicsInfoField;
	IBOutlet NSTextField *resourceHarmonicsInfoField;
	IBOutlet NSArrayController *harmonicsFileArray;
	
	IBOutlet NSComboBox *popup_combo;
	IBOutlet NSSlider *slider_opacity;
}

@property BOOL useStandardHarmonics;

- (IBAction)changeColor:(id)sender;
- (IBAction)changeExtralines:(id)sender;
- (IBAction)changeToplines:(id)sender;
- (IBAction)changeLinewidth:(id)sender;
- (IBAction)changeUnits:(id)sender;

- (IBAction)applyHarmonics:(id)sender;
- (IBAction)revertHarmonics:(id)sender;

@end
