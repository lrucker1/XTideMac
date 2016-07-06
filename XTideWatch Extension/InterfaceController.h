//
//  InterfaceController.h
//  XTideWatch Extension
//
//  Created by Lee Ann Rucker on 7/2/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <WatchKit/WatchKit.h>
#import <Foundation/Foundation.h>

extern NSString * const XTWatchAppContextNotification;

@import WatchConnectivity;

@interface InterfaceController : WKInterfaceController <WCSessionDelegate>

@property IBOutlet WKInterfaceGroup *group;

- (IBAction)showTidesOnPhone;

@end
