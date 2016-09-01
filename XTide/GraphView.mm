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
//  Some parts adapted from FlickDynamics:
//  (c) 2009 Dave Peck <davepeck [at] davepeck [dot] org>
//  This code is released under the BSD license. If you use my code in your product,
//  please put my name somewhere in the credits.

#import "GraphView.h"
#import "XTGraph.h"
#import "TideController.h"
#import "XTStation.h"

// these constants were determined by experimentation
const double DEFAULT_MOTION_DAMP = 0.95;
//const double DEFAULT_MOTION_MINIMUM = 0.0001;
const double DEFAULT_FLICK_THRESHOLD = 0.01;
const double DEFAULT_ANIMATION_RATE = 1.0f / 60.0f;
const double DEFAULT_MOTION_MULTIPLIER = 0.75f;

//const double MOTION_MAX = 3.0f; //0.165f;
const NSTimeInterval FLICK_TIME_BACK = 0.07;
const NSUInteger DEFAULT_CAPACITY = 20;

NSString * const TideViewTouchesBeganNotification = @"TideViewTouchesBegan";


@interface GraphView () // FlickDynamics

@property (readwrite, retain) NSTimer *flickTimer;
@property (readwrite, retain) NSEvent *lastEvent;
@property NSPoint initialPoint;
@property(readwrite) NSUInteger modifiers;
@property(readonly) NSPoint deltaOrigin;
@property(readonly) NSSize deltaSize;
@property CGFloat threshold;

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
    self.threshold = 30.0;
}

- (BOOL)isFlipped
{
    return YES;
}

- (BOOL)isOpaque
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
    self.needsDisplay = YES;
}

// Not part of standard XTide; this is here for dragging.
- (double)offsetTimeForDeltaX: (double)deltaX
{
    if ([self.dataSource station]) {
        NSRect frameRect = [self bounds];
        XTGraph *mygraph = [[XTGraph alloc] initWithXSize:frameRect.size.width
                                                    ysize:frameRect.size.height];
        double localDelta = deltaX;
        self.graphdate = [mygraph offsetStationTime:[self.dataSource station]
                                                now:graphdate
                                             deltaX:&localDelta];
        if (localDelta != deltaX) {
            NSLog(@"time to bounce %f %f %f", deltaX, localDelta, deltaX - localDelta);
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
    if (![self.dataSource station]) {
        return;
    }

    [NSGraphicsContext saveGraphicsState];

    // Draw the entire bounds, clipping to the visibleRect, which is required for printing
    // and also because the C++ code draws outside the bounds when it does labels.
    // It takes a lot of shortcuts - it assumes it's always starting from (0,0).
    // It also wants to center the station name. Having that on each page might be nice,
    // but... also a lot of work.
    NSRect frameRect = [self bounds];
    NSRectClip([self visibleRect]);
    XTGraph *mygraph = [[XTGraph alloc] initWithXSize:NSWidth(frameRect)
                                                ysize:NSHeight(frameRect)];
    
    [mygraph drawTides:[self.dataSource station] now:graphdate];
    [NSGraphicsContext restoreGraphicsState];
}

- (void)startAtPoint:(CGPoint)firstTouch
           withEvent:(NSEvent *)theEvent
{
    [self setFlickValuesForFrame:[self bounds]];
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

- (void)moveToPoint:(CGPoint)movedTouch
          withEvent:(NSEvent *)theEvent
{
    TouchInfo info;
    info.x = movedTouch.x;
    info.y = movedTouch.y;
    info.time = [[NSDate date] timeIntervalSince1970];
    [self addToHistory:info];
    
    self.lastEvent = theEvent;
}

- (void)releaseAtPoint:(CGPoint)movedTouch
{
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

- (void)mouseDown: (NSEvent *)theEvent
{
    NSPoint firstTouch = [self convertPoint:[theEvent locationInWindow]
                                   fromView:nil];
    [self startAtPoint:firstTouch withEvent:theEvent];
}

// Handles the continuation of a touch.
-(void)mouseDragged: (NSEvent *)theEvent
{
    NSPoint lastTouch = [self convertPoint:[self.lastEvent locationInWindow]
                                  fromView:nil];
    NSPoint movedTouch = [self convertPoint:[theEvent locationInWindow]
                                   fromView:nil];
    double deltaX = lastTouch.x - movedTouch.x;
    [self offsetTimeForDeltaX:deltaX];
    
    [self moveToPoint:movedTouch withEvent:theEvent];
}

// Uses the motion history to determine if there should be additional motion.
- (void)mouseUp: (NSEvent *)theEvent
{
    NSPoint lastTouch = [self convertPoint:[self.lastEvent locationInWindow]
                                  fromView:nil];
    NSPoint movedTouch = [self convertPoint:[theEvent locationInWindow]
                                   fromView:nil];
    double deltaX = lastTouch.x - movedTouch.x;
    [self offsetTimeForDeltaX:deltaX];
    [self releaseAtPoint:movedTouch];
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

- (BOOL)acceptsTouchEvents
{
    return YES;
}


- (void)releaseTouches
{
    _initialTouches[0] = nil;
    _initialTouches[1] = nil;
    _currentTouches[0] = nil;
    _currentTouches[1] = nil;
}

- (void)cancelTracking
{
    [self stopMotion];
    [self clearHistory];
    [self releaseTouches];
}

- (void)touchesBeganWithEvent:(NSEvent *)event
{
    NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseTouching inView:self];
    if (touches.count == 2) {
        self.initialPoint = [self convertPoint:[event locationInWindow]
                                      fromView:nil];
        NSArray *array = [touches allObjects];
        _initialTouches[0] = [array objectAtIndex:0];
        _initialTouches[1] = [array objectAtIndex:1];
        _currentTouches[0] = _initialTouches[0];
        _currentTouches[1] = _initialTouches[1];
        [self startAtPoint:self.initialPoint withEvent:event];
    } else if (touches.count > 2) {
        [self stopMotion];
        [self clearHistory];
        [self releaseTouches];
    }
}

// Overkill for this view because we only want dX.
- (NSPoint)deltaOrigin {
    if (!(_initialTouches[0] && _initialTouches[1] && _currentTouches[0] && _currentTouches[1])) return NSZeroPoint;
    
    CGFloat x1 = MIN(_initialTouches[0].normalizedPosition.x, _initialTouches[1].normalizedPosition.x);
    CGFloat x2 = MIN(_currentTouches[0].normalizedPosition.x, _currentTouches[1].normalizedPosition.x);
    CGFloat y1 = MIN(_initialTouches[0].normalizedPosition.y, _initialTouches[1].normalizedPosition.y);
    CGFloat y2 = MIN(_currentTouches[0].normalizedPosition.y, _currentTouches[1].normalizedPosition.y);
    
    NSSize deviceSize = _initialTouches[0].deviceSize;
    NSPoint delta;
    delta.x = (x2 - x1) * deviceSize.width;
    delta.y = (y2 - y1) * deviceSize.height;
    return delta;
}

- (NSSize)deltaSize {
    if (!(_initialTouches[0] && _initialTouches[1] && _currentTouches[0] && _currentTouches[1])) return NSZeroSize;
    
    CGFloat x1,x2,y1,y2,width1,width2,height1,height2;
    
    x1 = MIN(_initialTouches[0].normalizedPosition.x, _initialTouches[1].normalizedPosition.x);
    x2 = MAX(_initialTouches[0].normalizedPosition.x, _initialTouches[1].normalizedPosition.x);
    width1 = x2 - x1;
    
    y1 = MIN(_initialTouches[0].normalizedPosition.y, _initialTouches[1].normalizedPosition.y);
    y2 = MAX(_initialTouches[0].normalizedPosition.y, _initialTouches[1].normalizedPosition.y);
    height1 = y2 - y1;
    
    x1 = MIN(_currentTouches[0].normalizedPosition.x, _currentTouches[1].normalizedPosition.x);
    x2 = MAX(_currentTouches[0].normalizedPosition.x, _currentTouches[1].normalizedPosition.x);
    width2 = x2 - x1;
    
    y1 = MIN(_currentTouches[0].normalizedPosition.y, _currentTouches[1].normalizedPosition.y);
    y2 = MAX(_currentTouches[0].normalizedPosition.y, _currentTouches[1].normalizedPosition.y);
    height2 = y2 - y1;
    
    NSSize deviceSize = _initialTouches[0].deviceSize;
    NSSize delta;
    delta.width = (width2 - width1) * deviceSize.width;
    delta.height = (height2 - height1) * deviceSize.height;
    return delta;
}


- (void)touchesMovedWithEvent:(NSEvent *)event
{
    self.modifiers = [event modifierFlags];
    NSPoint eventPoint = [self convertPoint:[event locationInWindow]
                                   fromView:nil];
    NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseTouching inView:self];
    if (touches.count == 2 && _initialTouches[0]) {
        NSArray *array = [touches allObjects];
        _currentTouches[0] = nil;
        _currentTouches[1] = nil;

        NSTouch *touch;
        touch = [array objectAtIndex:0];
        if (touch.phase == NSTouchPhaseStationary) {
            self.initialPoint = eventPoint;
           return;
        }
        if ([touch.identity isEqual:_initialTouches[0].identity]) {
            _currentTouches[0] = touch;
        } else {
            _currentTouches[1] = touch;
        }
        touch = [array objectAtIndex:1];
        if (touch.phase == NSTouchPhaseStationary) {
            self.initialPoint = eventPoint;
            return;
        }
        if ([touch.identity isEqual:_initialTouches[0].identity]) {
            _currentTouches[0] = touch;
        } else {
            _currentTouches[1] = touch;
        }
        NSPoint deltaOrigin = self.deltaOrigin;
        if (fabs(deltaOrigin.x) > _threshold) {
            NSPoint movePoint = self.initialPoint;
            movePoint.x += deltaOrigin.x;
            movePoint.y += deltaOrigin.y;
            [self offsetTimeForDeltaX:deltaOrigin.x];
            [self moveToPoint:movePoint withEvent:event];
        }
    }
    // Always reset initial point.
    self.initialPoint = eventPoint;
}

// Uses the motion history to determine if there should be additional motion.
- (void)touchesEndedWithEvent:(NSEvent *)event
{
    NSPoint eventPoint = [self convertPoint:[event locationInWindow]
                                   fromView:nil];
    [self releaseAtPoint:eventPoint];
}
 
- (void)touchesCancelledWithEvent:(NSEvent *)event
{
    [self cancelTracking];
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

#pragma mark print
#if 0 // This would be nice, but it doesn't work for scaled printing.

// Return the number of pages available for printing
- (BOOL)knowsPageRange:(NSRangePointer)range
{
    NSRect bounds = [self bounds];
    CGFloat printWidth = [self calculatePageSize].width;
 
    range->location = 1;
    range->length = ceil(NSWidth(bounds) / printWidth);
    return YES;
}

- (NSRect)printRect
{
    NSPrintInfo *pi = [[NSPrintOperation currentOperation] printInfo];
    NSSize paperSize = [pi paperSize];
    CGFloat pageHeight = paperSize.height - [pi topMargin] - [pi bottomMargin];
    CGFloat pageWidth = paperSize.width - [pi leftMargin] - [pi rightMargin];
    return NSMakeRect(0, 0, pageWidth, pageHeight);
}

// Return the drawing rectangle for a particular page number
- (NSRect)rectForPage:(NSInteger)page
{
    NSSize pageSize = [self calculatePageSize];
    return NSMakeRect( (page-1) * pageSize.width, 0, pageSize.width, pageSize.height );
}

- (NSSize)calculatePageSize
{
    // Obtain the print info object for the current operation
    NSPrintInfo *pi = [[NSPrintOperation currentOperation] printInfo];
 
    // Calculate the page width in points
    NSSize paperSize = [pi paperSize];
    CGFloat pageHeight = paperSize.height - [pi topMargin] - [pi bottomMargin];
    CGFloat pageWidth = paperSize.width - [pi leftMargin] - [pi rightMargin];
 
    // Convert width to the scaled view
    CGFloat scale = [[[pi dictionary] objectForKey:NSPrintScalingFactor]
                    floatValue];
    return NSMakeSize(pageWidth / scale, pageHeight / scale);
}
#endif

@end
