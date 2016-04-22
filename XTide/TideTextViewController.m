//
//  TideTextViewController.m
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 5/5/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "TideTextViewController.h"
#import "XTSettings.h"
#import "XTStation.h"

static TideTextViewController *selfContext;

static NSArray *prefsKeysOfInterest;
static NSString * const TideData_startDate = @"startDate";
static NSString * const TideData_dayRange = @"dayRange";
static NSString * const TideData_hourRange = @"hourRange";

@interface TideTextViewController ()

@property BOOL customDate;

@end

@implementation TideTextViewController

+ (void)initialize
{
	// If any of these prefs change, recompute the data elements
	prefsKeysOfInterest = [NSArray arrayWithObjects:
			XTide_eventmask, XTide_units, nil];
}

- (void)dealloc
{
    for (NSString *keyPath in prefsKeysOfInterest) {
        [[NSUserDefaults standardUserDefaults] removeObserver:self
                                                   forKeyPath:keyPath
                                                      context:&selfContext];
    }
}


- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    // If it's showing a modified date, save it.
    if (self.customDate) {
        [coder encodeObject:[dateFromPicker dateValue] forKey:TideData_startDate];
    }
    [coder encodeInt:[dayStepper intValue] forKey:TideData_dayRange];
    [coder encodeInt:[hourStepper intValue] forKey:TideData_hourRange];
    [super encodeRestorableStateWithCoder:coder];
}

- (void)restoreStateWithCoder:(NSCoder *)coder
{
    // If it's nil, use current time.
    NSDate *displayDate = [coder decodeObjectForKey:TideData_startDate];
    if (displayDate) {
        [dateFromPicker setDateValue:displayDate];
        self.customDate = YES;
    }
    int dayRange = [coder decodeIntForKey:TideData_dayRange];
    int hourRange = [coder decodeIntForKey:TideData_hourRange];
	[dayStepper setIntValue:dayRange];
	[hourStepper setIntValue:hourRange];
	[dayField takeIntValueFrom:dayStepper];
	[hourField takeIntValueFrom:hourStepper];
	
	[self computeEvents];
	[self updateLabels];
    [super restoreStateWithCoder:coder];
}

- (int)defaultDayRange
{
	return 7;
}

- (void)awakeFromNib
{
	[super awakeFromNib];
//#define DEBUG_PREDICTIONS 1
#ifdef DEBUG_PREDICTIONS
    // @lar - simplify debugging by always starting at same date (Year(2006, 0.5) in C version)
    NSDate *timeFrom = [[NSDate dateWithYear:2006 
			month:1 day:1 hour:0 minute:0 second:0 
			timeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]] addTimeInterval:15768060];
#else
	NSCalendarDate *timeFrom = [NSCalendarDate calendarDate];
	[timeFrom setTimeZone:[station timeZone]];
#endif

    for (NSString *keyPath in prefsKeysOfInterest) {
        [[NSUserDefaults standardUserDefaults] addObserver:self
                                                forKeyPath:keyPath
                                                   options:NSKeyValueObservingOptionNew
                                                   context:&selfContext];
    }
	
	[dayStepper setIntValue:[self defaultDayRange]];
	[hourStepper setIntValue:0];
	[dayField takeIntValueFrom:dayStepper];
	[hourField takeIntValueFrom:hourStepper];
	
	[dateFromPicker setDateValue:timeFrom];
	[self setWindowTitleDate:timeFrom];
	[self computeEvents];
	[self updateLabels];
}

// Events and display
- (void)computeEvents
{
	NSLog(@"subclass must implement");
}


- (IBAction)returnToNow:(id)sender
{
    self.customDate = NO;
	NSCalendarDate *timeFrom = [NSCalendarDate calendarDate];
	[dateFromPicker setDateValue:timeFrom];
	[self setWindowTitleDate:timeFrom];
	[self computeEvents];
	[self updateLabels];
    [self invalidateRestorableState];
}


// Time changed
- (IBAction)updateStartTime:(id)sender
{
	[self computeEvents];
	[self updateLabels];
    [self invalidateRestorableState];
}

// Interval changed via steppers
- (IBAction)timeStepped:(id)sender
{
	[dayField takeIntValueFrom:dayStepper];
	[hourField takeIntValueFrom:hourStepper];
	[self computeEvents];
    [self invalidateRestorableState];
}

// Interval changed via textfields
- (IBAction)timeEntry:(id)sender
{
	[dayStepper takeIntValueFrom:dayField];
	[hourStepper takeIntValueFrom:hourField];
	[self computeEvents];
    [self invalidateRestorableState];
}

- (NSDate *)startDate
{
	return [dateFromPicker dateValue];
}

- (NSDate *)endDate
{
   static int SECONDS_PER_DAY = 24 * 60 * 60;
   return [[self startDate] dateByAddingTimeInterval:
                        [dayStepper intValue] * SECONDS_PER_DAY +
                        [hourStepper intValue] * 60];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context != &selfContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    } else if (([prefsKeysOfInterest containsObject:keyPath])) {
        [self computeEvents];
    } else {
        NSAssert(0, @"Unhandled key %@ in %@", keyPath, [self className]);
    }
}

@end
