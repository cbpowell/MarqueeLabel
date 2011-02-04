//
//  MarqueeLabel.m
//  
//
//  Created by Charles Powell on 1/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MarqueeLabel.h"


@implementation MarqueeLabel

@synthesize subLabel;
@synthesize baseLabelFrame;

@dynamic adjustsFontSizeToFitWidth, text, lineBreakMode, numberOfLines;

// Pass through properties
@dynamic baselineAdjustment, enabled, font, highlighted, highlightedTextColor, minimumFontSize;
@dynamic shadowColor, shadowOffset, textAlignment, textColor, userInteractionEnabled;

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code.
        
        // Set the containing MarqueeLabel view to clip it's interior, and have a clear background
        [self setClipsToBounds:YES];
        self.backgroundColor = [UIColor clearColor];
        
        // Create sublabel
        initialLabelFrame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
        self.subLabel = [[UILabel alloc] initWithFrame:initialLabelFrame];
        [self addSubview:subLabel];
        [subLabel release];
        
    }
    return self;
}

- (void)scrollWithLoop:(BOOL)loop andSpeed:(NSInteger)speed {
    
    // Get the label size based on text
    CGSize maximumLabelSize = CGSizeMake(1200, 9999);
    CGSize expectedLabelSize = [subLabel.text sizeWithFont:subLabel.font
                                         constrainedToSize:maximumLabelSize
                                             lineBreakMode:subLabel.lineBreakMode];
    
    CGRect newLabelFrame = subLabel.frame;
    newLabelFrame.size.width = expectedLabelSize.width;
    subLabel.frame = newLabelFrame;
    
    [self scrollLeft];
}
    
    

- (void)scrollLeft {
    
    // Get the start frame
    CGRect startSubLabelFrame = subLabel.frame;
    // Calculate the final frame
    startSubLabelFrame.origin.x = self.frame.size.width - subLabel.frame.size.width;
    
    [UIView animateWithDuration:7.0
                          delay:0.1 
                        options:UIViewAnimationCurveEaseInOut 
                     animations:^{
                         subLabel.frame = startSubLabelFrame;
                     }
                     completion:^(BOOL finished){
                         //NSLog(@"Done animating subLabel to the left");
                         [self scrollRight];
                     }];
}

- (void)scrollRight {
    
    [UIView animateWithDuration:7.0
                          delay:0.1 
                        options:UIViewAnimationCurveEaseInOut 
                     animations:^{
                         subLabel.frame = baseLabelFrame;
                     }
                     completion:^(BOOL finished){
                         //NSLog(@"Finished animating right");
                         [self scrollLeft];
                     }];
}
    

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code.
}
*/

#pragma mark -
#pragma mark UILabel Message Forwarding

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSLog(@"Method sig");
    return [UILabel instanceMethodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"forwarding");
    if ([subLabel respondsToSelector:[anInvocation selector]]) {
        [anInvocation invokeWithTarget:subLabel];
    } else {
        NSLog(@"MarqueeLabel does not recognize the selector");
        [super forwardInvocation:anInvocation];
    }
}

- (id)valueForUndefinedKey:(NSString *)key {
    return [subLabel valueForKey:key];
}

- (void) setValue:(id)value forUndefinedKey:(NSString *)key {
    [subLabel setValue:value forKey:key];
}

- (void)dealloc {
    [subLabel release];
    [super dealloc];
}


@end
