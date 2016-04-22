//
//  GraphView.m
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

#import "GraphView.h"
#import "XTGraph.h"
#import "TideController.h"
#import "XTStation.h"

// these constants were determined by experimentation
const double DEFAULT_MOTION_DAMP = 0.95;
const double DEFAULT_MOTION_MINIMUM = 0.0001;
const double DEFAULT_FLICK_THRESHOLD = 0.01;
const double DEFAULT_ANIMATION_RATE = 1.0f / 60.0f;
const double DEFAULT_MOTION_MULTIPLIER = 0.75f;

const double MOTION_MAX = 3.0f; //0.165f;
const NSTimeInterval FLICK_TIME_BACK = 0.07;
const NSUInteger DEFAULT_CAPACITY = 20;

NSString * const TideViewTouchesBeganNotification = @"TideViewTouchesBegan";

@interface GraphView () // FlickDynamics

@property (readwrite, retain) NSTimer *flickTimer;
@property (readwrite, retain) NSEvent *lastEvent;

-(void)clearHistory;
-(void)addToHistory:(TouchInfo)info;
-(TouchInfo)getHistoryAtIndex:(NSUInteger)index;
-(TouchInfo)getRecentHistory;
- (void)setFlickValuesForFrame: (NSRect)frame;

-(double)linearMap:(double)value
          valueMin:(double)valueMin
          valueMax:(double)valueMax
         targetMin:(double)targetMin
         targetMax:(double)targetMax;
-(double)linearInterpolate:(double)from to:(double)to percent:(double)percent;
-(void)stopMotion;

@end

@implementation GraphView

@synthesize graphdate;
@synthesize lastEvent;
@synthesize flickTimer;

- (id)initWithFrame:(NSRect)frameRect date:(NSDate*)date
{
    if ((self = [super initWithFrame:frameRect]) != nil) {
        // Add initialization code here
        graphdate = date;
        [self setFlickValuesForFrame:frameRect];
    }
    return self;
}

- (id)initWithFrame:(NSRect)frameRect
{
    return [self initWithFrame:frameRect
                          date:[NSDate date]];
}

- (void)dealloc
{
    graphdate = nil;
    self.lastEvent = nil;
    if (history) {
        free(history);
        history = NULL;
    }
}

- (void)awakeFromNib
{
    [dataSource setWindowTitleDate:graphdate];
}

- (BOOL)isFlipped
{
    return YES;
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    return NSDragOperationCopy;
}

- (void)setGraphdate:(NSDate*)newdate
{
    graphdate = newdate;
    [dataSource setWindowTitleDate:graphdate];
    [self display];
}

- (double)offsetTimeForDeltaX: (double)deltaX
{
    if ([dataSource station]) {
//        NSRect frameRect = [self bounds];
//        XTGraph *mygraph = [[XTGraph alloc] initWithXSize:frameRect.size.width
//                                                    ysize:frameRect.size.height];
        double localDelta = deltaX;
        // TODO: ???
//        self.graphdate = [mygraph offsetStationTime:[dataSource station]
//                                                now:graphdate
//                                             deltaX:&localDelta];
        if (localDelta != deltaX) {
            //NSLog(@"time to bounce %f %f %f", deltaX, localDelta, deltaX - localDelta);
        }
        [self setNeedsDisplay:YES];
        return localDelta;
    }
    return 0.0;
}

- (NSData *)PDFRepresentation
{
    return [self dataWithPDFInsideRect:[self visibleRect]];
}

- (NSData *)TIFFRepresentationWithPDF:(NSData*)data
{
    NSImage *image = [[NSImage alloc] initWithData:data];
    return [image TIFFRepresentation];
}

- (NSData *)TIFFRepresentation
{
    return [self TIFFRepresentationWithPDF:[self PDFRepresentation]];
}

- (IBAction)copy:(id)sender
{
    NSData *pdf = [self PDFRepresentation];
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    [pboard declareTypes:[NSArray arrayWithObjects:NSTIFFPboardType, NSPDFPboardType, nil] owner:nil];
    [pboard setData:[self TIFFRepresentationWithPDF:pdf] forType:NSTIFFPboardType];
    [pboard setData:pdf forType:NSPDFPboardType];
}

- (void)drawRect:(NSRect)rect
{
    NSRect frameRect = [self visibleRect];
    XTGraph *mygraph = [[XTGraph alloc] initWithXSize:frameRect.size.width + 1
                                                ysize:frameRect.size.height + 1];
    [mygraph drawTides:[dataSource station] now:graphdate];
}


- (void)mouseDown: (NSEvent *)theEvent
{
    NSPoint firstTouch = [self convertPoint:[theEvent locationInWindow]
                                   fromView:nil];
    [self stopMotion];
    [self clearHistory];
    
    TouchInfo info;
    info.x = firstTouch.x;
    info.y = firstTouch.y;
    info.time = [[NSDate date] timeIntervalSince1970];
    
    [self addToHistory:info];
    
    self.lastEvent = theEvent;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:TideViewTouchesBeganNotification
     object:self];
}

// Handles the continuation of a touch.
-(void)mouseDragged: (NSEvent *)theEvent
{
    NSPoint lastTouch = [self convertPoint:[lastEvent locationInWindow]
                                  fromView:nil];
    NSPoint movedTouch = [self convertPoint:[theEvent locationInWindow]
                                   fromView:nil];
    double deltaX = lastTouch.x - movedTouch.x;
    [self offsetTimeForDeltaX:deltaX];
    [self display];
    
    TouchInfo old = [self getRecentHistory];
    
    TouchInfo info;
    info.x = movedTouch.x;
    info.y = movedTouch.y;
    info.time = [[NSDate date] timeIntervalSince1970];
    [self addToHistory:info];
    
    self.lastEvent = theEvent;
}

- (void)mouseUp: (NSEvent *)theEvent
{
    NSPoint lastTouch = [self convertPoint:[lastEvent locationInWindow]
                                  fromView:nil];
    NSPoint movedTouch = [self convertPoint:[theEvent locationInWindow]
                                   fromView:nil];
    double deltaX = lastTouch.x - movedTouch.x;
    [self offsetTimeForDeltaX:deltaX];
    TouchInfo old = [self getRecentHistory];
    TouchInfo last;
    last.x = movedTouch.x;
    last.y = movedTouch.y;
    last.time = [[NSDate date] timeIntervalSince1970];
    [self addToHistory:last];
    
    // find the first point in our touch history that is younger than FLICK_TIME_BACK seconds.
    // this point, and the point of release, will allow us to find our vector for motion.
    NSTimeInterval crossoverTime = last.time - FLICK_TIME_BACK;
    NSUInteger recentIndex = 0;
    for (NSUInteger testIndex = 0; testIndex < historyCount; testIndex++)
    {
        TouchInfo testInfo = [self getHistoryAtIndex:testIndex];
        if (testInfo.time > crossoverTime)
        {
            recentIndex = testIndex;
            break;
        }
    }
    
    if (recentIndex == 0)
    {
        // this is a very fast gesture. we will want to interpolate this point
        // and the next _as if_ they projected out to where the touch would have
        // been at time NOW - FLICK_TIME_BACK
        recentIndex += 1;
    }
    
    // We have the two points closest to FLICK_TIME_BACK seconds
    // Use linear interpolation to decide where the point _would_ have been at FLICK_TIME_BACK seconds
    TouchInfo recentInfo = [self getHistoryAtIndex:recentIndex];
    TouchInfo previousInfo = [self getHistoryAtIndex:(recentIndex - 1)];
    double crossoverTimePercent = [self linearMap:crossoverTime valueMin:previousInfo.time valueMax:recentInfo.time targetMin:0.0f targetMax:1.0f];
    double flickX = [self linearInterpolate:previousInfo.x to:recentInfo.x percent:crossoverTimePercent];
    double flickY = [self linearInterpolate:previousInfo.y to:recentInfo.y percent:crossoverTimePercent];
    
    // Dampen the motion along each axis if it is too small to matter
    if (fabs(last.x - flickX) < flickThresholdX)
    {
        flickX = last.x;
    }
    
    if (fabs(last.y - flickY) < flickThresholdY)
    {
        flickY = last.y;
    }
    
    // this is not a flick gesture if there is no motion after interpolation and dampening
    if ((last.x == flickX) && (last.y == flickY))
    {
        return;
    }
    
    // determine our raw motion
    double rawMotionX = (flickX - last.x) * motionMultiplier;
    
    // done! assign our motion!
    motionX = rawMotionX;
    if (motionX != 0.0) {
        self.flickTimer =
        [NSTimer scheduledTimerWithTimeInterval:DEFAULT_ANIMATION_RATE
                                         target:self
                                       selector:@selector(timerFireMethod:)
                                       userInfo:nil
                                        repeats:YES];
    }
}

- (void)timerFireMethod:(NSTimer*)theTimer
{
    if (motionX == 0.0)
    {
        [theTimer invalidate];
        self.flickTimer = nil;
        return;
    }
    
    [self offsetTimeForDeltaX:motionX];
    
    motionX *= motionDamp;
    
    if (fabs(motionX) < motionMinimum)
    {
        motionX = 0.0;
    }
}

- (void)setFlickValuesForFrame: (NSRect)frame
{
    // "history" is a buffer of the last N touches. For performance, it is
    // managed as a circular queue; older items are just dropped from it.
    if (!history) {
        history = (TouchInfo*) malloc(sizeof(TouchInfo) * DEFAULT_CAPACITY);
    }
    historyCount = 0;
    historyHead = 0;
    double xAdjustment = frame.size.width / 1.0;
    double yAdjustment = frame.size.height / 1.0;
    //double viewportAdjustment = (xAdjustment + yAdjustment) / 2.0;
    
    double animationRateAdjustment = 2.0;
    motionDamp = pow(DEFAULT_MOTION_DAMP, animationRateAdjustment);
    motionMultiplier = DEFAULT_MOTION_MULTIPLIER; /* does not need to be affected by viewportAdjustment */
    motionMinimum = 3; //DEFAULT_MOTION_MINIMUM * viewportAdjustment;
    flickThresholdX = DEFAULT_FLICK_THRESHOLD * xAdjustment;
    flickThresholdY = DEFAULT_FLICK_THRESHOLD * yAdjustment;
}

-(void)clearHistory
{
    historyCount = 0;
    historyHead = 0;
}

-(void)addToHistory:(TouchInfo)info
{
    NSUInteger rawIndex;
    
    if (historyCount < DEFAULT_CAPACITY) {
        rawIndex = historyCount;
        historyCount += 1;
    }
    else {
        rawIndex = historyHead;
        historyHead += 1;
        if (historyHead == DEFAULT_CAPACITY)
        {
            historyHead = 0;
        }
    }
    
    history[rawIndex].x = info.x;
    history[rawIndex].y = info.y;
    history[rawIndex].time = info.time;
}

-(TouchInfo)getHistoryAtIndex:(NSUInteger)index
{
    NSUInteger rawIndex = historyHead + index;
    
    if (rawIndex >= DEFAULT_CAPACITY) {
        rawIndex -= DEFAULT_CAPACITY;
    }
    
    return history[rawIndex];
}

-(TouchInfo)getRecentHistory
{
    return [self getHistoryAtIndex:(historyCount-1)];
}

-(double)linearMap:(double)value
          valueMin:(double)valueMin
          valueMax:(double)valueMax
         targetMin:(double)targetMin
         targetMax:(double)targetMax
{
    double zeroValue = value - valueMin;
    double valueRange = valueMax - valueMin;
    double targetRange = targetMax - targetMin;
    double zeroTargetValue = zeroValue * (targetRange / valueRange);
    double targetValue = zeroTargetValue + targetMin;
    return targetValue;
}

-(double)linearInterpolate:(double)from to:(double)to percent:(double)percent
{
    return (from * (1.0f - percent)) + (to * percent);
}


-(void)stopMotion
{
    motionX = 0.0;
    [self.flickTimer invalidate];
    self.flickTimer = nil;
}

#pragma mark autolayout

- (NSSize)intrinsicContentSize
{
    return NSMakeSize(NSViewNoInstrinsicMetric, 300);
}
@end
