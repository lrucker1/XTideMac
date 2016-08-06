//
//  UIView_UIViewAdditions.m
//  XTide
//
//  Created by Lee Ann Rucker on 8/4/16.
//  Copyright © 2016 Lee Ann Rucker. All rights reserved.
//

#import "UIView_UIViewAdditions.h"

@implementation UIView (UIViewAdditions)

- (void)setSubviewWithPinnedConstraints:(UIView *)subview
{
    for (UIView *view in self.subviews) {
        [view removeFromSuperview];
    }
    [self addSubview:subview];
    subview.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary *views = NSDictionaryOfVariableBindings(subview);
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[subview]|"
                                             options:NSLayoutFormatAlignAllTop
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[subview]|"
                                             options:NSLayoutFormatAlignAllLeading
                                             metrics:nil
                                               views:views]];
}

@end