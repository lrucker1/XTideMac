//
//  XTTideEventsOrganizer.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "libxtide.hh"
#import "TideEventsOrganizer.hh"

@class XTTideEvent;

@interface XTTideEventsOrganizer : NSObject
{
   libxtide::TideEventsOrganizer *mTideEventsOrganizer;
   NSMutableArray *events;
}

@property (readonly) NSInteger numberOfSections;
@property (readonly) NSArray *sectionObjects;

- (libxtide::TideEventsOrganizer &)adaptedOrganizer;
- (libxtide::TideEventsOrganizer *)adaptedOrganizerPtr;


- (NSInteger)count;
- (XTTideEvent *)objectAtIndex: (NSInteger)i;
- (XTTideEvent *)objectAtIndexPath:(NSIndexPath *)indexPath;
- (NSInteger)numberOfRowsInSection:(NSInteger)section;

- (void)reloadData;
- (NSArray *)eventsAsDictionary;
- (NSArray *)standardEvents;

@end
