//
//  InterfaceController.m
//  WatchTide WatchKit Extension
//
//  Created by Lee Ann Rucker on 8/4/22.
//

#import "InterfaceController.h"
#import "XTSessionDelegate.h"
#import "NSDate+NSDate_XTWAdditions.h"

@interface InterfaceController ()

@property (strong) NSTimer *timer;
@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveUserInfo:)
                                                 name:XTSessionUserInfoNotification
                                               object:nil];
    [self setTitle:NSLocalizedString(@"Tides", @"Title: Tides page")];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:XTSessionUserInfoNotification
                                                  object:nil];
}


- (void)didReceiveUserInfo:(NSNotification *)note
{
    [self requestImage];
}

- (void)willActivate {
    [self requestImage];
    [self startTimer];
}

// The AX string will be local time even though the image shows station time.
- (NSString *)axDescriptionFromInfo:(NSDictionary *)info
{
    NSArray *events = [info objectForKey:@"clockEvents"];
    NSMutableArray *axStrings = [NSMutableArray array];
    [axStrings addObject:@"Tide Chart Graph"];
    for (NSDictionary *event in events) {
        NSString *desc = [event objectForKey:@"desc"];
        NSDate *date = [event objectForKey:@"date"];
        NSString *dateString = [date localizedTimeAndRelativeDateString];
        [axStrings addObject:[NSString stringWithFormat:@"%@ %@", desc, dateString]];
    }
    if ([axStrings count]) {
        return [axStrings componentsJoinedByString:@", "];
    }
    return @"";
}

- (void)requestImage
{
    [[XTSessionDelegate sharedDelegate] requestUpdate];
    // This method is called when watch view controller is about to be visible to user
    self.group.backgroundImage = [[XTSessionDelegate sharedDelegate] image];;
    NSString *axString = [self axDescriptionFromInfo:[[XTSessionDelegate sharedDelegate] info]];
    if (axString) {
        [self.group setAccessibilityLabel:axString];
    }
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [self.timer invalidate];
    self.timer = nil;
}

- (void)startTimer
{
    if (self.timer) {
        return;
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:60
                                                  target:self
                                                selector:@selector(requestImage)
                                                userInfo:nil
                                                 repeats:YES];
    self.timer.tolerance = 10;
}

@end



