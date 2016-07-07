//
//  AppKitAdditions.m
//  XTide
//
//  Created by Lee Ann Rucker on 6/29/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "AppKitAdditions.h"
#import "XTColorUtils.h"
#import "XTGraph.h"

@implementation XTStationRef (MacOSAdditions)

- (NSImage *)stationDot
{
    return [NSImage imageWithSize:NSMakeSize(12, 12) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        if (self.isReferenceStation) {
            [ColorForKey(XTide_ColorKeys[refcolor]) set];
        } else {
            [ColorForKey(XTide_ColorKeys[subcolor]) set];
        }
        [[NSBezierPath bezierPathWithOvalInRect:dstRect] fill];
        return YES;
    }];
}

@end


@implementation XTStation (MacOSAdditions)

// Create a placeholder image for the watch app when there's no station
// Use the 1984 ad day and Golden Gate station:
//      Jan 22, 1984
//      "San Francisco, San Francisco Bay, California"
// 38mm: (0.0, 0.0, 136.0, 170.0)
// 42mm: (0.0, 0.0, 156.0, 195.0)
//
// XXX: This is the hackiest code I've written in a long time.
// The image comes out inverted (not flipped; a non-flipped GC gives us correct text but inverted tides),
// so it'll need fixing in a nice app like GraphicConverter.
// But it's just a one-shot image generator, not user-facing, so it's good enough.

#if DEBUG_GENERATE_WATCH_IMAGE
- (void)createWatchPlaceholderImage: (NSURL *)fileURL
{
    CGFloat xsize = 136;
    CGFloat ysize = 170;
    CGFloat scale = 2;
    CGRect offscreenRect = CGRectMake(0, 0, xsize * scale, ysize * scale);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSSize size = offscreenRect.size;
    CGContextRef contextRef = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    NSGraphicsContext *graphicsContext = [NSGraphicsContext graphicsContextWithCGContext:contextRef flipped:YES];
    
    NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];
    [NSGraphicsContext setCurrentContext:graphicsContext];
    XTGraph *graph = [[XTGraph alloc] initClockModeWithXSize:offscreenRect.size.width ysize:offscreenRect.size.height scale:1];
    [graph drawTides:self now:[NSDate date]];
    [NSGraphicsContext setCurrentContext:currentContext];
    CGColorSpaceRelease(colorSpace);
    CGImageRef imageRef = CGBitmapContextCreateImage(contextRef);

    CFURLRef url = (__bridge CFURLRef)fileURL;
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    if (!destination) {
        NSLog(@"Failed to create CGImageDestination for %@", fileURL);
        return;
    }

    CGImageDestinationAddImage(destination, imageRef, nil);

    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"Failed to write image to %@", fileURL);
        CFRelease(destination);
        return;
    }

    CFRelease(destination);
}
#endif

- (NSAttributedString *)stationInfo
{
	return [[NSAttributedString alloc] initWithHTML:[[self stationInfoAsHTML] dataUsingEncoding:NSASCIIStringEncoding]
								 documentAttributes:NULL];
}

@end