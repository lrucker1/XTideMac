//
//  XTUITideEventsTableViewController.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/9/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <EventKit/EventKit.h>
#import <EventKitUI/EventKitUI.h>
#import "XTUITideTabBarController.h"

@class XTStation;

@interface XTUITideEventsTableViewController : UITableViewController <XTUITideView, EKEventEditViewDelegate>

- (void)updateStation:(XTStation *)station;

@end
