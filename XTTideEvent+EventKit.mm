//
//  XTTideEvent+EventKit.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/19/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTTideEvent+EventKit.h"
#import "XTStation.h"
#import "XTStationRef.h"

@implementation XTTideEvent (EventKit)


- (BOOL)matchesCalendarEvent:(EKEvent *)event
                  forStation:(XTStation*)station
{
    if (![event.structuredLocation.title isEqualToString:station.name]) {
        return NO;
    }
    if (![event.title isEqualToString:[self longDescription]]) {
        return NO;
    }
    // If the user changed the date to not span the tideEvent, then that's their problem.
    NSDate *date = [self date];
    if (   [date compare:event.startDate] == NSOrderedAscending
        || [date compare:event.endDate] == NSOrderedDescending) {
        return NO;
    }
    return YES;
}

- (EKEvent *)calendarEventWithEventStore:(EKEventStore *)eventStore
                              forStation:(XTStation*)station
{
    // Make a new event.
    EKEvent *event = [EKEvent eventWithEventStore:eventStore];
    EKStructuredLocation *loc = [[EKStructuredLocation alloc] init];
    loc.title = station.name;
    loc.geoLocation = station.stationRef.location;
    event.title = [self longDescription];
    event.structuredLocation = loc;
    NSDate *date = [self date];
    // Add a range because these aren't instant and also so the lookup code
    // doesn't have to worry about how precise the times are.
    event.startDate = [date dateByAddingTimeInterval:-5 * 60];
    event.endDate = [date dateByAddingTimeInterval:15 * 60];
    return event;
}

@end
