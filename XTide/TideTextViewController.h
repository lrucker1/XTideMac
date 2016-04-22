//
//  TideTextViewController.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 5/5/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TideController.h"

@interface TideTextViewController : TideController
{
	IBOutlet NSStepper *dayStepper;
	IBOutlet NSStepper *hourStepper;
	IBOutlet NSTextField *dayField;
	IBOutlet NSTextField *hourField;
}

- (IBAction)timeEntry:(id)sender;
- (IBAction)timeStepped:(id)sender;
- (IBAction)updateStartTime:(id)sender;
- (IBAction)returnToNow:(id)sender;

- (void)computeEvents;
- (NSDate *)startDate;
- (NSDate *)endDate;

@end
