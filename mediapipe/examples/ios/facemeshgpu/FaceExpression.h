//FaceExpression.h

#import <UIKit/UIKit.h>

#import "mediapipe/examples/ios/common/CommonViewController.h"

@class FaceExpression;

@protocol FaceExpressionDelegate <NSObject>
- (void)faceExpression:(FaceExpression*)faceExpression Type:(int)type;
@end

@interface FaceExpression

// The MediaPipe graph currently in use. Initialized in viewDidLoad, started in
// viewWillAppear: and sent video frames on videoQueue.
@property(nonatomic) MPPGraph* mediapipeGraph;

- (double)getRound:(double)val Num:(int)round;

- (void)initialize;

- (void)startCamera;

@end