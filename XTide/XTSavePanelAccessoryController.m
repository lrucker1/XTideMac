//
//  XTSavePanelAccessoryController.m
//  XTide
//
//  Created by Lee Ann Rucker on 8/15/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "XTSavePanelAccessoryController.h"

@interface XTSavePanelAccessoryController ()

@end

@implementation XTSavePanelAccessoryController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
    [self setWritableTypes:[[self savePanel] allowedFileTypes]];
}

- (NSString *)displayNameForExt:(NSString *)ext
{
    if ([ext isEqualToString:@"txt"]) return NSLocalizedString(@"Plain text", @"plain text");

    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL);
    return (__bridge NSString *)UTTypeCopyDescription(uti);
}

- (void)setWritableTypes:(NSArray *)typeExtensions
{
    NSMenu *menu = [self.fileTypesButton menu];
    [menu removeAllItems];
    for (NSString *ext in typeExtensions) {

        NSString *displayName = [self displayNameForExt:ext];
        NSString *fullName = [NSString stringWithFormat:@"%@ (*.%@)", displayName, ext];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:fullName action:NULL keyEquivalent:@""];
        [item setRepresentedObject:ext];
        [menu addItem:item];
    }
}

- (IBAction)selectFormat:(id)sender
{
    NSPopUpButton *button                 = (NSPopUpButton *)sender;
    NSString      *nameFieldString        = [[self savePanel] nameFieldStringValue];
    NSString      *trimmedNameFieldString = [nameFieldString stringByDeletingPathExtension];
    NSString      *extension = [[button selectedItem] representedObject];

    NSString *nameFieldStringWithExt = [NSString stringWithFormat:@"%@.%@", trimmedNameFieldString, extension];
    [[self savePanel] setNameFieldStringValue:nameFieldStringWithExt];

    // If the Finder Preference "Show all filename extensions" is false or the
    // panel's extensionHidden property is YES (the default), then the
    // nameFieldStringValue will not include the extension we just changed/added.
    // So, in order to ensure that the panel's URL has the extension we've just
    // specified, the workaround is to restrict the allowed file types to only
    // the specified one.
    [[self savePanel] setAllowedFileTypes:@[extension]];
}

@end
