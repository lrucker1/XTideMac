//
//  XTErrors.mm
//  XTideCocoa
//
//  Created by Lee Ann Rucker on 4/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "XTErrors.h"


@implementation XTErrors

// Output error message and die.
- (void)displayError: (NSString *)details
{
   NSAlert *alert = [[NSAlert alloc] init];
   [alert setMessageText:@"Fatal Error"];
   [alert setInformativeText:details];
   [alert runModal];
   [NSApp terminate:nil];
}

@end
