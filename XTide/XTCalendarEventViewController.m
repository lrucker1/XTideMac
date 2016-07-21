//
//  XTCalendarEventViewController.m
//  XTide
//
//  Created by Lee Ann Rucker on 7/20/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import <EventKit/EventKit.h>
#import "XTCalendarEventViewController.h"

@interface XTCalendarEventViewController ()


@end

@interface NSColor (DarkerColor)

- (NSColor *)darkerColor;

@end

@implementation NSColor (DarkerColor)

- (NSColor *)darkerColor
{
    CGFloat h, s, b, a;
    [self getHue:&h saturation:&s brightness:&b alpha:&a];
    return [NSColor colorWithHue:h
                      saturation:1
                      brightness:b * 0.6
                           alpha:1];
}

@end

@implementation XTCalendarEventViewController

- (NSImage *)dotWithColor:(NSColor *)color
{
    return [NSImage imageWithSize:NSMakeSize(12, 12) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        dstRect = NSInsetRect(dstRect, 1, 1);
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:dstRect xRadius:1 yRadius:1];
        [[color darkerColor] set];
        [path stroke];
        [color set];
        [path fill];
        return YES;
    }];
}

// There can be duplicate names.
- (NSMenuItem *)menuItemForCalendar:(EKCalendar *)cal
{
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:cal.title action:nil keyEquivalent:@""];
    menuItem.representedObject = cal;
    menuItem.indentationLevel = 1;
    menuItem.image = [self dotWithColor:[cal color]];
    return menuItem;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
    NSArray *calendars = [self.eventStore calendarsForEntityType:EKEntityTypeEvent];
    NSMutableArray *local = [NSMutableArray array];
    NSMutableArray *cloud = [NSMutableArray array];
    
    for (EKCalendar *cal in calendars) {
        if (!cal.allowsContentModifications) {
            continue;
        }
        if (cal.type == EKCalendarTypeLocal) {
            [local addObject:cal];
        } else if (cal.type == EKCalendarTypeCalDAV) {
            [cloud addObject:cal];
        }
    }
    // No, the Calendar app does not do case insensitive sort.
    NSSortDescriptor *nameSort = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
    [local sortUsingDescriptors:@[nameSort]];
    [cloud sortUsingDescriptors:@[nameSort]];

    NSMenu *menu = self.calendarPopup.menu;
    NSMenuItem *header = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"On My Mac", @"Name for local calendars")
                                                    action:nil
                                             keyEquivalent:@""];
    [header setEnabled:NO];
    [menu addItem:header];
    for (EKCalendar *cal in local) {
        [menu addItem:[self menuItemForCalendar:cal]];
    }
    if ([cloud count]) {
        [menu addItem:[NSMenuItem separatorItem]];
        header = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"iCloud", @"Name for iCloud calendars")
                                                    action:nil
                                             keyEquivalent:@""];
        [header setEnabled:NO];
        [menu addItem:header];
    }
    for (EKCalendar *cal in cloud) {
        [menu addItem:[self menuItemForCalendar:cal]];
    }
    EKEvent *event = (EKEvent *)self.representedObject;
    NSInteger sel = [menu indexOfItemWithRepresentedObject:event.calendar];
    [self.calendarPopup selectItemAtIndex:sel];
}

- (IBAction)addEvent:(id)sender
{
    [self checkEventStoreAccess];
    [self.popover close];
}

- (IBAction)cancel:(id)sender
{
    [self.popover close];
}


// Check the authorization status of our application for Calendar 
-(void)checkEventStoreAccess
{
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
 
    switch (status)
    {
        // Update our UI if the user has granted access to their Calendar
        case EKAuthorizationStatusAuthorized:
            [self saveCalendarEvent];
            break;
        // Prompt the user for access to Calendar if there is no definitive answer
        case EKAuthorizationStatusNotDetermined:
            [self requestCalendarAccess];
            break;
        // Display a message if the user has denied or restricted access to Calendar
        case EKAuthorizationStatusDenied:
        case EKAuthorizationStatusRestricted:
        {
//            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Privacy Warning" message:@"Permission was not granted for Calendar"
//                                                                    preferredStyle:UIAlertControllerStyleAlert];
//            
//            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
//                                                                    style:UIAlertActionStyleDefault
//                                                                  handler:^(UIAlertAction * action) {}];
//            [alert addAction:defaultAction];
//            [self presentViewController:alert animated:YES completion:nil];
        }
            break;
        default:
            break;
    }
}

// This method is called when the user has granted permission to Calendar
-(void)saveCalendarEvent
{
	EKEvent *event = [self representedObject];
    event.calendar = [[self.calendarPopup selectedItem] representedObject];
    NSError *error;
    if (![self.eventStore saveEvent:event span:EKSpanThisEvent commit:YES error:&error]) {
        NSLog(@"%@", error);
    }
}

// Prompt the user for access to their Calendar
-(void)requestCalendarAccess
{
    [self.eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error)
    {
         if (granted) {
             XTCalendarEventViewController * __weak weakSelf = self;
             // Let's ensure that our code will be executed from the main queue
             dispatch_async(dispatch_get_main_queue(), ^{
                // The user has granted access to their Calendar.
                [weakSelf saveCalendarEvent];
             });
         }
     }];
}

@end
