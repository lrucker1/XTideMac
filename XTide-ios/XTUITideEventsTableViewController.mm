//
//  XTUITideEventsTableViewController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/9/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTUITideEventsTableViewController.h"
#import "XTTideEventsOrganizer.h"
#import "XTTideEvent.h"
#import "XTTideEvent+EventKit.h"
#import "XTStation.h"
#import "XTStationRef.h"


@interface XTUITideEventsTableViewController ()

@property XTStation *station;
@property XTTideEventsOrganizer *organizer;
@property (nonatomic, strong) EKEventStore *eventStore;
@property (nonatomic, strong) EKCalendar *defaultCalendar;
@property NSDate *startDate;
@property NSDate *endDate;

@end

@implementation XTUITideEventsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self reloadContent];
	self.eventStore = [[EKEventStore alloc] init];

    // Initialize Refresh Control
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(reloadContent:) forControlEvents:UIControlEventValueChanged];
    [self setRefreshControl:refreshControl];

    self.clearsSelectionOnViewWillAppear = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    self.organizer = nil;
    [self.tableView reloadData];
}

- (void)updateStation:(XTStation *)station
{
    self.station = station;
    [self reloadContent];
}

- (IBAction)reloadContent:(id)sender
{
    [self reloadContent];
    [(UIRefreshControl *)sender endRefreshing];
}

- (IBAction)reloadContent
{
    if (!self.station) {
        return;
    }
	XTTideEventsOrganizer *tempOrganizer =
      [[XTTideEventsOrganizer alloc] init];
    self.startDate = [[NSDate date] dateByAddingTimeInterval:-60 * 60];
    self.endDate = [NSDate dateWithTimeIntervalSinceNow:60 * 60 * 24 * 7];
    [self.station predictTideEventsStart:self.startDate
                                     end:self.endDate
                               organizer:tempOrganizer
                                  filter:libxtide::Station::noFilter];
	self.organizer = tempOrganizer;
	[self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.organizer.numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.organizer numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TideEvent" forIndexPath:indexPath];

    XTTideEvent *tideEvent = [self.organizer objectAtIndexPath:indexPath];
    cell.textLabel.text = tideEvent.longDescriptionAndLevel;
    cell.detailTextLabel.text = [tideEvent dateForStation:self.station];
    NSString *imgString = tideEvent.eventTypeString;
    if ([imgString length] == 0) {
        imgString = @"blank";
    }
    cell.imageView.image = [UIImage imageNamed:imgString];
 
    UIButton *editCal = [UIButton buttonWithType:UIButtonTypeCustom];
    [editCal setFrame:CGRectMake(0, 0, 32, 32)];
    [editCal setImage:[UIImage imageNamed:@"editCalendar"] forState:UIControlStateNormal];
    [editCal addTarget:self action:@selector(checkButtonTapped:event:) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryView = editCal;
   
    return cell;
}

- (void)checkButtonTapped:(id)sender event:(id)event
{
    NSSet *touches = [event allTouches];
    UITouch *touch = [touches anyObject];
    CGPoint currentTouchPosition = [touch locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:currentTouchPosition];
    if (indexPath != nil){
        XTTideEvent *tideEvent = [self.organizer objectAtIndexPath:indexPath];
        [self checkEventStoreAccessForCalendar:tideEvent];
    }
}

- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    NSArray *events = self.organizer.sectionObjects;
    NSMutableArray *strings = [NSMutableArray array];
    for (XTTideEvent *event in events) {
        [strings addObject:[event timeForStation:self.station]];
    }
    return strings;
}

#pragma mark - Calendar

// Check the authorization status of our application for Calendar 
-(void)checkEventStoreAccessForCalendar:(XTTideEvent *)tideEvent
{
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];    
 
    switch (status)
    {
        // Update our UI if the user has granted access to their Calendar
        case EKAuthorizationStatusAuthorized:
            [self showCalendarEntryForEvent:tideEvent];
            break;
        // Prompt the user for access to Calendar if there is no definitive answer
        case EKAuthorizationStatusNotDetermined:
            [self requestCalendarAccess:tideEvent];
            break;
        // Display a message if the user has denied or restricted access to Calendar
        case EKAuthorizationStatusDenied:
        case EKAuthorizationStatusRestricted:
        {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Privacy Warning", @"No calendar error")
                                                                           message:NSLocalizedString(@"Permission was not granted for Calendar", @"No calendar message")
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {}];
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
            break;
        default:
            break;
    }
}


// Prompt the user for access to their Calendar
-(void)requestCalendarAccess:(XTTideEvent *)tideEvent
{
    [self.eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error)
    {
         if (granted) {
             XTUITideEventsTableViewController * __weak weakSelf = self;
             // Let's ensure that our code will be executed from the main queue
             dispatch_async(dispatch_get_main_queue(), ^{
                // The user has granted access to their Calendar.
                [weakSelf showCalendarEntryForEvent:tideEvent];
             });
         }
     }];
}

// Fetch all events happening during our current organizer span
- (NSArray *)fetchEvents
{
	// Search all calendars.
	NSArray *calendars = [self.eventStore calendarsForEntityType:EKEntityTypeReminder];
  
    // Create the predicate
	NSPredicate *predicate = [self.eventStore predicateForEventsWithStartDate:self.startDate
                                                                      endDate:self.endDate
                                                                    calendars:calendars];
	
	// Fetch all events that match the predicate
	return [self.eventStore eventsMatchingPredicate:predicate];
}

- (EKEvent *)calendarEntryForEvent:(XTTideEvent *)tideEvent
{
    NSArray *events = [self fetchEvents];
    for (EKEvent *event in events) {
        if ([tideEvent matchesCalendarEvent:event forStation:self.station]) {
            return event;
        }
    }

    // Make sure we have the default calendar associated with our event store
    self.defaultCalendar = self.eventStore.defaultCalendarForNewEvents;

    // Make a new event.
    return [tideEvent calendarEventWithEventStore:self.eventStore forStation:self.station];
}

// This method is called when the user has granted permission to Calendar
-(void)showCalendarEntryForEvent:(XTTideEvent *)tideEvent
{
	EKEventEditViewController *controller = [[EKEventEditViewController alloc] init];
    controller.editViewDelegate = self;
	controller.eventStore = self.eventStore;
    controller.event = [self calendarEntryForEvent:tideEvent];
    [self presentViewController:controller animated:YES completion:nil];
}

#pragma mark EKEventEditViewDelegate

// Overriding EKEventEditViewDelegate method to update event store according to user actions.
- (void)eventEditViewController:(EKEventEditViewController *)controller 
		  didCompleteWithAction:(EKEventEditViewAction)action
{
//    XTUITideEventsTableViewController * __weak weakSelf = self;
	// Dismiss the modal view controller
    [self dismissViewControllerAnimated:YES completion:^
     {
         if (action != EKEventEditViewActionCanceled)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                // This is where we'd update icons.
             });
         }
     }];
}


// Set the calendar edited by EKEventEditViewController to our chosen calendar - the default calendar.
- (EKCalendar *)eventEditViewControllerDefaultCalendarForNewEvents:(EKEventEditViewController *)controller
{
	return self.defaultCalendar;
}

@end
