//
//  DisclaimerController.m
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 7/18/06.
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

#import "DisclaimerController.h"
#import "XTSettings.h"

@implementation DisclaimerController
- (id)init
{
	return [super initWithWindowNibName:@"Disclaimer"];
}

- (void)awakeFromNib
{
	[checkBox_showdisclaimer setState:
		[[NSUserDefaults standardUserDefaults] boolForKey:XTide_showdisclaimer]];

}
- (IBAction)changeShowDisclaimer:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[checkBox_showdisclaimer state]
		forKey:XTide_showdisclaimer];
}

@end
