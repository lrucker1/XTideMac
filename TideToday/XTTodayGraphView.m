//
//  XTTodayGraphView.m
//  XTide
//
//  Created by Lee Ann Rucker on 8/3/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTTodayGraphView.h"
#import "XTStation.h"
#import "XTGraph.h"

@implementation XTTodayGraphView

- (void)drawRect:(CGRect)rect
{
    if (self.station) {
        CGRect frameRect = [self bounds];
        XTGraph *mygraph = [[XTGraph alloc] initWithXSize:frameRect.size.width + 1
                                                    ysize:frameRect.size.height + 1];
        
        [mygraph drawTides:self.station now:[NSDate date]];
//    } else {
//        [[UIColor redColor] set];
//        UIRectFill(rect);
    }
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, 150);
}

@end
