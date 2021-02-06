#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

#define HAND_UNKNOWN   (-1)
#define HAND_FIST      (0)
#define HAND_THUMB     (1)
#define HAND_INDEX     (2)
#define HAND_MIDDLE    (3)
#define HAND_RING      (4)
#define HAND_PINKY     (5)
#define HAND_FINGER1   (6)
#define HAND_FINGER2   (7)
#define HAND_FINGER3   (8)
#define HAND_FINGER4   (9)
#define HAND_FINGER5   (10)
#define HAND_FINGER6   (11)
#define HAND_OK        (12)
#define HAND_YEAH      (13)
#define HAND_WONDERFUL (14)
#define HAND_SPIDERMAN (15)

@class Landmark;
@class HandTracker;

@protocol HandTrackerDelegate <NSObject>
- (void)handTracker: (HandTracker*)handTracker didOutputLandmarks: (NSArray<Landmark *> *)landmarks;
- (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer;
- (void)handTracker: (HandTracker*)handTracker Type:(int)type Name:(NSString*)name;
@end

@interface HandTracker : NSObject
- (instancetype)init;
- (void)startGraph;
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer;
@property (weak, nonatomic) id <HandTrackerDelegate> delegate;
@end

@interface Landmark: NSObject
@property(nonatomic, readonly) float x;
@property(nonatomic, readonly) float y;
@property(nonatomic, readonly) float z;
@end
