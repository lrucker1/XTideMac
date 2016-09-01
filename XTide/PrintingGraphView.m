//
//  PrintingGraphView.m
//  XTide
//
//  Created by Lee Ann Rucker on 8/12/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "PrintingGraphView.h"
#import "PrintPanelAccessoryController.h"

@implementation PrintingGraphView


NSSize pageSizeForPrintInfo(NSPrintInfo *printInfo) {
    NSSize paperSize = [printInfo paperSize];
    paperSize.width -= ([printInfo leftMargin] + [printInfo rightMargin]);
    paperSize.height -= ([printInfo topMargin] + [printInfo bottomMargin]);
    return paperSize;
}

@synthesize printPanelAccessoryController, originalSize;

- (BOOL)knowsPageRange:(NSRangePointer)range {
    NSSize documentSizeInPage = pageSizeForPrintInfo([self.printPanelAccessoryController representedObject]);
    BOOL wrappingToFit = self.printPanelAccessoryController.wrappingToFit;
    
    if (!NSEqualSizes(previousValueOfDocumentSizeInPage, documentSizeInPage) || (previousValueOfWrappingToFit != wrappingToFit)) {
        previousValueOfDocumentSizeInPage = documentSizeInPage;
        previousValueOfWrappingToFit = wrappingToFit;
        
        NSSize size = wrappingToFit ? documentSizeInPage : self.originalSize;
        [self setFrame:NSMakeRect(0.0, 0.0, size.width, size.height)];
    }
    return [super knowsPageRange:range];
}

@end
