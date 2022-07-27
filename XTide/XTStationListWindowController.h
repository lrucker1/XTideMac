//
//  XTStationListWindowController.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/27/22.
//  Copyright © 2022 Lee Ann Rucker. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface XTStationListWindowController : NSWindowController

@property IBOutlet NSTableView *tableView;
@property IBOutlet NSArrayController *arrayController;

@end

NS_ASSUME_NONNULL_END
