//
//  XTUITideTabBarController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/9/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTUITideTabBarController.h"
#import "XTStation.h"

@interface XTUITideTabBarController ()
@property UIButton *nowButton;

@end

@implementation XTUITideTabBarController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Add a "Now" button
    self.nowButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.nowButton.frame = CGRectMake(0, 0, 24, 24);
    [self.nowButton setImage:[UIImage imageNamed:@"ReturnToNow"] forState:UIControlStateNormal];
    [self.nowButton addTarget:self action:@selector(reloadContent) forControlEvents:UIControlEventTouchUpInside];

    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] init];
    [barButton setCustomView:self.nowButton];
    self.navigationItem.rightBarButtonItem = barButton;
}

- (void)updateStation:(XTStation *)station
{
    for (UIViewController<XTUITideView> *vc in self.viewControllers) {
        if ([vc conformsToProtocol:@protocol(XTUITideView)]) {
            [vc updateStation:station];
        }
    }
}

- (IBAction)reloadContent
{
    UIViewController<XTUITideView> *vc = self.selectedViewController;
    if ([vc conformsToProtocol:@protocol(XTUITideView)]) {
        [vc reloadContent];
    }
}

@end
