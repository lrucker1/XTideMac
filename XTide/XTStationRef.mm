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

/*
 * loadStation creates a HarmonicsFile instance and is not thread safe,
 * because HarmonicsFile enforces having only one instance at a time.
 * Theoretically we could load multiple stations in the same file,
 * but that would break down on the Mac app which supports multiple files.
 * TODO: Consider dispatch_sync for loadStation.
 */
- (XTStation *)loadStation
{
    return [[XTStation alloc] initUsingStationRef:mStationRef];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] initWithStationRef:mStationRef];
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

- (CLLocation *)location
{
    // Assume stations are always at sea level.
    return [[CLLocation alloc] initWithCoordinate:[self coordinate]
                                         altitude:0
                               horizontalAccuracy:0
                                 verticalAccuracy:0
                                        timestamp:[NSDate date]];
}


- (NSString *)subtitle
{
    return (mStationRef->isReferenceStation ? NSLocalizedString(@"Reference", @"Reference station")
                                            : NSLocalizedString(@"Subordinate", @"Subordinate station"));
}


#pragma mark xtide

- (BOOL)isReferenceStation {return mStationRef->isReferenceStation;}
- (uint32_t)recordNumber {return mStationRef->recordNumber;}
- (BOOL)isCurrent {return mStationRef->isCurrent;}

// For sorting
- (NSString*)type
{
    return (mStationRef->isReferenceStation ? @"Ref" : @"Sub");
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
