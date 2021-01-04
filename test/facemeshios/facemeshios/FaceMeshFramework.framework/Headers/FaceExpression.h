//FaceExpression.h

#import <UIKit/UIKit.h>

//#import "mediapipe/examples/ios/common/CommonViewController.h"

@class FaceExpression;

@protocol FaceExpressionDelegate <NSObject>
- (void)faceExpression:(FaceExpression*)faceExpression Type:(int)type;
@end

@interface FaceExpression: NSObject

//@property (weak, nonatomic)id<FaceExpressionDelegate> delegate;

- (void)initialize:(UIView*)preview;

- (void)startCamera;

- (double)getRound:(double)val Num:(int)round;

@end

