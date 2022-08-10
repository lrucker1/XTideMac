//
//  XTWListInterfaceController.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/8/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>

@interface XTWListInterfaceController : WKInterfaceController

@property IBOutlet WKInterfaceLabel *stationLabel;
@property IBOutlet WKInterfaceTable *eventTable;
@property IBOutlet WKInterfaceButton *debugButton;

@end

@interface XTWListTableRowController : NSObject

@property (weak, nonatomic) IBOutlet WKInterfaceLabel *descLabel;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *levelLabel;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *timeLabel;
@property (weak, nonatomic) IBOutlet WKInterfaceImage *image;

@end
