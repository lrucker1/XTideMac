//
//  XTUITideTabBarController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/9/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTUITideTabBarController.h"
#import "XTStation.h"
#import "XTStationIndex.h"
#import "XTUIDatePickerViewController.h"

@interface XTUITideTabBarController ()

@property UIButton *favoriteButton;
@property UIButton *showDatePickerButton;
@property UIBarButtonItem *favoriteBarButton;
@property UIBarButtonItem *showDatePickerBarButton;
@property UIViewController *datePicker;
@property XTStation *station;

@end

@implementation XTUITideTabBarController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Add a "Favorite" button
    self.favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.favoriteButton.frame = CGRectMake(0, 0, 24, 24);
    self.favoriteButton.accessibilityLabel = NSLocalizedString(@"Favorite", @"Favorite button");
    [self.favoriteButton setImage:[UIImage imageNamed:@"FavoriteStarOpen"] forState:UIControlStateNormal];
    [self.favoriteButton setImage:[UIImage imageNamed:@"FavoriteStarFilled"] forState:UIControlStateSelected];
    [self.favoriteButton setContentMode:UIViewContentModeScaleToFill];
    self.favoriteButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.favoriteButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    [self.favoriteButton addTarget:self action:@selector(toggleFavorite) forControlEvents:UIControlEventTouchUpInside];
    if (self.station) {
        self.favoriteButton.selected = [[XTStationIndex sharedStationIndex] isFavoriteStation:self.station];
    }
    // Add a DatePickerPopover Button
    self.showDatePickerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.showDatePickerButton.frame = CGRectMake(0, 0, 24, 24);
    self.showDatePickerButton.accessibilityLabel = NSLocalizedString(@"Choose Date", @"Date Picker button");
    [self.showDatePickerButton setContentMode:UIViewContentModeScaleToFill];
    self.showDatePickerButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.showDatePickerButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    [self.showDatePickerButton setImage:[UIImage systemImageNamed:@"calendar.badge.clock"] forState:UIControlStateNormal];
    [self.showDatePickerButton addTarget:self action:@selector(showDatePicker) forControlEvents:UIControlEventTouchUpInside];

    self.favoriteBarButton = [[UIBarButtonItem alloc] init];
    [self.favoriteBarButton setCustomView:self.favoriteButton];
    self.showDatePickerBarButton = [[UIBarButtonItem alloc] init];
    [self.showDatePickerBarButton setCustomView:self.showDatePickerButton];
    // favorite is on the outside edge.
    self.navigationItem.rightBarButtonItems = @[self.favoriteBarButton, self.showDatePickerBarButton];
    self.delegate = self;
    UIViewController<XTUITideView> *vc = self.selectedViewController;
    if ([vc conformsToProtocol:@protocol(XTUITideView)]) {
        self.showDatePickerButton.enabled = [vc respondsToSelector:@selector(updateDate:)];
    }
}

- (void)updateStation:(XTStation *)station
{
    for (UIViewController<XTUITideView> *vc in self.viewControllers) {
        if ([vc conformsToProtocol:@protocol(XTUITideView)]) {
            [vc updateStation:station];
        }
    }
    self.station = station;
    self.favoriteButton.selected = [[XTStationIndex sharedStationIndex] isFavoriteStation:station];
}


- (void)updateDate:(NSDate *)date
{
    UIViewController<XTUITideView> *vc = self.selectedViewController;
    if ([vc conformsToProtocol:@protocol(XTUITideView)] && [vc respondsToSelector:@selector(updateDate:)]) {
        [vc updateDate:date];
    }
}

- (IBAction)showDatePicker {
    UIViewController<XTUITideView> *vc = self.selectedViewController;
    if ([vc conformsToProtocol:@protocol(XTUITideView)] && [vc respondsToSelector:@selector(updateDate:)]) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"TideViewsStoryboard" bundle:nil];
        XTUIDatePickerViewController *datePicker = [storyboard instantiateViewControllerWithIdentifier:@"DatePicker"];
        datePicker.modalPresentationStyle = UIModalPresentationPopover;
        datePicker.popoverPresentationController.barButtonItem = self.showDatePickerBarButton;
        datePicker.tideViewController = self;
        [self presentViewController:datePicker animated:YES completion:nil];
    }
}

- (void)dismissDatePicker:(UIViewController *)datePicker {
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)toggleFavorite
{
    self.favoriteButton.selected = !self.favoriteButton.selected;
    XTStationRef *ref = self.station.stationRef;
    if (self.favoriteButton.selected) {
        [[XTStationIndex sharedStationIndex] addFavorite:ref];
    }
    else {
        [[XTStationIndex sharedStationIndex] removeFavorite:ref];
    }
}

-(UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationPopover;
}

- (void)tabBarController:(UITabBarController *)tabBarController
 didSelectViewController:(UIViewController *)viewController {
    UIViewController<XTUITideView> *vc = (UIViewController<XTUITideView> *)viewController;
    if ([vc conformsToProtocol:@protocol(XTUITideView)]) {
        self.showDatePickerButton.enabled = [vc respondsToSelector:@selector(updateDate:)];
    }
}
@end
