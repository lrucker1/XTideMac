//
//  XTTideEventsOrganizer.mm
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "XTTideEventsOrganizer.h"
#import "XTTideEvent.h"


@interface XTTideEventsOrganizer ()

@property (readwrite, retain) NSArray *events;

@end

@implementation XTTideEventsOrganizer

@synthesize events;

/*
 *-----------------------------------------------------------------------------
 *
 * -[XTTideEventsOrganizer init] --
 *
 *      Initializer.
 *
 * Result:
 *      On success: An instance.
 *      On failure: nil
 *
 * Side effects:
 *      None
 *
 *-----------------------------------------------------------------------------
 */

- (id)init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    mTideEventsOrganizer = new libxtide::TideEventsOrganizer();
    events = [[NSMutableArray alloc] init];
    
    return self;
}


/*
 *-----------------------------------------------------------------------------
 *
 * -[XTTideEventsOrganizer dealloc] --
 *
 *      The destructor.
 *
 * Result:
 *      None
 *
 * Side effects:
 *      Deletes the TideEventsOrganizer instance.
 *
 *-----------------------------------------------------------------------------
 */

- (void)dealloc
{
    // Created and owned by self.
    delete mTideEventsOrganizer;
    events = nil;
    
}

- (libxtide::TideEventsOrganizer &)adaptedOrganizer
{
    return (libxtide::TideEventsOrganizer &)*mTideEventsOrganizer;
}

- (NSInteger)count
{
    return [events count];
}

- (XTTideEvent *)objectAtIndex: (NSInteger)i
{
    return [events objectAtIndex:i];
}

- (void)reloadData
{
    // TideEventsOrganizer sorts by timestamp.
    NSDate *eventDate = nil;
    NSMutableArray *tempEvents = [NSMutableArray array];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    unsigned unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay;
    NSDateComponents *eventComponents;
    NSDateComponents *currentComponents = nil;
    
    for (libxtide::TideEventsIterator it = mTideEventsOrganizer->begin();
         it != mTideEventsOrganizer->end();
         ++it) {
        libxtide::TideEvent &event (it->second);
        XTTideEvent *xtEvent = [[XTTideEvent alloc] initWithTideEvent:&event];
        eventDate = [xtEvent date];
        eventComponents = [calendar components:unitFlags fromDate:eventDate];
        if (![eventComponents isEqual:currentComponents]) {
            NSDate *date = [calendar dateFromComponents:eventComponents];
            XTTideEvent *dateEvent = [[XTTideEvent alloc] initWithDate:date];
            [tempEvents addObject:dateEvent];
            currentComponents = eventComponents;
        }
        [tempEvents addObject:xtEvent];
    }
    self.events = tempEvents;
}

@end
