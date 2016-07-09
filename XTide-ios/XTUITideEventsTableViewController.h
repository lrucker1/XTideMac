//
//  XTUITideEventsTableViewController.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/9/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XTUITideTabBarController.h"

@class XTStation;

@interface XTUITideEventsTableViewController : UITableViewController <XTUITideView>

- (void)updateStation:(XTStation *)station;

@end
