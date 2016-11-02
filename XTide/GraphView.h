//
//  GraphView.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 7/15/06.
//  Copyright 2006 .
//
/*
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#import <Cocoa/Cocoa.h>

@class QuartzGraph;
@class TideController;

extern NSString * const TideViewTouchesBeganNotification;

typedef struct TouchInfo {
    double x;
    double y;
    NSTimeInterval time; // all relative to the 1970 GMT epoch
} TouchInfo;

@interface GraphView : NSView
{
    NSDate *graphdate;
    
    TouchInfo *history;
    NSUInteger historyCount;
    NSUInteger historyHead;
    NSEvent *lastEvent;
    
    double motionX;
    double flickThresholdX;
    double flickThresholdY;
    double motionDamp;
    double motionMultiplier;
    double motionMinimum;
    NSTimer *flickTimer;

    NSTouch *_initialTouches[2];
    NSTouch *_currentTouches[2];
}

@property (readwrite, assign, nonatomic) IBOutlet TideController *dataSource;
@property (readwrite, retain, nonatomic) NSDate *graphdate;

- (instancetype)initWithFrame:(NSRect)frameRect date:(NSDate*)date;
- (NSData *)PDFRepresentation;
- (NSData *)TIFFRepresentation;

- (IBAction)copy:(id)sender;
- (void)stopMotion;

@end
