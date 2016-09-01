//
//  XTSavePanelAccessoryController.h
//  XTide
//
//  Created by Lee Ann Rucker on 8/15/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface XTSavePanelAccessoryController : NSViewController

@property (nonatomic, weak) NSSavePanel *savePanel;
@property IBOutlet NSPopUpButton *fileTypesButton;

@end
