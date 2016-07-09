//
//  XTUIGraphViewController.h
//  XTide
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>

@class XTStation;

@interface XTUIGraphViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIButton *listButton;

- (void)updateStation: (XTStation *)station;

@end
