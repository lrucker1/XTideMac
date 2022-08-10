//
//  XTWListInterfaceController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/8/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTWListInterfaceController.h"
#import "XTSessionDelegate.h"
#import "InterfaceController.h"
#import "NSDate+NSDate_XTWAdditions.h"


@interface XTWListInterfaceController ()

@property (strong) NSTimer *timer;
@property (strong) NSDate *fireDate;
@property BOOL isActive;

@end

@implementation XTWListTableRowController
@end

@implementation XTWListInterfaceController

- (void)awakeWithContext:(id)context
{
    [super awakeWithContext:context];

    [self setTitle:NSLocalizedString(@"Min/Max", @"Title: Min/Max page")];
    /*
     * There is a bug which is hard to isolate: if we update the contents between now and
     * willActivate, layout never happens and the contents can't be seen.
     * Provide placeholder info if we don't have contents.
     * It does not seem to be related to which thread we're on.
     * Oh, fun - sometimes it happens anyway, but only on the watch, not the sim.
     */
    NSArray *events = @[@{@"desc":NSLocalizedString(@"High Tide", @"High Tide"),
                          @"level":@" ...",
                          @"type":@"hightide"},
                        @{@"desc":NSLocalizedString(@"Low Tide", @"Low Tide"),
                          @"level":@" ...",
                          @"type":@"lowtide"}];
    [self updateContentsFromInfo:@{@"clockEvents":events}];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveUserInfo:)
                                                 name:XTSessionUserInfoNotification
                                               object:nil];
#if DEBUG
    self.debugButton.hidden = NO;
#endif
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:XTSessionUserInfoNotification
                                                  object:nil];
}

#if DEBUG
- (IBAction)forceUpdate {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:XTSessionUserInfoNotification
        object:self];}
#endif

- (void)didReceiveUserInfo:(NSNotification *)note
{
    [[XTSessionDelegate sharedDelegate] requestUpdate];
    NSDictionary *info = [[XTSessionDelegate sharedDelegate] info];

    if (info) {
        [self updateContentsFromInfo:info];
    }
}

- (BOOL)contentsNeedUpdate:(NSDictionary *)info {
    if (info == nil) {
        return YES;
    }
    NSArray *events = [info objectForKey:@"clockEvents"];

    if ([events count] < 2) {
        return YES;
    }

    __block BOOL result = NO;
    [events enumerateObjectsUsingBlock:^(NSDictionary *event, NSUInteger idx, BOOL *stop) {
        NSDate *date = [event objectForKey:@"date"];
        if (date && ([date compare:[NSDate date]] == NSOrderedAscending)) {
            result = YES;
            *stop = YES;
        }
    }];
    return result;
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    NSDictionary *info = [[XTSessionDelegate sharedDelegate] info];
    if ([self contentsNeedUpdate:info]) {
        [[XTSessionDelegate sharedDelegate] requestUpdate];
        info = [[XTSessionDelegate sharedDelegate] info];
    }
    if (info) {
        [self updateContentsFromInfo:info];
    }
}

- (void)updateContentsFromInfo:(NSDictionary *)info
{
    // Table behaves badly if configured while not active.
    // Set the label so it stops saying "Waiting for iPhone", and then bail.
    NSString *title = [info objectForKey:@"title"];
    BOOL placeholder = title == nil;
    if (!placeholder) {
        self.stationLabel.text = title;
    }

    // Being on the main thread does not help.
    //NSAssert([NSThread isMainThread], @"is on main thread");
    NSArray *events = [info objectForKey:@"clockEvents"];

    if ([events count] < 2) {
        return;
    }
    // If it's the same date and station, it's the same data.
    NSInteger numberOfRows = [self.eventTable numberOfRows];
    if (numberOfRows != 2) {
        // Don't change unnecessarily; it flickers.
        [self.eventTable setNumberOfRows:[events count] withRowType:@"listRow"];
    }

    [events enumerateObjectsUsingBlock:^(NSDictionary *event, NSUInteger idx, BOOL *stop) {
        XTWListTableRowController *row = [self.eventTable rowControllerAtIndex:idx];

        [row.descLabel setText:[event objectForKey:@"desc"]];
        [row.levelLabel setText:[event objectForKey:@"level"]];
        NSDate *date = [event objectForKey:@"date"];
        // For placeholders, show localized "Today" with no time.
        [row.timeLabel setText:date ? [date localizedTimeAndRelativeDateString]
                                    : [[NSDate date] localizedRelativeDateString]];
        [row.image setImage:[UIImage imageNamed:[event objectForKey:@"type"]]];
        UIColor *color = nil;
        if (date && ([date compare:[NSDate date]] == NSOrderedAscending)) {
            // Dim everything when the date is in the past.
            // Doc says setTextColor:nil resets; it doesn't. rdar://27389249
            // Shouldn't happen now that we're doing the computations here.
            color = [UIColor darkGrayColor];
        }
//        [row.descLabel setTextColor:color];
//        [row.levelLabel setTextColor:color];
//        [row.timeLabel setTextColor:color];
        [row.image setTintColor:color];
        
    }];

    [self.eventTable scrollToRowAtIndex:0];
}

@end
