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

@interface XTUITideEventsTableViewController ()

@property XTStation *station;
@property XTTideEventsOrganizer *organizer;

@end

@implementation XTUITideEventsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
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

- (NSDate *)startDate
{
    return [NSDate date];
}

- (NSDate *)endDate
{
    // Show a week.
    return [NSDate dateWithTimeIntervalSinceNow:60 * 60 * 24 * 7];
}

- (IBAction)reloadContent
{
	XTTideEventsOrganizer *tempOrganizer =
      [[XTTideEventsOrganizer alloc] init];
    [self.station predictTideEventsStart:[[self startDate] dateByAddingTimeInterval:(-60)]
                                     end:[[self endDate] dateByAddingTimeInterval:(60)]
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
    
    return cell;
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
