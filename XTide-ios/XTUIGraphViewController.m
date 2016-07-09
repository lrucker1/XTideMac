//
//  XTUIGraphViewController.m
//  XTide
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTUIGraphViewController.h"
#import "XTUIGraphView.h"

static XTUIGraphViewController *selfContext;

@interface XTUIGraphViewController ()

@property XTStation *station;

@end

@implementation XTUIGraphViewController

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    
    return UIInterfaceOrientationMaskAll;
}

- (void)updateStation: (XTStation *)station
{
    self.station = station;
    XTUIGraphView *gv = self.graphView;
    gv.station = station;
    [gv setNeedsDisplay];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    XTUIGraphView *gv = self.graphView;
    gv.graphdate = [NSDate date];
    gv.hasCustomDate = NO;
    gv.station = self.station;
    [gv setContentMode:UIViewContentModeRedraw];
    [self.favoriteButton setImage:[UIImage imageNamed:@"FavoriteStarOpen"] forState:UIControlStateNormal];
    [self.favoriteButton setImage:[UIImage imageNamed:@"FavoriteStarFilled"] forState:UIControlStateSelected];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)reloadContent
{
    [self.graphView returnToNow];
}

- (IBAction)toggleFavorite
{
    self.favoriteButton.selected = !self.favoriteButton.selected;
    if (self.favoriteButton.selected) {
//        [[XTStationIndex sharedStationIndex] addFavorite:annotation];
    }
    else {
//        [[XTStationIndex sharedStationIndex] removeFavorite:annotation];
    }
}

@end
