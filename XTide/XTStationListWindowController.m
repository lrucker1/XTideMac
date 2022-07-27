//
//  XTStationListWindowController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/27/22.
//  Copyright © 2022 Lee Ann Rucker. All rights reserved.
//

#import "XTStationListWindowController.h"
#import "XTStationRef.h"
#import "AppDelegate.h"
#import "XTStationInfoViewController.h"

@interface XTStationListTableCellView : NSTableCellView

@property (strong) IBOutlet XTStationListWindowController *stationController;
@end

@interface XTStationListWindowController ()
@property (strong) IBOutlet NSPopover *stationPopover;    // popover to display station info
@property (strong) IBOutlet XTStationInfoViewController *stationInfoViewController;
- (void)showInfoForStation:(XTStationRef *)ref onButton:(NSButton *)button;

@end

@implementation XTStationListTableCellView


- (IBAction)stationInfoAction:(id)sender
{
    // user clicked the Info button
    //
    if (![sender isKindOfClass:[NSButton class]]) {
        NSBeep();
        return;
    }
    NSButton *button = (NSButton *)sender;
    XTStationListWindowController *wc = button.window.windowController;
    [wc showInfoForStation:self.objectValue onButton:button];
}

- (IBAction)tideInfoAction:(id)sender
{
    if (![sender isKindOfClass:[NSSegmentedControl class]]) {
        NSBeep();
        return;
    }
    NSSegmentedControl *button = (NSSegmentedControl *)sender;
    XTStationRef *ref = (XTStationRef *)self.objectValue;
    if ([button selectedSegment] == 0) {
        [(AppDelegate *)[NSApp delegate] showTideGraphForStation:ref];
    } else {
        [(AppDelegate *)[NSApp delegate] showTideDataForStation:ref];
    }
}

@end



@implementation XTStationListWindowController

- (instancetype)init
{
    return [super initWithWindowNibName:@"XTStationListWindowController"];
}

- (void)showInfoForStation:(XTStationRef *)ref onButton:(NSButton *)button
{
    if ([self.stationPopover isShown]) {
        [self.stationPopover close];
        return;
    }

    // configure the preferred position of the popover
    NSRectEdge prefEdge = NSRectEdgeMaxY;

    self.stationInfoViewController.representedObject = ref;
    [self.stationInfoViewController reloadData];
    [self.stationPopover showRelativeToRect:[button bounds] ofView:button preferredEdge:prefEdge];
}

- (IBAction)closePopover:(id)sender
{
    [self.stationPopover close];
}

@end
