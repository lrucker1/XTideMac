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

// WARNING! We may have no version if we've tried to get the info before the file has been vetted by Sandbox.
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
    NSString *label = data[versionKey];
    if ([label length] == 0) {
        // Maybe we've gotten past the sandbox?
        label = [[XTStationIndex sharedStationIndex] versionFromHarmonicsFile:[data[urlKey] path]];
        if ([label length] == 0) {
            // Nope. Fallback time.
            label = [data[urlKey] lastPathComponent];
        }
    }
    cell.textLabel.text = label;
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
            [array addObject:url];
        }
    }
    [(AppDelegate *)[[UIApplication sharedApplication] delegate] addHarmonicsFiles:array];
}

- (IBAction)openImportDocumentPicker:(id)sender {
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"xtide.tcd"]
                                                                                                            inMode:UIDocumentPickerModeImport];
    documentPicker.delegate = self;
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:documentPicker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    // Give it time to be Sandbox-approved. Who knows, it could happen.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.harmonicsFileArray addObjectsFromArray:[self objectsForURLs:urls]];
        [self.tableView reloadData];
        [self applyHarmonics:nil];
    });
}
@end
