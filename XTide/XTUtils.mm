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


// Display error message.
// This comes from common code and I've only seen it when there are new features I haven't
// implemented yet, so I'm not even installing it on iOS.
// If it means the app dies with no notice, that's not terrible. iOS apps do that.
void DisplayCoreError(const Dstr &errorDstr, libxtide::Error::ErrType fatality)
{
    NSString *errorString = DstrToNSString(errorDstr);
    NSLog(@"Fatal Error: %@", errorString);
#if TARGET_OS_IPHONE
//    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Unexpected problem occurred"
//                                   message:errorString
//                                   preferredStyle:UIAlertControllerStyleAlert];
//     
//    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
//       handler:^(UIAlertAction * action) {}];
//     
//    [alert addAction:defaultAction];
   // TODO: [self presentViewController:alert animated:YES completion:nil];
#else
   NSAlert *alert = [[NSAlert alloc] init];
   [alert setMessageText:@"Unexpected problem occurred"];
   [alert setInformativeText:errorString];
   [alert runModal];
#endif
}


@implementation NSString (DStr)

- (Dstr)asDstr {
    return Dstr([self cStringUsingEncoding:NSISOLatin1StringEncoding]);
}

@end
