//
//  XTCalendarEventViewController.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/20/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface XTCalendarEventViewController : NSViewController

@property IBOutlet NSPopUpButton *calendarPopup;

@property (weak) NSPopover *popover;
@property (nonatomic, strong) EKEventStore *eventStore;

- (IBAction)addEvent:(id)sender;

@end
