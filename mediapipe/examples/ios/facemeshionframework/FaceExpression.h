//FaceExpression.h

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

#define FACE_EXPRESSION_UNKNOW      0
#define FACE_EXPRESSION_HAPPY       1
#define FACE_EXPRESSION_SURPRISE    2
#define FACE_EXPRESSION_CRY         3
#define FACE_EXPRESSION_NATURE      4
#define FACE_EXPRESSION_SAD         5
#define FACE_EXPRESSION_ANGRY       6
#define FACE_EXPRESSION_NERVOUS     7
#define FACE_EXPRESSION_HEADFALSE   8

@class Landmark;
@class FaceExpression;

@protocol FaceExpressionDelegate <NSObject>
- (void)faceExpression: (FaceExpression*)faceExpression didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
- (void)faceExpression: (FaceExpression*)faceExpression Type:(int)type;
@optional
- (void)faceExpression: (FaceExpression*)faceExpression didOutputLandmarks: (NSArray<Landmark *> *)landmarks;
@end

@interface FaceExpression: NSObject

@property (weak, nonatomic)id<FaceExpressionDelegate> delegate;

- (instancetype)init;

- (void)startGraph;

- (void)processGraph;

- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer;

- (double)getRound:(double)val Num:(int)round;

@end

@interface Landmark: NSObject

@property(nonatomic, readonly) float x;

@property(nonatomic, readonly) float y;

@property(nonatomic, readonly) float z;

@end

