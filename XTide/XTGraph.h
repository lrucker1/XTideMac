//
//  XTGraph.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XTColorUtils.h"

@class XTStation;

@interface XTGraph : NSObject

+ (BOOL)isColorOfInterest:(NSString*)key;
+ (NSArray *)colorsOfInterest;

- (id)initWithXSize:(unsigned)xsize ysize:(unsigned)ysize;

// This is where it all starts
- (void)drawTides:(XTStation*)sr now:(NSDate*)now;

// Custom method for drag events.
- (NSDate*)offsetStationTime:(XTStation*)sr
                         now:(NSDate *)now
                      deltaX:(double *)deltaX;

@end
