/*
 *  XTUtils.mm
 *  XTideCocoa
 *
 *  Created by Lee Ann Rucker on 4/13/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#import "TargetConditionals.h" 
#if TARGET_OS_IPHONE
   #import <UIKit/UIKit.h>
#else
   #import <Cocoa/Cocoa.h>
#endif

#import "libxtide.hh"
#import "XTUtils.h"

NSString *
DstrToNSString(const Dstr &s)
{
   return [NSString stringWithCString:s.aschar()
                             encoding:NSISOLatin1StringEncoding];
}

NSDate *
TimestampToNSDate(const libxtide::Timestamp t)
{
   return [NSDate dateWithTimeIntervalSince1970:t.timet()];
}


// Output error message and die.
/*
 * Yes, this is bad iOS/Mac behavior, but it's called from the common code.
 * However I've only hit it in early development, when the common code
 * adds features I don't have yet. There's no iOS terminate, so if this does
 * hit a user, I have no idea what happens after that.
 */
void DisplayFatalError(NSString *errorString)
{
    NSLog(@"Fatal Error: %@", errorString);
#if TARGET_OS_IPHONE
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Unexpected problem occurred"
                                   message:errorString
                                   preferredStyle:UIAlertControllerStyleAlert];
     
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
       handler:^(UIAlertAction * action) {}];
     
    [alert addAction:defaultAction];
   // TODO: [self presentViewController:alert animated:YES completion:nil];
#else
   NSAlert *alert = [[NSAlert alloc] init];
   [alert setMessageText:@"Unexpected problem occurred"];
   [alert setInformativeText:errorString];
   [alert runModal];
   [NSApp terminate:nil];
#endif
}
