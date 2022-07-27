//
//  XTUITideTabBarController.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/9/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>

@class XTStation;

@protocol XTUITideView

- (void)updateStation: (XTStation *)station;
@optional
- (void)updateDate: (NSDate *)date;

@end


@interface XTUITideTabBarController : UITabBarController <XTUITideView, UITabBarControllerDelegate, UIPopoverPresentationControllerDelegate>

@property (nonatomic, strong) IBOutlet UIViewController *datePickerViewController;

- (void)dismissDatePicker:(UIViewController *)datePicker;

@end
