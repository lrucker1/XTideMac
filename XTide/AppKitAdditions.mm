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

#define SVG_EXPERIMENT 1
#ifdef SVG_EXPERIMENT
#import "XTStationInt.h"
#import "XTUtils.h"
#import "Graph.hh"
#import "SVGGraph.hh"
#endif

#define IOS_ICONS 0

@implementation XTStationRef (MacOSAdditions)

- (NSImage *)stationDot
{
    return [NSImage imageWithSize:NSMakeSize(12, 12) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        if (self.isCurrent) {
            [ColorForKey(XTide_ColorKeys[currentdotcolor]) set];
        } else {
            [ColorForKey(XTide_ColorKeys[tidedotcolor]) set];
        }
        [[NSBezierPath bezierPathWithOvalInRect:dstRect] fill];
        return YES;
    }];
}

@end


@implementation XTStation (MacOSAdditions)

#if DEBUG_GENERATE_WATCH_IMAGE

#if SVG_EXPERIMENT
- (NSData *)SVGClockImageWithWidth:(CGFloat)width
                            height:(CGFloat)height
                              date:(NSDate *)clockDate
{
    Dstr text_out;
    libxtide::Timestamp clockTS = libxtide::Timestamp((time_t)[clockDate timeIntervalSince1970]);
    libxtide::SVGGraph g(width, height, libxtide::Graph::clock);
    g.drawTides(mStation, clockTS);
    g.print(text_out);
    return [DstrToNSString(text_out) dataUsingEncoding:NSUTF8StringEncoding];
}
#endif

// Create a placeholder image for the watch app when there's no station
// Use the 1984 ad day and Golden Gate station:
//      Jan 22, 1984
//      "San Francisco, San Francisco Bay, California"
// 38mm: (0.0, 0.0, 136.0, 170.0)
// 42mm: (0.0, 0.0, 156.0, 195.0)
//
// XXX: This is the hackiest code I've written in a long time.
// But it's just a one-shot image generator, not user-facing, so it's good enough.

- (void)createWatchPlaceholderImages
{
    CGFloat scale = 2;
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    dateComponents.day = 22;
    dateComponents.month = 1;
    dateComponents.year = 1984;
    dateComponents.hour = 6;
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDate *date = [gregorianCalendar dateFromComponents:dateComponents];
#if IOS_ICONS
    NSString *fileLoc = [@"~/watchBackground38@2x.png" stringByExpandingTildeInPath];
    if (fileLoc) {
        [self createWatchPlaceholderImage:fileLoc
                                     rect:CGRectMake(0, 0, 136 * scale, 170 * scale)
                                     date:date];
    }
 
    fileLoc = [@"~/watchBackground42@2x.png" stringByExpandingTildeInPath];
    if (fileLoc) {
        [self createWatchPlaceholderImage:fileLoc
                                     rect:CGRectMake(0, 0, 156 * scale, 195 * scale)
                                     date:date];
    }
 
    fileLoc = [@"~/icon512@2x.png" stringByExpandingTildeInPath];
    if (fileLoc) {
        [self createWatchPlaceholderImage:fileLoc
                                     rect:CGRectMake(0, 0, 512 * scale, 512 * scale)
                                     date:date];
    }
#endif

#if SVG_EXPERIMENT
    // This works, but isn't as pretty as the images - no translucency, font isn't sharp,
    // no + mark for the current time.
    // PNG files are small enough to transfer to the watch.
    // Also the watch doesn't handle SVGs that aren't in files, though PocketSVG is an option.
    NSString *svgFileLoc = [@"~/watchBackground.svg" stringByExpandingTildeInPath];
    NSData *svgImage = [self SVGClockImageWithWidth:136 * scale height:170 * scale date:date];
    if (svgImage) {
        [svgImage writeToFile:svgFileLoc atomically:YES];
    }
#endif
}

- (void)createWatchPlaceholderImage:(NSString *)fileLoc
                               rect:(CGRect)offscreenRect
                               date:(NSDate *)date
{
    NSURL *fileURL = [NSURL fileURLWithPath:fileLoc];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSSize size = offscreenRect.size;
    CGContextRef contextRef = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    NSGraphicsContext *graphicsContext = [NSGraphicsContext graphicsContextWithCGContext:contextRef flipped:YES];
    
    NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];
    [NSGraphicsContext setCurrentContext:graphicsContext];

    // translate/flip the graphics context (for transforming from CoreGraphics coordinates to default UI coordinates. The Y axis is flipped on regular coordinate systems)
    CGContextTranslateCTM(contextRef, 0.0, offscreenRect.size.height);
    CGContextScaleCTM(contextRef, 1.0, -1.0);

    XTGraph *graph = [[XTGraph alloc] initIconModeWithXSize:offscreenRect.size.width ysize:offscreenRect.size.height scale:1];
    [graph drawTides:self now:date];
    CGColorSpaceRelease(colorSpace);
    CGImageRef imageRef = CGBitmapContextCreateImage(contextRef);
    [NSGraphicsContext setCurrentContext:currentContext];

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