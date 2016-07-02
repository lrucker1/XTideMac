//
//  XTStationRef.mm
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "XTStationRefInt.h"
#import "XTStationInt.h"
#import "XTUtils.h"

@interface XTStationRef ()
{
    libxtide::StationRef *mStationRef;
}

@property(readwrite, copy) NSString *title;

@end


@implementation XTStationRef

- (id)initWithStationRef: (libxtide::StationRef *)aStationRef
{
    if ((self = [super init])) {
        mStationRef = aStationRef;
        self.title = DstrToNSString(mStationRef->name);
    }
    return self;
}

- (void)dealloc
{
    // Created by HarmonicsFile->getNextStationRef(), owned by StationIndex.
    mStationRef = NULL;
    self.title = nil;
}

- (libxtide::StationRef *)adaptedStationRef
{
    return mStationRef;
}

- (XTStation *)loadStation
{
    return [[XTStation alloc] initUsingStationRef:mStationRef];
}

- (BOOL)isEqual:(id)object
{
    // harmonicsFileName + recordNumber uniquely identify a station.
    if (object == nil || ![object isKindOfClass:[self class]]) {
        return NO;
    }
    if (object == self) {
        return YES;
    }
    XTStationRef *objRef = (XTStationRef *)object;
    return objRef.adaptedStationRef->harmonicsFileName == mStationRef->harmonicsFileName
           && objRef.adaptedStationRef->recordNumber == mStationRef->recordNumber;
}

- (NSUInteger)hash
{
    return [DstrToNSString(mStationRef->harmonicsFileName) hash] + mStationRef->recordNumber;
}


#pragma mark MKAnnotation

- (CLLocationCoordinate2D)coordinate
{
    libxtide::Coordinates coordinates = mStationRef->coordinates;
    return CLLocationCoordinate2DMake(coordinates.lat(), coordinates.lng());
}

- (NSString *)subtitle
{
    return @"";
}


#pragma mark xtide

- (BOOL)isReferenceStation {return mStationRef->isReferenceStation;}
- (uint32_t)recordNumber {return mStationRef->recordNumber;}

// For sorting
- (NSString*)type
{
    return (mStationRef->isReferenceStation? @"Ref" : @"Sub");
}

// For sorting
- (NSNumber*)latitude
{
    return [NSNumber numberWithDouble:mStationRef->coordinates.lat()];
}

// For sorting
- (NSNumber*)longitude
{
    return [NSNumber numberWithDouble:mStationRef->coordinates.lng()];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ %@ %f %f",
            [self title],
            [self type],
            mStationRef->coordinates.lat(),
            mStationRef->coordinates.lng()];
}

@end
