//
//  XTUIFavoritesTableViewController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/1/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTUIFavoritesTableViewController.h"
#import "XTStationIndex.h"
#import "XTStationRef.h"
#import "XTUITideTabBarController.h"
#import "UIKitAdditions.h"

@interface XTUIFavoritesTableViewController ()

@property (copy) NSArray *favoritesArray;

@end

@implementation XTUIFavoritesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.favoritesArray = [[XTStationIndex sharedStationIndex] favoriteStationRefs];
    if ([self.favoritesArray count] == 0) {
        self.tableView.backgroundView = self.noFavoritesView;
    } else {
        self.tableView.backgroundView = nil;
    }
    
    // Uncomment the following line to preserve selection between presentations.
    self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.favoritesArray count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FavoriteInfo" forIndexPath:indexPath];

    XTStationRef *ref = [self.favoritesArray objectAtIndex:[indexPath row]];
    cell.textLabel.text = ref.title;
    cell.detailTextLabel.text = ref.subtitle;
    cell.imageView.image = ref.stationDot;
    
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support editing the table view. See Apple doc.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        XTStationRef *ref = [self.favoritesArray objectAtIndex:[indexPath row]];
        // Delete the row from the data source, update the array after table animation.
        [[XTStationIndex sharedStationIndex] removeFavorite:ref];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        self.favoritesArray = [[XTStationIndex sharedStationIndex] favoriteStationRefs];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    XTStationRef *ref = [self.favoritesArray objectAtIndex:[indexPath row]];
    UIViewController<XTUITideView> *vc = [segue destinationViewController];
    if ([vc conformsToProtocol:@protocol(XTUITideView)]) {
        [vc updateStation:[ref loadStation]];
    }
}

@end
