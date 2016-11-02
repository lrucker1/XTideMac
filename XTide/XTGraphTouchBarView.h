//
//  XTGraphTouchBarView.h
//  XTide
//
//  Created by Lee Ann Rucker on 10/31/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class QuartzGraph;
@class TideController;
@class XTStationRef;

@interface XTGraphTouchBarView : NSView

@property (readwrite, assign, nonatomic) TideController *dataSource;
@property (readwrite, retain, nonatomic) NSDate *graphdate;

- (instancetype)initWithFrame:(NSRect)frameRect date:(NSDate*)date  stationRef:(XTStationRef *)in_stationRef;

@end
