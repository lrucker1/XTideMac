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
#import "XTTideEventsOrganizer.h"

@implementation XTStationRef (iOSAdditions)

- (UIImage *)stationDot
{
    CGRect rect = CGRectMake(0, 0, 20, 20);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 2);
    rect = CGRectInset(rect, 2, 2);
    CGContextRef context = UIGraphicsGetCurrentContext();

    UIColor *color = nil;
    if (self.isCurrent) {
        color = ColorForKey(XTide_ColorKeys[currentdotcolor]);
    } else {
        color = ColorForKey(XTide_ColorKeys[tidedotcolor]);
    }

    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillEllipseInRect(context, rect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

@end



@implementation XTStation (iOSAdditions)

- (NSAttributedString *)stationInfo
{
	return [[NSAttributedString alloc] initWithData:[[self stationInfoAsHTML] dataUsingEncoding:NSUTF8StringEncoding]
                                 options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                           NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)} 
                      documentAttributes:nil
                                   error:nil];
}

@end
