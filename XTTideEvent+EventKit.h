//
//  XTTideEvent+EventKit.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/19/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <EventKit/EventKit.h>
#import "XTTideEvent.h"

@class XTStation;

@interface XTTideEvent (EventKit)

- (BOOL)matchesCalendarEvent:(EKEvent *)event
                  forStation:(XTStation*)station;

- (EKEvent *)calendarEventWithEventStore:(EKEventStore *)eventStore
                              forStation:(XTStation*)station;

@end
