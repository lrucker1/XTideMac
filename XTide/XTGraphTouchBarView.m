//
//  XTGraphTouchBarView.m
//  XTide
//
//  Created by Lee Ann Rucker on 10/31/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTGraphTouchBarView.h"
#import "XTColorUtils.h"
#import "XTGraph.h"
#import "TideController.h"
#import "XTStation.h"
#import "XTStationRef.h"

@interface XTGraphTouchBarView ()

@property NSDate *oldDate;
@property id trackingTouchIdentity;
@property CGFloat offset;
@property CGFloat lastX;
// load a separate instance of the station so we can adjust aspect ratio independently of
// any other graph.
@property XTStation *station;

@end

@implementation XTGraphTouchBarView

- (id)initWithFrame:(NSRect)frameRect date:(NSDate*)date stationRef:(XTStationRef *)in_stationRef
{
    self = [super initWithFrame:frameRect];
    if (!self) {
        return nil;
    }
    _graphdate = date;
    _station = [in_stationRef loadStation];
    _station.aspect = 2.0;
    return self;
}

- (id)initWithFrame:(NSRect)frameRect
{
    return [self initWithFrame:frameRect
                          date:[NSDate date]
                    stationRef:nil];
}

- (void)setGraphdate:(NSDate*)newdate
{
    _graphdate = newdate;
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    if (!self.station) {
        return;
    }

    [NSGraphicsContext saveGraphicsState];

    // Draw the entire bounds, clipping to the visibleRect
    // because the C++ code takes a lot of shortcuts - it assumes it's always starting from (0,0).
    NSRect frameRect = [self bounds];
    NSRectClip([self visibleRect]);
    XTGraph *mygraph = [self graphForFrame:frameRect];
    
    [mygraph drawTides:self.station now:self.graphdate];
    [NSGraphicsContext restoreGraphicsState];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)isFlipped
{
    return YES;
}

- (BOOL)isOpaque
{
    return YES;
}

- (XTGraph *)graphForFrame:(NSRect)frameRect
{
    return [[XTGraph alloc] initIconModeWithXSize:NSWidth(frameRect)
                                            ysize:NSHeight(frameRect)
                                            scale:2];
}

// Not part of standard XTide; this is here for dragging.
- (CGFloat)offsetTimeForDeltaX: (CGFloat)deltaX
{
    if (self.station) {
        NSRect frameRect = [self bounds];
        XTGraph *mygraph = [self graphForFrame:frameRect];
        double localDelta = deltaX;
        [self.dataSource syncStartDate:[mygraph offsetStationTime:self.station
                                                              now:self.graphdate
                                                           deltaX:&localDelta]];
        if (localDelta != deltaX) {
            NSLog(@"time to bounce %f %f %f", deltaX, localDelta, deltaX - localDelta);
        }
        [self setNeedsDisplay:YES];
        return localDelta;
    }
    return 0.0;
}

- (void)touchesBeganWithEvent:(NSEvent *)event
{
    // We are already tracking a touch, so this must be a new touch.
    // What should we do? Cancel or ignore.
    //
    if (self.trackingTouchIdentity == nil)
    {
        NSSet<NSTouch *> *touches = [event touchesMatchingPhase:NSTouchPhaseBegan inView:self];
        // Note: Touches may contain 0, 1 or more touches.
        // What to do if there are more than one touch?
        // In this example, randomly pick a touch to track and ignore the other one.
        
        NSTouch *touch = touches.anyObject;
        if (touch != nil)
        {
            if (touch.type == NSTouchTypeDirect)
            {
                _trackingTouchIdentity = touch.identity;
                
                // Remember the selection value at start of tracking in case we need to cancel.
                _oldDate = self.graphdate;
                
                NSPoint location = [touch locationInView:self];
                self.lastX = location.x;
            }
        }
    }
    
    [super touchesBeganWithEvent:event];
}

- (void)touchesMovedWithEvent:(NSEvent *)event
{
    if (self.trackingTouchIdentity)
    {
        for (NSTouch *touch in [event touchesMatchingPhase:NSTouchPhaseMoved inView:self])
        {
            if (touch.type == NSTouchTypeDirect && [_trackingTouchIdentity isEqual:touch.identity])
            {
                NSPoint location = [touch locationInView:self];
                CGFloat deltaX = self.lastX - location.x;
                [self offsetTimeForDeltaX:deltaX];
                self.lastX = location.x;
                
                break;
            }
        }
    }
    
    [super touchesMovedWithEvent:event];
}

- (void)touchesEndedWithEvent:(NSEvent *)event
{
    if (self.trackingTouchIdentity)
    {
        for (NSTouch *touch in [event touchesMatchingPhase:NSTouchPhaseEnded inView:self])
        {
            if (touch.type == NSTouchTypeDirect && [_trackingTouchIdentity isEqual:touch.identity])
            {
                // Finshed tracking successfully.
                _trackingTouchIdentity = nil;
                
//                NSPoint location = [touch locationInView:self];
//                self.trackingLocationString = [NSString stringWithFormat:@"Ended at: {x = %3.2f}", location.x];
                break;
            }
        }
    }

    [super touchesEndedWithEvent:event];
}

- (void)touchesCancelledWithEvent:(NSEvent *)event
{    
    if (self.trackingTouchIdentity)
    {
        for (NSTouch *touch in [event touchesMatchingPhase:NSTouchPhaseMoved inView:self])
        {
            if (touch.type == NSTouchTypeDirect && [self.trackingTouchIdentity isEqual:touch.identity])
            {
                // CANCEL
                // This can happen for a number of reasons.
                // # A gesture recognizer started recognizing a touch.
                // # The underlying touch context changed (User Cmd-Tabbed while interacting with this view).
                // # The hardware itself decided to cancel the touch.
                // Whatever the reason, but things back the way they were, in this example, reset the selection.
                //
                _trackingTouchIdentity = nil;
                
                [self.dataSource syncStartDate:self.oldDate];
            }
        }
    }
    
    [super touchesCancelledWithEvent:event];
}


@end
