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

- (libxtide::TideEventsOrganizer &)adaptedOrganizer;

- (NSInteger)count;
- (XTTideEvent *)objectAtIndex: (NSInteger)i;
- (void)reloadData;

@end
