//
//  XTUITideTabBarController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/9/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTUITideTabBarController.h"
#import "XTStation.h"

@implementation XTUITideTabBarController

- (void)updateStation:(XTStation *)station
{
    for (UIViewController<XTUITideView> *vc in self.viewControllers) {
        if ([vc conformsToProtocol:@protocol(XTUITideView)]) {
            [vc updateStation:station];
        }
    }
}

@end
