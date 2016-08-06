//
//  TodayViewController.h
//  TideToday
//
//  Created by Lee Ann Rucker on 8/2/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>

@class XTTodayGraphView;

@interface TodayViewController : UIViewController

@property IBOutlet XTTodayGraphView *graphView;
@property IBOutlet UIView *noFavoritesView;
@property IBOutlet UILabel *eventLabel;
@property IBOutlet UILabel *label;

- (IBAction)openApp;

@end
