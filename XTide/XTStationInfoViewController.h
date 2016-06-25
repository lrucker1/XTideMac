//
//  XTStationInfoViewController.h
//  XTide
//
//  Created by Lee Ann Rucker on 4/23/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface XTStationInfoViewController : NSViewController

@property IBOutlet NSTableView *tableView;
@property IBOutlet NSArrayController *arrayController;
@property (weak) NSPopover *popover;

- (void)reloadData;

@end
