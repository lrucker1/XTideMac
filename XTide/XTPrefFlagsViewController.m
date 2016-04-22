//
//  XTPrefFlagsViewController.m
//  XTide
//
//  Created by Lee Ann Rucker on 4/21/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTPrefFlagsViewController.h"
#import "XTSettings.h"

static XTPrefFlagsViewController *selfContext;

@interface XTPrefFlagsViewController ()

@property BOOL isObserving;
@end

@implementation XTPrefFlagsViewController

- (void)awakeFromNib
{
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:XTide_eventmask
                                               options:NSKeyValueObservingOptionNew
                                               context:&selfContext];
    self.isObserving = YES;
    [self parseEventMask];
}


- (void)dealloc
{
    if (self.isObserving) {
        [[NSUserDefaults standardUserDefaults] removeObserver:self
                                                   forKeyPath:XTide_eventmask
                                                      context:&selfContext];
    }
}

/*
 * Events to suppress
 * (p = phase of moon, S = sunrise, s = sunset, M = moonrise, m = moonset)
 * or x to suppress none.
 * E.g, to suppress all sun and moon events, set eventmask to the value pSsMm.
 *
 * The preference pane reverses the logic, and has checkboxes
 * that say "Display ____ event"
 */

- (void)parseEventMask
{
    NSString *eventMask = [[NSUserDefaults standardUserDefaults] stringForKey:XTide_eventmask];
    self.phaseOfMoon = [eventMask rangeOfString:@"p"].location == NSNotFound;
    self.sunrise = [eventMask rangeOfString:@"S"].location == NSNotFound;
    self.sunset = [eventMask rangeOfString:@"s"].location == NSNotFound;
    self.moonrise = [eventMask rangeOfString:@"M"].location == NSNotFound;
    self.moonset = [eventMask rangeOfString:@"m"].location == NSNotFound;
}


- (IBAction)updateEventMask:(id)sender
{
    char mask[6];
    int index = 0;
    mask[0] = 'x';
    mask[1] = '\0';

    if (!self.phaseOfMoon) mask[index++] = 'p';
    if (!self.sunrise) mask[index++] = 'S';
    if (!self.sunset) mask[index++] = 's';
    if (!self.moonrise) mask[index++] = 'M';
    if (!self.moonset) mask[index++] = 'm';
    mask[index] = '\0';
    NSString *pref = [NSString stringWithUTF8String:mask];
    XTSettings_SetShortcutToValue("em", pref);
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context != &selfContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    } else if ([keyPath isEqualToString:XTide_eventmask]) {
        [self parseEventMask];
    } else {
        NSAssert(0, @"Unhandled key %@ in %@", keyPath, [self className]);
    }
}

@end
