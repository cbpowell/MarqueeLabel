
//
//  MarqueeLabel.h
//  

#import <UIKit/UIKit.h>

// MarqueeLabel types
typedef enum {
    MLLeftRight = 0,        // Scrolls left first, then back right to the original position
    MLRightLeft,            // Scrolls right first, then back left to the original position
    MLContinuous,           // Continuously scrolls left (with a pause at the original position if animationDelay is set)
    MLContinuousReverse     // Continuously scrolls right (with a pause at the original position if animationDelay is set)
} MarqueeType;

@interface MarqueeLabel : UILabel

// MarqueeLabel-specific properties

/* animationCurve:
 * The animation curve used in the motion of the labels.
 *  Allowable options:
 *      UIViewAnimationOptionCurveEaseInOut
 *      UIViewAnimationOptionCurveEaseIn
 *      UIViewAnimationOptionCurveEaseOut
 *      UIViewAnimationOptionCurveLinear
 *
 * Default is UIViewAnimationOptionCurveEaseInOut.
 */
@property (nonatomic, assign) UIViewAnimationOptions animationCurve;


/* awayFromHome:
 * Returns if the label is away from "home", the location where it would be if
 * it were a normal UILabel (although it does take into account the fade lengths,
 * in that "home" is offset by those in order for the edge of the labels not to be
 * faded when at the home location.
 */
@property (nonatomic, assign, readonly) BOOL awayFromHome;


/* labelize:
 * When set to YES, the MarqueeLabel will not scroll and will behave like a normal UILabel
 * Defaults to NO.
 * See also: holdScrolling
 */
@property (nonatomic, assign) BOOL labelize;


/* holdScrolling:
 * When set to YES, the MarqueeLabel will not scroll but will not otherwise adjust normal operation
 * or truncate text. Any in-progress animations will complete when this is set to YES.
 * The labelize property supercedes this setting.
 * Defaults to NO.
 * See also: labelize
 */
@property (nonatomic, assign) BOOL holdScrolling;


/* marqueeType:
 * When set to LeftRight, the label moves from left to right and back from right to left alternatively.
 *
 *      NOTE: LeftRight type is ONLY compatible with a label text alignment of UITextAlignmentLeft. Specifying
 *      LeftRight will change any previously set, non-compatible text alignment to UITextAlignmentLeft.
 *
 * When set to RightLeft, the label moves from right to left and back from left to right alternatively.
 *
 *      NOTE: RightLeft type is ONLY compatibile with a label text alignment of UITextAlignmentRight. Specifying
 *      RightLeft will change any previously set, non-compatible text alignment to UITextAlignmentRight.
 *
 * When set to Continuous, the label slides continuously to the left.
 *
 *      NOTE: MLContinuous does support any text alignment, but will always scroll left.
 *
 * Defaults to LeftRight.
 */
@property (nonatomic, assign) MarqueeType marqueeType;


/* continuousMarqueeExtraBuffer:
 * Sets an additional amount (in points) of space between the strings of a
 * continuous label. The minimum spacing is 2x the fade length, and can be increased
 * by adjusting this value.
 * Defaults to 0.0;
 */
@property (nonatomic, assign) CGFloat continuousMarqueeExtraBuffer;


/* fadeLength:
 * Sets the length of fade (from alpha 1.0 to alpha 0.0) at the edges of the
 * MarqueeLabel. Cannot be larger than 1/2 of the frame width (will be santized).
 */
@property (nonatomic, assign) CGFloat fadeLength;


/* animationDelay:
 * Sets how long the label pauses at the "origin" position between scrolling
 */
@property (nonatomic, assign) CGFloat animationDelay;


/* tapToScroll:
 * If YES, when tapped the label will scroll through its cycle once.
 * NOTE: The label will not automatically scroll if this is set to YES!
 * Defaults to NO.
 */
@property (nonatomic, assign) BOOL tapToScroll;


// Read-only properties for state
@property (nonatomic, assign, readonly) BOOL isPaused;


// Class Methods
+ (void)controllerViewAppearing:(UIViewController *)controller;
+ (void)controllerLabelsShouldLabelize:(UIViewController *)controller;
+ (void)controllerLabelsShouldAnimate:(UIViewController *)controller;

// Methods
- (id)initWithFrame:(CGRect)frame rate:(CGFloat)pixelsPerSec andFadeLength:(CGFloat)fadeLength;
- (id)initWithFrame:(CGRect)frame duration:(NSTimeInterval)lengthOfScroll andFadeLength:(CGFloat)fadeLength;

/* Use this method to resize a MarqueeLabel to the minimum possible size, accounting
 * for fade length, for the current text while constrained to the maxSize provided. Use
 * CGSizeZero for maxSize to indicate an unlimited size.
 */
- (void)minimizeLabelFrameWithMaximumSize:(CGSize)maxSize adjustHeight:(BOOL)adjustHeight;

- (void)restartLabel;
- (void)resetLabel;

- (void)pauseLabel;
- (void)unpauseLabel;

@end


