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
@property (readwrite, retain) NSArray *sections;
@property (readwrite) NSInteger numberOfSections;
@property (readwrite) NSArray *sectionObjects;

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

- (libxtide::TideEventsOrganizer *)adaptedOrganizerPtr
{
    return mTideEventsOrganizer;
}

- (NSInteger)count
{
    return [events count];
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section
{
    if (section < [self.sections count]) {
        return [[self.sections objectAtIndex:section] count];
    }
    return 0;
}

- (XTTideEvent *)objectAtIndex: (NSInteger)i
{
    return [events objectAtIndex:i];
}

- (XTTideEvent *)objectAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath length] != 2) {
        return nil;
    }
    NSInteger section = [indexPath indexAtPosition:0];
    NSInteger item = [indexPath indexAtPosition:1];

    if (section < [self.sections count]) {
        NSArray *items = [self.sections objectAtIndex:section];
        if (item < [items count]) {
            return [items objectAtIndex:item];
        }
    }
    return nil;
}

// Tide events as simple dictionaries for IPC.
- (NSArray *)eventsAsDictionary
{
    NSMutableArray *array = [NSMutableArray array];
    for (XTTideEvent *event in [self standardEvents]) {
        NSDictionary *dict = [event eventDictionary];
        [array addObject:dict];
    }
    return array;
}

/*
 * The cached events are primarily for use in tables, so they add dateEvents.
 *
 * We could generate the array on request, but most organizer clients predict once
 * and then keep reusing it, so adding code to track changes to the C++ contents
 * would be overkill.
 * TODO: Cache both table and standard arrays in this method.
 */
- (void)reloadData
{
    // TideEventsOrganizer sorts by timestamp.
    NSDate *eventDate = nil;
    NSMutableArray *tempEvents = [NSMutableArray array];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    unsigned unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay;
    NSDateComponents *eventComponents;
    NSDateComponents *currentComponents = nil;
    BOOL first = YES;
    NSMutableArray *sectionArray = [NSMutableArray array];
    NSMutableArray *sectionArrays = [NSMutableArray array];
    NSMutableArray *sectionObjects = [NSMutableArray array];
    
    for (libxtide::TideEventsIterator it = mTideEventsOrganizer->begin();
         it != mTideEventsOrganizer->end();
         ++it) {
        libxtide::TideEvent &event (it->second);
        XTTideEvent *xtEvent = [[XTTideEvent alloc] initWithTideEvent:&event];
        eventDate = [xtEvent date];
        eventComponents = [calendar components:unitFlags fromDate:eventDate];
        if (![eventComponents isEqual:currentComponents]) {
            if (!first) {
                [sectionArrays addObject:sectionArray];
                sectionArray = [NSMutableArray array];
            }
            first = NO;
            NSDate *date = [calendar dateFromComponents:eventComponents];
            XTTideEvent *dateEvent = [[XTTideEvent alloc] initWithDate:date];
            [tempEvents addObject:dateEvent];
            [sectionObjects addObject:dateEvent];
            currentComponents = eventComponents;
        }
        [tempEvents addObject:xtEvent];
        [sectionArray addObject:xtEvent];
    }
    if (!first) {
        [sectionArrays addObject:sectionArray];
    }
    self.numberOfSections = [sectionArrays count];
    self.sections = sectionArrays;
    self.events = tempEvents;
    self.sectionObjects = sectionObjects;
}

// Only the predicted events, no date events.
- (NSArray *)standardEvents
{
    // TideEventsOrganizer sorts by timestamp.
    NSMutableArray *tempEvents = [NSMutableArray array];
    
    for (libxtide::TideEventsIterator it = mTideEventsOrganizer->begin();
         it != mTideEventsOrganizer->end();
         ++it) {
        libxtide::TideEvent &event (it->second);
        XTTideEvent *xtEvent = [[XTTideEvent alloc] initWithTideEvent:&event];
        [tempEvents addObject:xtEvent];
    }
    return tempEvents;
}

@end
