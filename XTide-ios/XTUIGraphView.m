//
//  XTUIGraphView.m
//  XTide
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//
//  Some parts adapted from FlickDynamics:
//  (c) 2009 Dave Peck <davepeck [at] davepeck [dot] org>
//  This code is released under the BSD license. If you use my code in your product,
//  please put my name somewhere in the credits.

#import "XTUIGraphView.h"
#import "XTStation.h"
#import "XTGraph.h"

// these constants were determined by experimentation
const double DEFAULT_MOTION_DAMP = 0.95;
//const double DEFAULT_MOTION_MINIMUM = 0.0001;
const double DEFAULT_FLICK_THRESHOLD = 0.01;
const double DEFAULT_ANIMATION_RATE = 1.0f / 60.0f;
const double DEFAULT_MOTION_MULTIPLIER = 0.75f;

//const double MOTION_MAX = 3.0f; //0.165f;
const NSTimeInterval FLICK_TIME_BACK = 0.07;
const NSUInteger DEFAULT_CAPACITY = 20;


@interface XTUIGraphView () // FlickDynamics

@property (readwrite, retain) NSTimer *flickTimer;
@property CGPoint initialPoint;

@end


@implementation XTUIGraphView

@synthesize flickTimer;

- (void)drawRect:(CGRect)rect
{
    if (self.station) {
        if (!self.graphdate) {
            self.graphdate = [NSDate date];
        }
        CGRect frameRect = [self bounds];
        //[ColorForKey(XTide_ColorKeys[nightcolor]) set];
        [[UIColor whiteColor] set];
        UIRectFill(frameRect);
        XTGraph *mygraph = [[XTGraph alloc] initWithXSize:frameRect.size.width + 1
                                                    ysize:frameRect.size.height + 1];
        
        [mygraph drawTides:self.station now:self.graphdate];
    } else {
        [[UIColor redColor] set];
        UIRectFill(rect);
    }
}

- (void)returnToNow
{
    // TODO: Some intermediate dates so it's not so abrupt.
    [self stopMotion];
    self.hasCustomDate = NO;
    self.graphdate = [NSDate date];
    [self setNeedsDisplay];
}

// Not part of standard XTide; this is here for dragging.
- (double)offsetTimeForDeltaX: (double)deltaX
{
    if (self.station) {
        CGRect frameRect = [self bounds];
        XTGraph *mygraph = [[XTGraph alloc] initWithXSize:frameRect.size.width
                                                    ysize:frameRect.size.height];
        double localDelta = deltaX;
        self.graphdate = [mygraph offsetStationTime:self.station
                                                now:self.graphdate
                                             deltaX:&localDelta];
        if (localDelta != deltaX) {
            NSLog(@"time to bounce %f %f %f", deltaX, localDelta, deltaX - localDelta);
        }
        self.hasCustomDate = YES;
        [self setNeedsDisplay];
        return localDelta;
    }
    return 0.0;
}

- (void)startAtPoint:(CGPoint)firstTouch
{
    [self setFlickValuesForFrame:[self bounds]];
    [self stopMotion];
    [self clearHistory];
    
    TouchInfo info;
    info.x = firstTouch.x;
    info.y = firstTouch.y;
    info.time = [[NSDate date] timeIntervalSince1970];
    
    [self addToHistory:info];
}

- (void)moveToPoint:(CGPoint)movedTouch
{
    TouchInfo info;
    info.x = movedTouch.x;
    info.y = movedTouch.y;
    info.time = [[NSDate date] timeIntervalSince1970];
    [self addToHistory:info];
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

- (void)setFlickValuesForFrame: (CGRect)frame
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


#define HORIZ_SWIPE_DRAG_MIN  12


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self stopMotion];

    if (touches.count > 1) {
        return;
    }
    UITouch *touch = [touches anyObject];
    self.initialPoint = [touch locationInView:self];
    [self startAtPoint:self.initialPoint];
}
 
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    if (touches.count == 1) {
        CGPoint currentTouchPosition = [touch locationInView:self];
        //  Check if direction of touch is horizontal and long enough
        double deltaX = self.initialPoint.x - currentTouchPosition.x;
        if (fabs(deltaX) >= HORIZ_SWIPE_DRAG_MIN)
        {
            [self offsetTimeForDeltaX:deltaX];
            [self moveToPoint:currentTouchPosition];
        }
    }
    // Always reset initial point.
    self.initialPoint = [touch locationInView:self];
}
 
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([touches count] > 1) {
        [self stopMotion];
        return;
    }
    UITouch *aTouch = [touches anyObject];
    CGPoint currentTouchPosition = [aTouch locationInView:self];
 
    //  Check if direction of touch is horizontal and long enough
    double deltaX = self.initialPoint.x - currentTouchPosition.x;
    if (fabs(deltaX) >= HORIZ_SWIPE_DRAG_MIN)
    {
        [self offsetTimeForDeltaX:deltaX];
        [self releaseAtPoint:currentTouchPosition];
    }
    self.initialPoint = CGPointZero;
}
 
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.initialPoint = CGPointZero;
}
@end
