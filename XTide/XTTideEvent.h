//
//  XTTideEvent.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "libxtide.hh"
#import "TideEvent.hh"

@class XTStation;

@interface XTTideEvent : NSObject
{
   libxtide::TideEvent *mTideEvent;
	NSDate *eventDate;
}

- (id)initWithTideEvent:(libxtide::TideEvent *)aTideEvent;
- (id)initWithDate:(NSDate *)date;

- (libxtide::TideEvent *)adaptedTideEvent;

- (NSDate *)date;
- (NSString *)longDescriptionAndLevel;
- (NSString *)longDescription;
- (NSString *)displayLevel;
- (NSDictionary *)eventDictionary;
- (NSString *)eventTypeString;
- (NSString *)timeForStation: (XTStation *)station;

- (libxtide::TideEvent::EventType)eventType;
- (BOOL)isDateEvent;

+ (NSString*)descriptionListHeadForm:(char)form
                                mode:(char)mode
                             station:(XTStation*)station;

+ (NSString*)descriptionListTailForm:(char)form
                                mode:(char)mode
                             station:(XTStation*)station;

- (NSString*)descriptionWithForm:(char)form
                            mode:(char)mode
                         station:(XTStation*)station;

@end
