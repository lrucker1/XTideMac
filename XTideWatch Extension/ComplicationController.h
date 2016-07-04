//
//  ComplicationController.h
//  XTideWatch Extension
//
//  Created by Lee Ann Rucker on 7/2/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <ClockKit/ClockKit.h>
@import WatchConnectivity;

@interface ComplicationController : NSObject <CLKComplicationDataSource, WCSessionDelegate>

@end
