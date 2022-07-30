//
//  XTUIStationTableViewController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/1/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTUIStationTableViewController.h"

#import "AppDelegate.h"
#import "XTStationIndex.h"
#import "XTStationRef.h"
#import "XTUIGraphViewController.h"
#import "UIKitAdditions.h"
#import "XTUITideTabBarController.h"

@interface XTUIStationTableViewController ()

@property (nonatomic, strong) UISearchController *searchController;
@property (retain) id mapsLoadObserver;
@property (copy) NSArray *stationRefArray;
@property (copy) NSArray *filteredArray;

@end


@implementation XTUIStationTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Uses the AppDelegate stationIndexes, so it does not need to listen for reloads.
    [self loadStations];
    if (!self.stationRefArray) {
        self.mapsLoadObserver = [[NSNotificationCenter defaultCenter] addObserverForName:XStationIndexDidLoadNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
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
    self.searchController.obscuresBackgroundDuringPresentation = NO; // default is YES
    self.searchController.searchBar.delegate = self; // so we can monitor text changes + others
    
    // Search is now just presenting a view controller. As such, normal view controller
    // presentation semantics apply. Namely that presentation will walk up the view controller
    // hierarchy until it finds the root view controller or one that defines a presentation context.
    //
    self.definesPresentationContext = YES;  // know where you want UISearchController to be displayed
}

-(void)dealloc
{
    // http://stackoverflow.com/questions/32282401/attempting-to-load-the-view-of-a-view-controller-while-it-is-deallocating-uis
    [_searchController.view removeFromSuperview];
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
    NSMutableArray *suggestions = [NSMutableArray array];
    NSArray *stationRefArray = self.stationRefArray;

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
    cell.imageView.image = ref.stationDot;
 
    UIButton *favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [favoriteButton setFrame:CGRectMake(0, 0, 32, 32)];
    [favoriteButton setImage:[UIImage imageNamed:@"FavoriteStarOpen"] forState:UIControlStateNormal];
    [favoriteButton setImage:[UIImage imageNamed:@"FavoriteStarFilled"] forState:UIControlStateSelected];
    [favoriteButton addTarget:self action:@selector(checkButtonTapped:event:) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryView = favoriteButton;
   
    return cell;
}

- (void)checkButtonTapped:(id)sender event:(id)event
{
    NSSet *touches = [event allTouches];
    UITouch *touch = [touches anyObject];
    CGPoint currentTouchPosition = [touch locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:currentTouchPosition];
    if (indexPath != nil){
        UIButton *button = (UIButton *)sender;
        button.selected = !button.selected;
        XTStationRef *ref = [self.filteredArray objectAtIndex:[indexPath row]];
        if (button.selected) {
            [[XTStationIndex sharedStationIndex] addFavorite:ref];
        }
        else {
            [[XTStationIndex sharedStationIndex] removeFavorite:ref];
        }
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    XTStationRef *ref = [self.filteredArray objectAtIndex:[indexPath row]];
    UIViewController<XTUITideView> *vc = [segue destinationViewController];
    if ([vc conformsToProtocol:@protocol(XTUITideView)]) {
        [vc updateStation:[ref loadStation]];
    }
}

@end
