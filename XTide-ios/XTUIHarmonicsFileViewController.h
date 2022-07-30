//
//  XTUIHarmonicsFileViewController.h
//  XTide-ios
//
//  Created by Lee Ann Rucker on 7/28/22.
//  Copyright © 2022 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XTUIHarmonicsFileViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UISwitch *useResourceFilesSwitch;
@property (nonatomic, strong) IBOutlet UILabel *harmonicsFileLabel;

@end

NS_ASSUME_NONNULL_END
