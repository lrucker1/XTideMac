//
//  XTUIStationInfoViewController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/9/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTUIStationInfoViewController.h"
#import "XTStation.h"

@interface XTUIStationInfoViewController ()
@property XTStation *station;

@end

@implementation XTUIStationInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.webView loadHTMLString:[self.station stationInfoAsHTML] baseURL:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateStation: (XTStation *)station
{
    self.station = station;
    [self.webView loadHTMLString:[self.station stationInfoAsHTML] baseURL:nil];
}

- (IBAction)reloadContent
{
}

@end
