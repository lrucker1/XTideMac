//
//  XTUIDatePickerViewController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/26/22.
//  Copyright © 2022 Lee Ann Rucker. All rights reserved.
//

#import "XTUIDatePickerViewController.h"

@implementation XTUIDatePickerViewController


- (IBAction)datePickerValueChanged:(id)sender {
    [self.tideViewController updateDate:self.dateFromPicker.date];
}


- (IBAction)resetToNow {
    [self.dateFromPicker setDate:[NSDate now]];
    [self datePickerValueChanged:self];
}

- (IBAction)dismissDatePicker {
    [self.tideViewController dismissDatePicker:self];
}

@end
