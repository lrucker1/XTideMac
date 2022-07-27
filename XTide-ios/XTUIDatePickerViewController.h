//
//  XTUIDatePickerViewController.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/26/22.
//  Copyright © 2022 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XTUIGraphViewController.h"
#import "XTUITideTabBarController.h"

NS_ASSUME_NONNULL_BEGIN

@interface XTUIDatePickerViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIDatePicker *dateFromPicker;
@property (nonatomic, weak, readwrite) XTUITideTabBarController *tideViewController;

@end

NS_ASSUME_NONNULL_END
