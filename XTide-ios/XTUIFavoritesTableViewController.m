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
#import "XTUIGraphViewController.h"
#import "UIKitAdditions.h"

@interface XTUIFavoritesTableViewController ()

@property (copy) NSArray *favoritesArray;

@end

@implementation XTUIFavoritesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.favoritesArray = [[XTStationIndex sharedStationIndex] favoriteStationRefs];
    
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    XTStationRef *ref = [self.favoritesArray objectAtIndex:[indexPath row]];
    if (ref) {
        XTUIGraphViewController *viewController = [[XTUIGraphViewController alloc] init];
        viewController.edgesForExtendedLayout = UIRectEdgeNone;
        [viewController updateStation:[ref loadStation]];
        
        [self.navigationController pushViewController:viewController animated:YES];
    }
}



// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        XTStationRef *ref = [self.favoritesArray objectAtIndex:[indexPath row]];
        // Delete the row from the data source
        [[XTStationIndex sharedStationIndex] removeFavorite:ref];
        self.favoritesArray = [[XTStationIndex sharedStationIndex] favoriteStationRefs];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

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
