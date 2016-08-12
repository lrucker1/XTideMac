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

@interface XTUITideTabBarController ()

@property UIButton *favoriteButton;
@property UIBarButtonItem *favoriteBarButton;
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
    [self.favoriteButton addTarget:self action:@selector(toggleFavorite) forControlEvents:UIControlEventTouchUpInside];
    if (self.station) {
        self.favoriteButton.selected = [[XTStationIndex sharedStationIndex] isFavoriteStation:self.station];
    }

    self.favoriteBarButton = [[UIBarButtonItem alloc] init];
    [self.favoriteBarButton setCustomView:self.favoriteButton];
    self.navigationItem.rightBarButtonItem = self.favoriteBarButton;
    self.delegate = self;
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

@end
