//
//  UIKitAdditions.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/2/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "UIKitAdditions.h"
#import "XTColorUtils.h"
#import "XTGraph.h"

@implementation XTStationRef (iOSAdditions)

- (UIImage *)stationDot
{
    CGRect rect = CGRectMake(0, 0, 20, 20);
    UIGraphicsBeginImageContext(rect.size);
    rect = CGRectInset(rect, 2, 2);
    CGContextRef context = UIGraphicsGetCurrentContext();

    UIColor *color = nil;
    if (self.isReferenceStation) {
        color = ColorForKey(XTide_ColorKeys[refcolor]);
    } else {
        color = ColorForKey(XTide_ColorKeys[subcolor]);
    }

    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillEllipseInRect(context, rect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

@end



@implementation XTStation (iOSAdditions)

- (UIImage *)clockImageWithXSize:(CGFloat)xsize
                           ysize:(CGFloat)ysize
                           scale:(CGFloat)scale
{
    CGRect rect = CGRectMake(0, 0, xsize, ysize);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, [[UIColor blackColor] CGColor]);
    CGContextFillRect(context, rect);
    [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:6] addClip];
    

    XTGraph *graph = [[XTGraph alloc] initClockModeWithXSize:xsize ysize:ysize scale:scale];
    [graph drawTides:self now:[NSDate date]];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (NSAttributedString *)stationInfo
{
	return [[NSAttributedString alloc] initWithData:[[self stationInfoAsHTML] dataUsingEncoding:NSUTF8StringEncoding]
                                 options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                           NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)} 
                      documentAttributes:nil
                                   error:nil];
}

@end
