//FaceExpression.mm

#import "FaceExpression.h"

#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPLayerRenderer.h"
#import "mediapipe/objc/MPPPlayerInputSource.h"

#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/util/cpu_util.h"

static NSString* const kGraphName = @"face_mesh_mobile_gpu";

static const char* kNumFacesInputSidePacket = "num_faces";
static const char* kLandmarksOutputStream = "multi_face_landmarks";

// Max number of faces to detect/process.
static const int kNumFaces = 1;

#define AVG_CNT         10
#define DETECT_TIMES    2
#define POINT_NUM       4  //输入线性拟和点

static double brow_width_arr[AVG_CNT];
static double brow_height_arr[AVG_CNT];
static double brow_line_arr[AVG_CNT];
static double brow_mouth_arr[AVG_CNT];
static double brow_height_mouth_arr[AVG_CNT];
static double eye_height_arr[AVG_CNT];
static double eye_width_arr[AVG_CNT];
static double eye_height_mouth_arr[AVG_CNT];
static double mouth_width_arr[AVG_CNT];
static double mouth_height_arr[AVG_CNT];
static double mouth_pull_down_arr[AVG_CNT];
static int arr_cnt = 0;
static int normal_times = 0, suprise_times = 0, sad_times = 0, happy_times = 0, angry_times = 0;
static int total_log_cnt = 0;

@interface FaceExpression() <MPPGraphDelegate>

@end

@implementation FaceExpression {}

- (void)initialize {
    [self.mediapipeGraph setSidePacket:(mediapipe::MakePacket<int>(kNumFaces))
                                 named:kNumFacesInputSidePacket];
    [self.mediapipeGraph addFrameOutputStream:kLandmarksOutputStream
                             outputPacketType:MPPPacketTypeRaw];
}

- (void)startCamera {

}

#pragma mark - MPPGraphDelegate methods
// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph didOutputPacket:(const ::mediapipe::Packet&)packet fromStream:(const std::string&)streamName {

}

/**
 四舍五入字符串
 @param round 小数位 eg: 4
 @param numberString 数字 eg 0.125678
 @return 四舍五入之后的 eg: 0.1257
 */
- (double)getRound:(double)val Num:(int)round {
    NSString* valString = [NSString stringWithFormat:@"%f", val];
    if (valString == nil) {
        return 0;
    }
    NSDecimalNumberHandler *roundingBehavior    = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundPlain scale:round raiseOnExactness:NO raiseOnOverflow:NO raiseOnUnderflow:NO raiseOnDivideByZero:NO];
    NSDecimalNumber *aDN                        = [[NSDecimalNumber alloc] initWithString:valString];
    NSDecimalNumber *resultDN                   = [aDN decimalNumberByRoundingAccordingToBehavior:roundingBehavior];
    return resultDN.doubleValue;
}

@end
