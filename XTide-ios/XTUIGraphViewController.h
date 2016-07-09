//
//  XTUIGraphViewController.h
//  XTide
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XTUITideTabBarController.h"

@class XTStation;
@class XTUIGraphView;

@interface XTUIGraphViewController : UIViewController <XTUITideView>

@property (nonatomic, strong) IBOutlet UIButton *listButton;
@property (nonatomic, strong) IBOutlet XTUIGraphView *graphView;

- (void)updateStation: (XTStation *)station;

@end
