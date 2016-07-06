//
//  XTWMapInterfaceController.h
//  XTide
//
//  Created by Lee Ann Rucker on 7/5/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>

@interface XTWMapInterfaceController : WKInterfaceController

@property IBOutlet WKInterfaceMap *map;
@property IBOutlet WKInterfaceLabel *mapLabel;

@end
