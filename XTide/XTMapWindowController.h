//
//  XTMapWindowController.h
//  XTide
//
//  Created by Lee Ann Rucker on 4/14/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MapKit.h>

@interface XTMapWindowController : NSWindowController <NSPopoverDelegate>

@property (strong) IBOutlet MKMapView *mapView;
@property (strong) IBOutlet NSTextField *searchField;

- (IBAction)goHome:(id)sender;
- (IBAction)selectSuggestedAnnotation:(id)sender;

@end
