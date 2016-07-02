//
//  XTUIGraphViewController.m
//  XTide
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTUIGraphViewController.h"
#import "XTUIGraphView.h"

@interface XTUIGraphViewController ()

@end

@implementation XTUIGraphViewController



- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    
    return UIInterfaceOrientationMaskAll;
}


- (void)updateStation: (XTStation *)station
{
    XTUIGraphView *gv = (XTUIGraphView *)self.view;
    gv.station = station;
    [gv setNeedsDisplay];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    XTUIGraphView *gv = (XTUIGraphView *)self.view;
    gv.graphdate = [NSDate date];
    [gv setContentMode:UIViewContentModeRedraw];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
