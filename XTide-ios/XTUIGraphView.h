//
//  XTUIGraphView.h
//  XTide
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <UIKit/UIKit.h>

@class XTStation;

typedef struct TouchInfo {
    double x;
    double y;
    NSTimeInterval time; // all relative to the 1970 GMT epoch
} TouchInfo;

@interface XTUIGraphView : UIView
{
    TouchInfo *history;
    NSUInteger historyCount;
    NSUInteger historyHead;

    double motionX;
    double flickThresholdX;
    double flickThresholdY;
    double motionDamp;
    double motionMultiplier;
    double motionMinimum;
    NSTimer *flickTimer;
}

@property (strong) XTStation *station;
@property (strong) NSDate *graphdate;

@end
