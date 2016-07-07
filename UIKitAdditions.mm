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
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 2);
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

- (NSDictionary *)clockInfoWithXSize:(CGFloat)xsize
                               ysize:(CGFloat)ysize
                               scale:(CGFloat)scale
{
    CGRect rect = CGRectMake(0, 0, xsize, ysize);
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, scale);
    
    NSString *axString = nil;
    XTGraph *graph = [[XTGraph alloc] initClockModeWithXSize:xsize ysize:ysize scale:scale];
    [graph drawTides:self now:[NSDate date] description:&axString];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData *data = UIImagePNGRepresentation(image);
    if (axString == nil) {
        axString = @"";
    }

    return @{@"clockImage" : data, @"axDescription": axString, @"title" : self.name };
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
