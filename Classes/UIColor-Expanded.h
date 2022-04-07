// FROM: http://github.com/ars/uicolor-utilities/blob/master//UIColor-Expanded.h

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#endif

#define SUPPORTS_UNDOCUMENTED_API 0

@interface FCColor (UIColor_Expanded)

@property (nonatomic, readonly) CGColorSpaceModel colorSpaceModel;
@property (nonatomic, readonly) BOOL canProvideRGBComponents;
@property (nonatomic, readonly) CGFloat red; // Only valid if canProvideRGBComponents is YES
@property (nonatomic, readonly) CGFloat green; // Only valid if canProvideRGBComponents is YES
@property (nonatomic, readonly) CGFloat blue; // Only valid if canProvideRGBComponents is YES
@property (nonatomic, readonly) CGFloat white; // Only valid if colorSpaceModel == kCGColorSpaceModelMonochrome
@property (nonatomic, readonly) CGFloat alpha;
@property (nonatomic, readonly) UInt32 rgbHex;

- (NSString *)colorSpaceString;

- (NSArray *)arrayFromRGBAComponents;

- (BOOL)red:(CGFloat *)r green:(CGFloat *)g blue:(CGFloat *)b alpha:(CGFloat *)a;

- (FCColor *)colorByLuminanceMapping;

- (FCColor *)colorByMultiplyingByRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
- (FCColor *) colorByAddingRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
- (FCColor *) colorByLighteningToRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
- (FCColor *) colorByDarkeningToRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;

- (FCColor *)colorByMultiplyingBy:(CGFloat)f;
- (FCColor *) colorByAdding:(CGFloat)f;
- (FCColor *) colorByLighteningTo:(CGFloat)f;
- (FCColor *) colorByDarkeningTo:(CGFloat)f;

- (FCColor *)colorByMultiplyingByColor:(FCColor *)color;
- (FCColor *) colorByAddingColor:(FCColor *)color;
- (FCColor *) colorByLighteningToColor:(FCColor *)color;
- (FCColor *) colorByDarkeningToColor:(FCColor *)color;

- (NSString *)stringFromColor;
- (NSString *)hexStringFromColor;

+ (FCColor *)randomColor;
+ (FCColor *)colorWithString:(NSString *)stringToConvert;
+ (FCColor *)colorWithRGBHex:(UInt32)hex;
+ (FCColor *)colorWithHexString:(NSString *)stringToConvert;

+ (FCColor *)colorWithName:(NSString *)cssColorName;

@end

#if SUPPORTS_UNDOCUMENTED_API
// UIColor_Undocumented_Expanded
// Methods which rely on undocumented methods of UIColor
@interface UIColor (UIColor_Undocumented_Expanded)
- (NSString *)fetchStyleString;
- (UIColor *)rgbColor; // Via Poltras
@end
#endif // SUPPORTS_UNDOCUMENTED_API

