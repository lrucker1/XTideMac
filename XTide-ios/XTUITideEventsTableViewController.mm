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

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    //self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateStation:(XTStation *)station
{
    self.station = station;
    [self reloadContent];
}

- (IBAction)reloadContent:(id)sender
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
    [(UIRefreshControl *)sender endRefreshing];
}

- (IBAction)reloadContent
{
    [self reloadContent:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.organizer.numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
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

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


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
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Privacy Warning" message:@"Permission was not granted for Calendar"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
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
- (NSMutableArray *)fetchEvents
{
	// We will only search the default calendar for our events
	NSArray *calendarArray = @[self.defaultCalendar];
  
    // Create the predicate
	NSPredicate *predicate = [self.eventStore predicateForEventsWithStartDate:self.startDate
                                                                      endDate:self.endDate
                                                                    calendars:calendarArray];
	
	// Fetch all events that match the predicate
	NSMutableArray *events = [NSMutableArray arrayWithArray:[self.eventStore eventsMatchingPredicate:predicate]];
    
	return events;
}

- (BOOL)matchTideEvent:(XTTideEvent *)tideEvent
               toEvent:(EKEvent *)event
{
    if (![event.structuredLocation.title isEqualToString:self.station.name]) {
        return NO;
    }
    if (![event.title isEqualToString:[tideEvent longDescription]]) {
        return NO;
    }
    // If the user changed the date to not span the tideEvent, then that's their problem.
    NSDate *date = [tideEvent date];
    if (   [date compare:event.startDate] == NSOrderedAscending
        || [date compare:event.endDate] == NSOrderedDescending) {
        return NO;
    }
    return YES;
}

- (EKEvent *)calendarEntryForEvent:(XTTideEvent *)tideEvent
{
    NSArray *events = [self fetchEvents];
    for (EKEvent *event in events) {
        if ([self matchTideEvent:tideEvent toEvent:event]) {
            return event;
        }
    }

    // Make a new event.
    EKEvent *event = [EKEvent eventWithEventStore:self.eventStore];
    EKStructuredLocation *loc = [[EKStructuredLocation alloc] init];
    loc.title = self.station.name;
    loc.geoLocation = self.station.stationRef.location;
    event.title = [tideEvent longDescription];
    event.structuredLocation = loc;
    NSDate *date = [tideEvent date];
    // Add a range because these aren't instant and also so the lookup code
    // doesn't have to worry about how precise the times are.
    event.startDate = [date dateByAddingTimeInterval:-5 * 60];
    event.endDate = [date dateByAddingTimeInterval:15 * 60];
    return event;
}

// This method is called when the user has granted permission to Calendar
-(void)showCalendarEntryForEvent:(XTTideEvent *)tideEvent
{
    // Make sure we have the default calendar associated with our event store
    self.defaultCalendar = self.eventStore.defaultCalendarForNewEvents;
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
                // This is where we'd update buttons.
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
