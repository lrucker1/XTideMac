//
//  XTUIStationTableViewController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/1/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTUIStationTableViewController.h"

#import "AppDelegate.h"
#import "XTStationRef.h"
#import "XTUIGraphViewController.h"

@interface XTUIStationTableViewController ()

@property (nonatomic, strong) UISearchController *searchController;
@property (retain) id mapsLoadObserver;
@property (copy) NSArray *stationRefArray;
@property (copy) NSArray *filteredArray;

@end


@implementation XTUIStationTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self loadStations];
    if (!self.stationRefArray) {
        self.mapsLoadObserver = [[NSNotificationCenter defaultCenter] addObserverForName:XTideMapsLoadedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            [self loadStations];
        }];
    }

   // Uncomment the following line to preserve selection between presentations.
    self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;

    // SearchResultsController must be nil when showing results in the same view
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    [self.searchController.searchBar sizeToFit];
    self.tableView.tableHeaderView = self.searchController.searchBar;
    
    self.searchController.delegate = self;
    self.searchController.dimsBackgroundDuringPresentation = NO; // default is YES
    self.searchController.searchBar.delegate = self; // so we can monitor text changes + others
    
    // Search is now just presenting a view controller. As such, normal view controller
    // presentation semantics apply. Namely that presentation will walk up the view controller
    // hierarchy until it finds the root view controller or one that defines a presentation context.
    //
    self.definesPresentationContext = YES;  // know where you want UISearchController to be displayed
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)loadStations
{
    if (self.stationRefArray) {
        return;
    }
    self.stationRefArray = [(AppDelegate *)[[UIApplication sharedApplication] delegate] stationRefArray];
}

#pragma mark - Table view data source
- (NSArray *)suggestionsForText:(NSString *)text
{
    // Wait until there are > 3 characters because the search is slow. TODO: dispatch_async?
//    if ([text length] < 3) {
//        return nil;
//    }
    NSMutableArray *suggestions = [NSMutableArray array];
    NSArray *stationRefArray = self.stationRefArray;
//    if (self.searchingSubStations) {
//        stationRefArray = [(AppDelegate *)[NSApp delegate] stationRefArray];
//    } else {
//        stationRefArray = self.refStations;
//    }

    // Stop when we have 30 hits. Any more won't show up on most screens, and it'll speed things up.
    NSInteger count = 0;
    if ([[NSString class] instancesRespondToSelector:@selector(localizedStandardContainsString:)]) {
        for (XTStationRef *station in stationRefArray) {
            if ([station.title localizedStandardContainsString:text]) {
                [suggestions addObject:station];
                count++;
                if (count > 30) {
                    break;
                }
            }
       }
    }
    else {
         for (XTStationRef *station in stationRefArray) {
            NSRange range = [station.title rangeOfString:text options:NSCaseInsensitiveSearch];
            if (range.location != NSNotFound) {
                [suggestions addObject:station];
                count++;
                if (count > 30) {
                    break;
                }
            }
        }
    }
    return suggestions;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    self.filteredArray = [self suggestionsForText:searchController.searchBar.text];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.filteredArray count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StationInfo" forIndexPath:indexPath];
    
    // Configure the cell...
    XTStationRef *ref = [self.filteredArray objectAtIndex:[indexPath row]];
    cell.textLabel.text = ref.title;
    cell.detailTextLabel.text = ref.subtitle;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    XTStationRef *ref = [self.filteredArray objectAtIndex:[indexPath row]];
    XTUIGraphViewController *viewController = [[XTUIGraphViewController alloc] init];
    viewController.edgesForExtendedLayout = UIRectEdgeNone;
    [viewController updateStation:[ref loadStation]];
    
    [self.navigationController pushViewController:viewController animated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
