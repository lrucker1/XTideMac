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
static NSString * const GraphView_hasCustomDate = @"view.hasCustomDate";

@interface XTUIGraphViewController ()

@property UIButton *nowButton;
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
    // Add a "Now" button
    self.nowButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.nowButton.frame = CGRectMake(0, 0, 24, 24);
    [self.nowButton setImage:[UIImage imageNamed:@"ReturnToNow"] forState:UIControlStateNormal];
    [self.nowButton addTarget:self action:@selector(returnToNow) forControlEvents:UIControlEventTouchUpInside];

    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] init];
    [barButton setCustomView:self.nowButton];
    self.navigationItem.rightBarButtonItem = barButton;
    /*
     * TODO: Either watch the time and enable the button when it's more than a minute or
     * so different from the chart, or add "sync to now" behavior like the Mac & Watch.
     */
//    [self addObserver:self forKeyPath:GraphView_hasCustomDate options:0 context:&selfContext];

//    [self.nowButton setEnabled:NO];
}

- (void)dealloc
{
//    [self removeObserver:self forKeyPath:GraphView_hasCustomDate context:&selfContext];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)returnToNow
{
    [self.graphView returnToNow];
}

#pragma mark observation

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context != &selfContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    } else if ([keyPath isEqualToString:GraphView_hasCustomDate]) {
        [self.nowButton setEnabled:self.graphView.hasCustomDate];
    } else {
        NSAssert(0, @"Unhandled key %@ in %@", keyPath, self);
    }
}

@end
