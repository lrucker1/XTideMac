//
//  TodayViewController.m
//  TideToday
//
//  Created by Lee Ann Rucker on 8/2/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import "libxtide.hh"
#import "XTStationIndex.h"
#import "XTStationRef.h"
#import "XTStation.h"
#import "XTSettings.h"
#import "XTTodayGraphView.h"
#import "XTTideEventsOrganizer.h"
#import "XTTideEvent.h"
#import "XTColorUtils.h"
#import "NSDate+NSDate_XTWAdditions.h"
#import "UIView_UIViewAdditions.h"

@interface TodayViewController () <NCWidgetProviding>

@property (strong) NSArray *stationRefArray;
@property (strong) NSDate *nextEventDate;
@property (strong) NSDate *lastChartDate;

@end

@implementation TodayViewController

+ (void)initialize
{
    static NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.xtide"];
    static CGFloat alpha = 0.4;

    NSDictionary *todayShortcuts =
        @{@"nc" : [ColorForName(@"deepskyblue") colorWithAlphaComponent:alpha],
          @"dc" : [ColorForName(@"skyblue") colorWithAlphaComponent:alpha],
          @"fg" : [ColorForName(@"gray90") colorWithAlphaComponent:alpha],
          @"gs" : @"l",
          @"nl" : @(YES)};

    RegisterUserDefaults(nil);
    libxtide::Global::mutex_init_harmonics();
    XTSettings_SetDefaults(todayShortcuts);
    [[XTStationIndex sharedStationIndex] setFavoritesDefaults:defaults];
}

- (void)updateContents
{
    XTStationRef *favorite = [[XTStationIndex sharedStationIndex] closestFavorite];
    if (!favorite) {
        favorite = [[[XTStationIndex sharedStationIndex] favoriteStationRefs] firstObject];
    }
    
    if (favorite) {
        if (self.graphView.superview == nil) {
            CGSize size = self.preferredContentSize;
            size.height = self.graphView.intrinsicContentSize.height;
            //self.preferredContentSize = size;
            [self.view setSubviewWithPinnedConstraints:self.graphView];
        }
    } else {
        if (self.noFavoritesView.superview == nil) {
            // No, Today Widgets really do not shrink to fit to the preferred autolayout size without help.
            CGSize size = self.preferredContentSize;
            size.height = self.noFavoritesView.intrinsicContentSize.height;
            self.preferredContentSize = size;
            [self.view setSubviewWithPinnedConstraints:self.noFavoritesView];
        }
    }
    if (![favorite isEqual:self.graphView.station]) {
        self.graphView.station = [favorite loadStation];
    }
    NSDate *now = [NSDate date];
    if (!self.lastChartDate || [self.lastChartDate timeIntervalSinceNow] > 120) {
        [self.graphView setNeedsDisplay];
        self.lastChartDate = now;
    }
    if (!self.nextEventDate || [self.nextEventDate compare:now] == NSOrderedAscending) {
        XTTideEvent *event = [self.graphView.station nextMajorEventAfter:now];
        self.label.text = favorite.title;
        self.eventLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ - %@", @"Two strings with a dash, because France"),
                                    [event longDescription],
                                    [[event date] localizedTimeAndRelativeDateString]];
        self.nextEventDate = [event date];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self updateContents];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [self updateContents];
    [super viewWillAppear:animated];
}

- (UIEdgeInsets)widgetMarginInsetsForProposedMarginInsets:(UIEdgeInsets)defaultMarginInsets
{
    // Fill the whole space.
    defaultMarginInsets.left = 0;
    defaultMarginInsets.bottom = 0;
    return defaultMarginInsets;
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData
    [self updateContents];
    completionHandler(NCUpdateResultNewData);
}

- (IBAction)openApp
{
    NSURLComponents *urlComponents = [NSURLComponents new];
    urlComponents.scheme = @"xtide";
    [self.extensionContext openURL:[urlComponents URL] completionHandler:nil];
}

@end
