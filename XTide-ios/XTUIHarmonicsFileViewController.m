//
//  XTUIHarmonicsFileViewController.m
//  XTide-ios
//
//  Created by Lee Ann Rucker on 7/28/22.
//  Copyright © 2022 Lee Ann Rucker. All rights reserved.
//

#import "XTUIHarmonicsFileViewController.h"
#import "XTSettings.h"
#import "XTStation.h"
#import "XTStationIndex.h"
#import "AppDelegate.h"

static NSString *urlKey = @"url";
static NSString *versionKey = @"version";

@interface XTUIHarmonicsFileViewController ()
@property BOOL useStandardHarmonics;
@property NSMutableArray *harmonicsFileArray;

@end

@implementation XTUIHarmonicsFileViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *resourceTCDVersion = [[XTStationIndex sharedStationIndex] resourceTCDVersion];
    if (resourceTCDVersion) {
        self.harmonicsFileLabel.text = resourceTCDVersion;
    }
    // Do any additional setup after loading the view.
    [self readHarmonicsFromPrefs];
}

- (NSMutableArray *)objectsForURLs:(NSArray *)urls
{
    NSMutableArray *array = [NSMutableArray array];
    for (NSURL *url in urls) {
        NSString *version = [[XTStationIndex sharedStationIndex] versionFromHarmonicsFile:[url path]];
        [array addObject:@{urlKey:url,
                          versionKey: version}];
    }
    return array;
}

- (void)readHarmonicsFromPrefs
{
    self.useStandardHarmonics = ![XTSettings_GetUserDefaults() boolForKey:XTide_ignoreResourceHarmonics];
    [self.useResourceFilesSwitch setOn:self.useStandardHarmonics animated:NO];
    NSArray *urls = XTSettings_GetHarmonicsURLsFromPrefs();
    self.harmonicsFileArray = [self objectsForURLs:urls];
}

-(void)tableView:(UITableView*)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath {
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    // If row is deleted, remove it from the list.
    if (editingStyle == UITableViewCellEditingStyleDelete) {
         NSInteger row = [indexPath row];
         [self.harmonicsFileArray removeObjectAtIndex:row];
         [tableView reloadData];
    }
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"harmonicsCell"];
    NSDictionary *data = [self.harmonicsFileArray objectAtIndex:indexPath.row];
    cell.textLabel.text = data[versionKey];
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.harmonicsFileArray count];
}

- (IBAction)toggleUseStandardFiles:(id)sender {
    self.useStandardHarmonics = self.useResourceFilesSwitch.isOn;
}

- (IBAction)applyHarmonics:(id)sender
{
    [XTSettings_GetUserDefaults() setBool:!self.useStandardHarmonics forKey:XTide_ignoreResourceHarmonics];
    NSMutableArray *array = [NSMutableArray array];
    for (NSDictionary *tableData in self.harmonicsFileArray) {
        NSURL *url = [tableData objectForKey:urlKey];
        if (url) {
            NSData *bookmarkData = [url bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark
                                 includingResourceValuesForKeys:nil
                                                  relativeToURL:nil
                                                          error:NULL];
            if (bookmarkData) {
                [array addObject:bookmarkData];
            }
        }
    }
    [XTSettings_GetUserDefaults() setObject:array forKey:XTide_harmonicsFiles];
    [[XTStationIndex sharedStationIndex] reloadHarmonicsFiles];
    [(AppDelegate *)[[UIApplication sharedApplication] delegate] loadStationIndexes];
}

- (IBAction)openImportDocumentPicker:(id)sender {
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"xtide.tcd"]
                                                                                                            inMode:UIDocumentPickerModeOpen];
    documentPicker.delegate = self;
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:documentPicker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [self.harmonicsFileArray addObjectsFromArray:[self objectsForURLs:urls]];
    [self.tableView reloadData];
    [self applyHarmonics:nil];
}
@end
