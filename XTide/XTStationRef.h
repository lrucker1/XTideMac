//
//  XTStationRef.h
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@class XTStation;

@interface XTStationRef : NSObject <MKAnnotation>

- (uint32_t)recordNumber;
- (XTStation *)loadStation;
- (BOOL)isReferenceStation;
- (CLLocation *)location;
- (BOOL)isCurrent;

@end
