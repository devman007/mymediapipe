//FaceExpression.mm

#import "FaceExpression.h"

#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPLayerRenderer.h"
#import "mediapipe/objc/MPPPlayerInputSource.h"

#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/util/cpu_util.h"

// typedef NS_ENUM(NSInteger, MediaPipeDemoSourceMode) {
//   MediaPipeDemoSourceCamera,
//   MediaPipeDemoSourceVideo
// };

@interface FaceExpression() <MPPGraphDelegate/*, MPPInputSourceDelegate*/>
// The MediaPipe graph currently in use. Initialized in viewDidLoad, started in
// viewWillAppear: and sent video frames on videoQueue.
@property(nonatomic) MPPGraph* mediapipeGraph;
//// Handles camera access via AVCaptureSession library.
//@property(nonatomic) MPPCameraInputSource* cameraSource;
//// Provides data from a video.
//@property(nonatomic) MPPPlayerInputSource* videoSource;
// The data source for the demo.
// @property(nonatomic) MediaPipeDemoSourceMode sourceMode;
//// Inform the user when camera is unavailable.
//@property(nonatomic) IBOutlet UILabel* noCameraLabel;
//
//// Display the camera preview frames.
//@property(strong, nonatomic) IBOutlet UIView* liveView;
//// Render frames in a layer.
//@property(nonatomic) MPPLayerRenderer* renderer;
// Process camera frames on this queue.
@property(nonatomic) dispatch_queue_t videoQueue;
//// Graph name.
//@property(nonatomic) NSString* graphName;
//// Graph input stream.
//@property(nonatomic) const char* graphInputStream;
//// Graph output stream.
//@property(nonatomic) const char* graphOutputStream;

@end

@interface Landmark()
- (instancetype)initWithX:(float)x y:(float)y z:(float)z;
@end

#define AVG_CNT         10
#define DETECT_TIMES    2
#define POINT_NUM       4  //输入线性拟和点

static NSString* const kGraphName = @"face_mesh_mobile_gpu";
static const char* kNumFacesInputSidePacket = "num_faces";
static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kLandmarksOutputStream = "multi_face_landmarks";
static const char* kVideoQueueLabel = "com.google.mediapipe.example.videoQueue";
// Max number of faces to detect/process.
static const int kNumFaces = 1;

static double face_width_arr[AVG_CNT];
static double face_height_arr[AVG_CNT];
static double face_ratio_arr[AVG_CNT];
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
static double dis_eye_mouth_arr[AVG_CNT];
static int arr_cnt = 0;
static int normal_times = 0, suprise_times = 0, sad_times = 0, happy_times = 0, angry_times = 0;
static int total_log_cnt = 0;

@implementation FaceExpression {}

- (instancetype)init {
    self = [super init];
    if(self) {
//    //for uiview used
//    NSLog(@"%s, %d, preview(%x)\n", __FUNCTION__, __LINE__, preview);
//    self.renderer = [[MPPLayerRenderer alloc] init];
//    self.renderer.layer.frame = preview.layer.bounds;
//    [preview.layer addSublayer:self.renderer.layer];
//    self.renderer.frameScaleMode = MPPFrameScaleModeFillAndCrop;
//
    dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, /*relative_priority=*/0);
    self.videoQueue = dispatch_queue_create(kVideoQueueLabel, qosAttribute);
//    NSLog(@"%s, %d, videoQueue(%x)\n", __FUNCTION__, __LINE__, self.videoQueue);
//    self.graphName = kGraphName;//[[NSBundle mainBundle] objectForInfoDictionaryKey:@"GraphName"];
//    self.graphInputStream =
//        [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"GraphInputStream"] UTF8String];
//    self.graphOutputStream =
//        [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"GraphOutputStream"] UTF8String];
//    NSLog(@"%s, %d, graphName(%s)\n", __FUNCTION__, __LINE__, self.graphName);
    self.mediapipeGraph = [[self class] loadGraphFromResource:kGraphName];
    [self.mediapipeGraph addFrameOutputStream:kOutputStream
                             outputPacketType:MPPPacketTypePixelBuffer];
    [self processGraph];
    self.mediapipeGraph.delegate = self;
    // Set maxFramesInFlight to a small value to avoid memory contention for real-time processing.
//    self.mediapipeGraph.maxFramesInFlight = 2;
//    NSLog(@"%s, %d, mediapipeGraph(%x)\n", __FUNCTION__, __LINE__, self.mediapipeGraph);
//    //for camera used
//    self.cameraSource = [[MPPCameraInputSource alloc] init];
//    [self.cameraSource setDelegate:self queue:self.videoQueue];
//    self.cameraSource.sessionPreset = AVCaptureSessionPresetHigh;
//    NSLog(@"%s, %d, cameraSource(%x)\n", __FUNCTION__, __LINE__, self.cameraSource);
//    NSString* cameraPosition =
//        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CameraPosition"];
//    if (cameraPosition.length > 0 && [cameraPosition isEqualToString:@"back"]) {
//      self.cameraSource.cameraPosition = AVCaptureDevicePositionBack;
//    } else {
//      self.cameraSource.cameraPosition = AVCaptureDevicePositionFront;
//      // When using the front camera, mirror the input for a more natural look.
//      _cameraSource.videoMirrored = YES;
//    }
//
//    // The frame's native format is rotated with respect to the portrait orientation.
//    _cameraSource.orientation = AVCaptureVideoOrientationPortrait;
//
//    [self.cameraSource requestCameraAccessWithCompletionHandler:^void(BOOL granted) {
//      if (granted) {
//        [self startCamera];
////        dispatch_async(dispatch_get_main_queue(), ^{
////          self.noCameraLabel.hidden = YES;
////        });
//      }
//    }];
//    NSLog(@"%s, %d, end\n", __FUNCTION__, __LINE__);
    }
    return self;
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

- (double)getDistancd3DwithX1:(double)x1 Y1:(double)y1 Z1:(double)z1 X2:(double)x2 Y2:(double)y2 Z2:(double)z2 {
    POINTS start, end;
    start.x = x1;
    start.y = y1;
    start.z = z1;
    end.x = x2;
    end.y = y2;
    end.z = z2;
    double ret = ::mediapipe::getDistance3D(start, end);
    
    return fabs(ret);
}

#pragma mark - Cleanup methods

- (void)dealloc {
  self.mediapipeGraph.delegate = nil;
  [self.mediapipeGraph cancel];
  // Ignore errors since we're cleaning up.
  [self.mediapipeGraph closeAllInputStreamsWithError:nil];
  [self.mediapipeGraph waitUntilDoneWithError:nil];
}

#pragma mark - MediaPipe graph methods

+ (MPPGraph*)loadGraphFromResource:(NSString*)resource {
    // Load the graph config resource.
//    NSLog(@"%s, %d, resource(%s)\n", __FUNCTION__, __LINE__, resource);
    NSError* configLoadError = nil;
    NSBundle* bundle = [NSBundle bundleForClass:[self class]];
    if (!resource || resource.length == 0) {
        return nil;
    }
    NSURL* graphURL = [bundle URLForResource:resource withExtension:@"binarypb"];
    NSData* data = [NSData dataWithContentsOfURL:graphURL options:0 error:&configLoadError];
    if (!data) {
        NSLog(@"Failed to load MediaPipe graph config: %@", configLoadError);
        return nil;
    }
//    NSLog(@"%s, %d, graphURL(%s)\n", __FUNCTION__, __LINE__, graphURL);
    // Parse the graph config resource into mediapipe::CalculatorGraphConfig proto object.
    mediapipe::CalculatorGraphConfig config;
    config.ParseFromArray(data.bytes, data.length);

    // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
    MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];
    [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
    [newGraph addFrameOutputStream:kLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];
//    NSLog(@"%s, %d, newGraph(%x)\n", __FUNCTION__, __LINE__, newGraph);
    return newGraph;
}

- (void)startGraph {
    // Start running self.mediapipeGraph.
    NSError* error;
    if (![self.mediapipeGraph startWithError:&error]) {
        NSLog(@"Failed to start graph: %@", error);
    }

//    // Start fetching frames from the camera.
//    dispatch_async(self.videoQueue, ^{
//        [self.cameraSource start];
//    });
}

- (void)processGraph {
    [self.mediapipeGraph setSidePacket:(mediapipe::MakePacket<int>(kNumFaces))
                                 named:kNumFacesInputSidePacket];
    [self.mediapipeGraph addFrameOutputStream:kLandmarksOutputStream
                             outputPacketType:MPPPacketTypeRaw];
}

//#pragma mark - MPPInputSourceDelegate methods

// Must be invoked on self.videoQueue.
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer
                /*timestamp:(CMTime)timestamp
               fromSource:(MPPInputSource*)source*/ {
//    if (source != self.cameraSource && source != self.videoSource) {
//        NSLog(@"Unknown source: %@", source);
//        return;
//    }

    [self.mediapipeGraph sendPixelBuffer:imageBuffer
                              intoStream:kInputStream
                              packetType:MPPPacketTypePixelBuffer];
}

#pragma mark - MPPGraphDelegate methods

// Receives CVPixelBufferRef from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
  didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer
            fromStream:(const std::string&)streamName {
    
    if (streamName == kOutputStream) {
//        // Display the captured image on the screen.
//        CVPixelBufferRetain(pixelBuffer);
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [self.renderer renderPixelBuffer:pixelBuffer];
//            CVPixelBufferRelease(pixelBuffer);
//        });
        [_delegate faceExpression:self didOutputPixelBuffer: pixelBuffer];
    }
}

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const ::mediapipe::Packet&)packet
            fromStream:(const std::string&)streamName {
    if (streamName == kLandmarksOutputStream) {
       if (packet.IsEmpty()) {
          NSLog(@"[TS:%lld] No face landmarks", packet.Timestamp().Value());
          return;
       }
       const auto& multi_face_landmarks = packet.Get<std::vector<::mediapipe::NormalizedLandmarkList>>();
#if 0
        NSMutableArray<Landmark *> *result = [NSMutableArray array];
        const auto& landmarks = multi_face_landmarks[0];
        for (int i = 0; i < landmarks.landmark_size(); ++i) {
            Landmark *landmark = [[Landmark alloc] initWithX:landmarks.landmark(i).x()
                                                           y:landmarks.landmark(i).y()
                                                           z:landmarks.landmark(i).z()];
            [result addObject:landmark];
        }
        [_delegate faceExpression:self didOutputLandmarks: result];
#else
//    NSLog(@"[TS:%lld] Number of face instances with landmarks: %lu", packet.Timestamp().Value(),
//          multi_face_landmarks.size());
        int face_index = 0;
     /*for (int face_index = 0; face_index < multi_face_landmarks.size(); ++face_index)*/ {
        const auto& landmarks = multi_face_landmarks[face_index];
//      NSLog(@"\tNumber of landmarks for face[%d]: %d", face_index, landmarks.landmark_size());
//        for (int i = 0; i < landmarks.landmark_size(); ++i) {
//            NSLog(@"\t\tLandmark[%d]: (%f, %f, %f)", i, landmarks.landmark(i).x(),
//                  landmarks.landmark(i).y(), landmarks.landmark(i).z());
//        }
//        for (int i = 0; i < landmarkList.getLandmarkCount(); i++) {
//            faceLandmarksStr  += "\t\tLandmark ["
//                                + i + "], "
//                                + landmarks.landmark(i).x() + ", "
//                                + landmarks.landmark(i).y() + ", "
//                                + landmarks.landmark(i).z() + ")\n";
//            Log.i(TAG, faceLandmarksStr);
//        }
            // 1、计算人脸识别框边长(注: 脸Y坐标 下 > 上, X坐标 右 > 左)
//            double face_width = fabs(landmarks.landmark(361).x() - landmarks.landmark(132).x());
         double face_width = [self getDistancd3DwithX1:landmarks.landmark(361).x() Y1:landmarks.landmark(361).y() Z1:landmarks.landmark(361).z()
                                                    X2:landmarks.landmark(132).x() Y2:landmarks.landmark(132).y() Z2:landmarks.landmark(132).z()];
//            double face_height = fabs(landmarks.landmark(152).y() - landmarks.landmark(10).y());
         double face_height = [self getDistancd3DwithX1:landmarks.landmark(152).x() Y1:landmarks.landmark(152).y() Z1:landmarks.landmark(152).z()
                                                     X2:landmarks.landmark(10).x() Y2:landmarks.landmark(10).y() Z2:landmarks.landmark(10).z()];
            double face_ratio = fabs((landmarks.landmark(133).y() - landmarks.landmark(362).y())/(landmarks.landmark(133).x() - landmarks.landmark(362).x()));

            //2、眉毛宽度(注: 脸Y坐标 下 > 上, X坐标 右 > 左 眉毛变短程度: 皱变短(恐惧、愤怒、悲伤))
//            double brow_width = fabs(landmarks.landmark(296).x()-landmarks.landmark(53).x() +
//                         landmarks.landmark(334).x()-landmarks.landmark(52).x() +
//                         landmarks.landmark(293).x()-landmarks.landmark(65).x() +
//                         landmarks.landmark(300).x()-landmarks.landmark(55).x() +
//                         landmarks.landmark(285).x()-landmarks.landmark(70).x() +
//                         landmarks.landmark(295).x()-landmarks.landmark(63).x() +
//                         landmarks.landmark(282).x()-landmarks.landmark(105).x() +
//                         landmarks.landmark(283).x()-landmarks.landmark(66).x());
         double brow_width =
                             [self getDistancd3DwithX1:landmarks.landmark(53).x() Y1:landmarks.landmark(53).y() Z1:landmarks.landmark(53).z()
                                                    X2:landmarks.landmark(296).x() Y2:landmarks.landmark(296).y() Z2:landmarks.landmark(296).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(52).x() Y1:landmarks.landmark(52).y() Z1:landmarks.landmark(52).z()
                                                    X2:landmarks.landmark(334).x() Y2:landmarks.landmark(334).y() Z2:landmarks.landmark(334).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(65).x() Y1:landmarks.landmark(65).y() Z1:landmarks.landmark(65).z()
                                                    X2:landmarks.landmark(293).x() Y2:landmarks.landmark(293).y() Z2:landmarks.landmark(293).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(55).x() Y1:landmarks.landmark(55).y() Z1:landmarks.landmark(55).z()
                                                    X2:landmarks.landmark(300).x() Y2:landmarks.landmark(300).y() Z2:landmarks.landmark(300).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(70).x() Y1:landmarks.landmark(70).y() Z1:landmarks.landmark(70).z()
                                                    X2:landmarks.landmark(285).x() Y2:landmarks.landmark(285).y() Z2:landmarks.landmark(285).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(63).x() Y1:landmarks.landmark(63).y() Z1:landmarks.landmark(63).z()
                                                    X2:landmarks.landmark(295).x() Y2:landmarks.landmark(295).y() Z2:landmarks.landmark(295).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(105).x() Y1:landmarks.landmark(105).y() Z1:landmarks.landmark(105).z()
                                                    X2:landmarks.landmark(282).x() Y2:landmarks.landmark(282).y() Z2:landmarks.landmark(282).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(66).x() Y1:landmarks.landmark(66).y() Z1:landmarks.landmark(66).z()
                                                    X2:landmarks.landmark(283).x() Y2:landmarks.landmark(283).y() Z2:landmarks.landmark(283).z()];

            //2.1、眉毛高度之和
//            double brow_left_height = fabs(landmarks.landmark(53).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(52).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(65).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(55).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(70).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(63).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(105).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(66).y() - landmarks.landmark(10).y());
         double brow_left_height =
                             [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                    X2:landmarks.landmark(53).x() Y2:landmarks.landmark(53).y() Z2:landmarks.landmark(53).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                    X2:landmarks.landmark(52).x() Y2:landmarks.landmark(52).y() Z2:landmarks.landmark(52).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                    X2:landmarks.landmark(65).x() Y2:landmarks.landmark(65).y() Z2:landmarks.landmark(65).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                    X2:landmarks.landmark(55).x() Y2:landmarks.landmark(55).y() Z2:landmarks.landmark(55).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                    X2:landmarks.landmark(70).x() Y2:landmarks.landmark(70).y() Z2:landmarks.landmark(70).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                    X2:landmarks.landmark(63).x() Y2:landmarks.landmark(63).y() Z2:landmarks.landmark(63).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                    X2:landmarks.landmark(105).x() Y2:landmarks.landmark(105).y() Z2:landmarks.landmark(105).z()] +
                             [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                    X2:landmarks.landmark(66).x() Y2:landmarks.landmark(66).y() Z2:landmarks.landmark(66).z()];
//            double brow_right_height = fabs(landmarks.landmark(283).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(282).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(295).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(285).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(300).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(293).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(334).y() - landmarks.landmark(10).y() +
//                                    landmarks.landmark(296).y() - landmarks.landmark(10).y());
         double brow_right_height =
                            [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                   X2:landmarks.landmark(283).x() Y2:landmarks.landmark(283).y() Z2:landmarks.landmark(283).z()] +
                            [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                   X2:landmarks.landmark(282).x() Y2:landmarks.landmark(282).y() Z2:landmarks.landmark(282).z()] +
                            [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                   X2:landmarks.landmark(295).x() Y2:landmarks.landmark(295).y() Z2:landmarks.landmark(295).z()] +
                            [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                   X2:landmarks.landmark(285).x() Y2:landmarks.landmark(285).y() Z2:landmarks.landmark(285).z()] +
                            [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                   X2:landmarks.landmark(300).x() Y2:landmarks.landmark(300).y() Z2:landmarks.landmark(300).z()] +
                            [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                   X2:landmarks.landmark(293).x() Y2:landmarks.landmark(293).y() Z2:landmarks.landmark(293).z()] +
                            [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                   X2:landmarks.landmark(334).x() Y2:landmarks.landmark(334).y() Z2:landmarks.landmark(334).z()] +
                            [self getDistancd3DwithX1:landmarks.landmark(10).x() Y1:landmarks.landmark(10).y() Z1:landmarks.landmark(10).z()
                                                   X2:landmarks.landmark(296).x() Y2:landmarks.landmark(296).y() Z2:landmarks.landmark(296).z()];
            double brow_hight = brow_left_height + brow_right_height;
            //2.2、眉毛高度与识别框高度之比: 眉毛抬高(惊奇、恐惧、悲伤), 眉毛压低(厌恶, 愤怒)
            double brow_hight_rate = brow_hight/16;
            double brow_width_rate = brow_width/8;
            //左眉拟合曲线(53-52-65-55-70-63-105-66)
            double brow_line_points_x[POINT_NUM];
            brow_line_points_x[0] = landmarks.landmark(55).x();
            brow_line_points_x[1] = landmarks.landmark(70).x();
            brow_line_points_x[2] = landmarks.landmark(105).x();
            brow_line_points_x[3] = landmarks.landmark(107).x();
            double brow_line_points_y[POINT_NUM];
            brow_line_points_y[0] = landmarks.landmark(55).y();
            brow_line_points_y[1] = landmarks.landmark(70).y();
            brow_line_points_y[2] = landmarks.landmark(105).y();
            brow_line_points_y[3] = landmarks.landmark(107).y();

            //2.3、眉毛变化程度: 变弯(高兴、惊奇) - 上扬  - 下拉
            double brow_line_left = (-10) * (::mediapipe::getCurveFit_android(brow_line_points_x, brow_line_points_y, POINT_NUM)); //调函数拟合直线
            double brow_line_rate = brow_line_left;
            //3、眼睛高度 (注: 眼睛Y坐标 下 > 上, X坐标 右 > 左)
//            double eye_left_height = fabs(landmarks.landmark(23).y() - landmarks.landmark(27).y());   //中心 以后尝试修改为 Y(145) - Y(159) -> Y(23) - Y(27)
         double eye_left_height = [self getDistancd3DwithX1:landmarks.landmark(145).x() Y1:landmarks.landmark(145).y() Z1:landmarks.landmark(145).z()
                                                         X2:landmarks.landmark(159).x() Y2:landmarks.landmark(159).y() Z2:landmarks.landmark(159).z()];
//            double eye_left_width = fabs(landmarks.landmark(133).x() - landmarks.landmark(33).x());
         double eye_left_width = [self getDistancd3DwithX1:landmarks.landmark(133).x() Y1:landmarks.landmark(133).y() Z1:landmarks.landmark(133).z()
                                                        X2:landmarks.landmark(33).x() Y2:landmarks.landmark(33).y() Z2:landmarks.landmark(33).z()];
//            double eye_right_height = fabs(landmarks.landmark(253).y() - landmarks.landmark(257).y());  // 中心 以后尝试修改为 Y(374) - Y(386) -> Y(253) - Y(257)
         double eye_right_height = [self getDistancd3DwithX1:landmarks.landmark(253).x() Y1:landmarks.landmark(253).y() Z1:landmarks.landmark(253).z()
                                                          X2:landmarks.landmark(257).x() Y2:landmarks.landmark(257).y() Z2:landmarks.landmark(257).z()];
//            double eye_right_width = fabs(landmarks.landmark(263).x() - landmarks.landmark(362).x());
         double eye_right_width = [self getDistancd3DwithX1:landmarks.landmark(263).x() Y1:landmarks.landmark(263).y() Z1:landmarks.landmark(263).z()
                                                         X2:landmarks.landmark(362).x() Y2:landmarks.landmark(362).y() Z2:landmarks.landmark(362).z()];

            //3.1、眼睛睁开程度: 上下眼睑拉大距离(惊奇、恐惧)
            double eye_height = (eye_left_height + eye_right_height)/2;
            double eye_width = (eye_left_width + eye_right_width)/2;

            //4、嘴巴宽高(两嘴角间距离- 用于计算嘴巴的宽度 注: 嘴巴Y坐标 上 > 下, X坐标 右 > 左 嘴巴睁开程度- 用于计算嘴巴的高度: 上下嘴唇拉大距离(惊奇、恐惧、愤怒、高兴))
//            double mouth_width = fabs(landmarks.landmark(308).x() - landmarks.landmark(78).x());
         double mouth_width = [self getDistancd3DwithX1:landmarks.landmark(308).x() Y1:landmarks.landmark(308).y() Z1:landmarks.landmark(308).z()
                                                     X2:landmarks.landmark(78).x() Y2:landmarks.landmark(78).y() Z2:landmarks.landmark(78).z()];
//            double mouth_height = fabs(landmarks.landmark(17).y() - landmarks.landmark(0).y());  // 中心
         double mouth_height = [self getDistancd3DwithX1:landmarks.landmark(17).x() Y1:landmarks.landmark(17).y() Z1:landmarks.landmark(17).z()
                                                      X2:landmarks.landmark(0).x() Y2:landmarks.landmark(0).y() Z2:landmarks.landmark(0).z()];

            //4.1、嘴角下拉(厌恶、愤怒、悲伤),    > 1 上扬， < 1 下拉
//            double mouth_pull_down = fabs((landmarks.landmark(14).y() - landmarks.landmark(324).y())/(landmarks.landmark(14).y() + landmarks.landmark(324).x()));
            //对嘴角进行一阶拟合，曲线斜率
            double lips_line_points_x[POINT_NUM];
            lips_line_points_x[0] = landmarks.landmark(318).x();
            lips_line_points_x[1] = landmarks.landmark(324).x();
            lips_line_points_x[2] = landmarks.landmark(308).x();
            lips_line_points_x[3] = landmarks.landmark(291).x();
            double lips_line_points_y[POINT_NUM];
            lips_line_points_y[0] = landmarks.landmark(318).y();
            lips_line_points_y[1] = landmarks.landmark(324).y();
            lips_line_points_y[2] = landmarks.landmark(308).y();
            lips_line_points_y[3] = landmarks.landmark(291).y();
            double mouth_pull_down_rate = (-10) * (::mediapipe::getCurveFit_android(lips_line_points_x, lips_line_points_y, POINT_NUM)); //调函数拟合直线

            //5、两侧眼角到同侧嘴角距离
//            double distance_eye_left_mouth = fabs(landmarks.landmark(78).y() - landmarks.landmark(133).y());
         double distance_eye_left_mouth = [self getDistancd3DwithX1:landmarks.landmark(133).x() Y1:landmarks.landmark(133).y() Z1:landmarks.landmark(133).z()
                                                                 X2:landmarks.landmark(78).x() Y2:landmarks.landmark(78).y() Z2:landmarks.landmark(78).z()];
//            double distance_eye_right_mouth = fabs(landmarks.landmark(308).y() - landmarks.landmark(362).y());
         double distance_eye_right_mouth = [self getDistancd3DwithX1:landmarks.landmark(362).x() Y1:landmarks.landmark(362).y() Z1:landmarks.landmark(362).z()
                                                                  X2:landmarks.landmark(308).x() Y2:landmarks.landmark(308).y() Z2:landmarks.landmark(308).z()];
            double distance_eye_mouth = distance_eye_left_mouth + distance_eye_right_mouth;

            //6、归一化
            double MM = 0, NN = 0, PP = 0, QQ = 0;
            double dis_eye_mouth_rate = (2 * mouth_width)/distance_eye_mouth;             // 嘴角 / 眼角嘴角距离, 高兴(0.85),愤怒/生气(0.7),惊讶(0.6),大哭(0.75)
//            double distance_brow = fabs(landmarks.landmark(296).x() - landmarks.landmark(66).x());
         double distance_brow = [self getDistancd3DwithX1:landmarks.landmark(66).x() Y1:landmarks.landmark(66).y() Z1:landmarks.landmark(66).z()
                                                       X2:landmarks.landmark(296).x() Y2:landmarks.landmark(296).y() Z2:landmarks.landmark(296).z()];
            double dis_brow_mouth_rate = mouth_width/distance_brow;                       // 嘴角 / 两眉间距
            double dis_eye_height_mouth_rate = mouth_width/eye_height;                    // 嘴角 / 上下眼睑距离
//            double dis_brow_height_mouth_rate = (2 * mouth_width)/fabs((landmarks.landmark(145).y() - landmarks.landmark(70).y()));
         double dis_brow_height_mouth_rate = (2 * mouth_width)/[self getDistancd3DwithX1:landmarks.landmark(70).x() Y1:landmarks.landmark(70).y() Z1:landmarks.landmark(70).z()
                                                                                      X2:landmarks.landmark(145).x() Y2:landmarks.landmark(145).y() Z2:landmarks.landmark(145).z()];

            //7、 求连续多次的平均值
            if(arr_cnt < AVG_CNT) {
                face_width_arr[arr_cnt] = face_width;
                face_height_arr[arr_cnt] = face_height;
                face_ratio_arr[arr_cnt] = face_ratio;
                brow_mouth_arr[arr_cnt] = dis_brow_mouth_rate;
                brow_height_mouth_arr[arr_cnt] = dis_brow_height_mouth_rate;
                brow_width_arr[arr_cnt] = brow_width_rate;
                brow_height_arr[arr_cnt] = brow_hight_rate;
                brow_line_arr[arr_cnt] = brow_line_rate;
                eye_height_arr[arr_cnt] = eye_height;
                eye_width_arr[arr_cnt] = eye_width;
                eye_height_mouth_arr[arr_cnt] = dis_eye_height_mouth_rate;
                mouth_width_arr[arr_cnt] = mouth_width;
                mouth_height_arr[arr_cnt] = mouth_height;
                mouth_pull_down_arr[arr_cnt] = mouth_pull_down_rate;
                dis_eye_mouth_arr[arr_cnt] = dis_eye_mouth_rate;
            }
            double face_width_avg = 0, face_height_avg = 0, face_ratio_avg = 0;
            double brow_mouth_avg = 0, brow_height_mouth_avg = 0;
            double brow_width_avg = 0, brow_height_avg = 0, brow_line_avg = 0;
            double eye_height_avg = 0, eye_width_avg = 0, eye_height_mouth_avg = 0;
            double mouth_width_avg = 0, mouth_height_avg = 0, mouth_pull_down_avg = 0;
            double dis_eye_mouth_avg = 0;
            arr_cnt++;
            if(arr_cnt >= AVG_CNT) {
                face_width_avg = ::mediapipe::getAverage_android(face_width_arr, AVG_CNT);
                face_height_avg = ::mediapipe::getAverage_android(face_height_arr, AVG_CNT);
                face_ratio_avg = ::mediapipe::getAverage_android(face_ratio_arr, AVG_CNT);
                brow_mouth_avg = ::mediapipe::getAverage_android(brow_mouth_arr, AVG_CNT);
                brow_height_mouth_avg = ::mediapipe::getAverage_android(brow_height_mouth_arr, AVG_CNT);
                brow_width_avg = ::mediapipe::getAverage_android(brow_width_arr, AVG_CNT);
                brow_height_avg = ::mediapipe::getAverage_android(brow_height_arr, AVG_CNT);
                brow_line_avg = ::mediapipe::getAverage_android(brow_line_arr, AVG_CNT);
                eye_height_avg = ::mediapipe::getAverage_android(eye_height_arr, AVG_CNT);
                eye_width_avg = ::mediapipe::getAverage_android(eye_width_arr, AVG_CNT);
                eye_height_mouth_avg = ::mediapipe::getAverage_android(eye_height_mouth_arr, AVG_CNT);
                mouth_width_avg = ::mediapipe::getAverage_android(mouth_width_arr, AVG_CNT);
                mouth_height_avg = ::mediapipe::getAverage_android(mouth_height_arr, AVG_CNT);
                mouth_pull_down_avg = ::mediapipe::getAverage_android(mouth_pull_down_arr, AVG_CNT);
                dis_eye_mouth_avg = ::mediapipe::getAverage_android(dis_eye_mouth_arr, AVG_CNT);
                arr_cnt = 0;
            }
            if(arr_cnt == 0) {
                memset(face_width_arr, 0, sizeof(face_width_arr));
                memset(face_height_arr, 0, sizeof(face_height_arr));
                memset(face_ratio_arr, 0, sizeof(face_ratio_arr));
                memset(brow_mouth_arr, 0, sizeof(brow_mouth_arr));
                memset(brow_height_mouth_arr, 0, sizeof(brow_height_mouth_arr));
                memset(brow_width_arr, 0, sizeof(brow_width_arr));
                memset(brow_height_arr, 0, sizeof(brow_height_arr));
                memset(brow_line_arr, 0, sizeof(brow_line_arr));
                memset(eye_height_arr, 0, sizeof(eye_height_arr));
                memset(eye_width_arr, 0, sizeof(eye_width_arr));
                memset(eye_height_mouth_arr, 0, sizeof(eye_height_mouth_arr));
                memset(mouth_width_arr, 0, sizeof(mouth_width_arr));
                memset(mouth_height_arr, 0, sizeof(mouth_height_arr));
                memset(mouth_pull_down_arr, 0, sizeof(mouth_pull_down_arr));
                memset(dis_eye_mouth_arr, 0, sizeof(dis_eye_mouth_arr));
            }

            total_log_cnt++;
            if(total_log_cnt >= AVG_CNT) {
//                //8、表情算法
//                ::mediapipe::setFaceExpressionFace(face_width, face_height, face_ratio);
//                ::mediapipe::setFaceExpressionBrow(brow_width_avg, brow_height_avg, brow_line_avg);
//                ::mediapipe::setFaceExpressionEye(eye_width_avg, eye_height_avg, dis_eye_mouth_rate);
//                ::mediapipe::setFaceExpressionMouth(mouth_width_avg, mouth_height_avg, mouth_pull_down_avg, brow_height_mouth_avg);
//
//                int expression = ::mediapipe::getFaceExpressionType();
//                //9、抛出表情结果, 回调结果给上层
//                [_delegate faceExpression:self Type:expression];
                int ret = 0;
                double mouth_h_w, eye_h_w, brow_h_w;
                double eye_rate, brow_rate, eye_mouth_rate;

                if(abs(face_ratio) <= 1.5f) {    //判断头部倾斜度
                    NSLog(@"faceEC: face_ratio = %f\n", face_ratio);
                    [_delegate faceExpression:self Type:FACE_EXPRESSION_HEADFALSE];
                    return;
                }

                mouth_h_w = mouth_height_avg/mouth_width_avg;
                brow_h_w = brow_height_avg/brow_width_avg;
                eye_h_w = eye_height_avg/eye_width_avg;
//                NSLog(@"faceEC: 头部位置(%f), \t眉高宽比(%f), \t眼高宽比(%f), \t嘴高宽比(%f)\n",
//                        face_ratio,
//                        brow_h_w,
//                        eye_h_w,
//                        mouth_h_w);
                if(brow_h_w <= 0.365f) {
                    brow_rate = (brow_h_w * 0);
                } else if((brow_h_w > 0.365f)&&(brow_h_w <= 0.405f)) {
                    brow_rate = (brow_h_w * 3.58f);
                } else if((brow_h_w > 0.405f)&&(brow_h_w <= 0.455f)) {
                    brow_rate = (brow_h_w * 4.22f);
                } else if(brow_h_w > 0.455f) {
                    brow_rate = (brow_h_w * 5);
                }

                // 眼睛睁开程度
                if(eye_h_w >= 0.323) {
                    eye_rate = (eye_h_w * 4.58f);
                } else if((eye_h_w < 0.323 ) &&(eye_h_w >= 0.286)){
                    eye_rate = (eye_h_w * 3.58f);
                } else {
                    eye_rate = (eye_h_w * 0);
                }

                // 判断微笑程度
                if(dis_eye_mouth_rate <= 0.7) {
                    eye_mouth_rate = dis_eye_mouth_rate * 0;
                } else if((dis_eye_mouth_rate > 0.7) &&(dis_eye_mouth_rate <= 0.75)) {    // 微笑
                    eye_mouth_rate = (dis_eye_mouth_rate * 1.38);
                } else if((dis_eye_mouth_rate > 0.75) &&(dis_eye_mouth_rate <= 0.8)) {
                    eye_mouth_rate = (dis_eye_mouth_rate * 2.58);
                } else if((dis_eye_mouth_rate > 0.8) &&(dis_eye_mouth_rate <= 0.9)) {
                    eye_mouth_rate = (dis_eye_mouth_rate * 3.54);
                } else if((dis_eye_mouth_rate > 0.9) &&(dis_eye_mouth_rate <= 1.0)) {     //大笑
                    eye_mouth_rate = (dis_eye_mouth_rate * 4.22);
                } else if(dis_eye_mouth_rate > 1) {
                    eye_mouth_rate = (dis_eye_mouth_rate * 5.0);
                }

//                printf("faceEC: %s 挑眉(%f), \t嘴角下拉(%f), \t眼角嘴(%f), \t眼角嘴2(%f)\n",
//                    __FUNCTION__,
//                    brow_line_avg,
//                    mouth_pull_down_avg,
//                    dis_eye_mouth_rate,
//                    eye_mouth_rate);
//                printf("faceEC: %s 头部位置(%f), \t眉高宽比(%f), \t眼高宽比(%f), \t嘴高宽比(%f)\n",
//                    __FUNCTION__,
//                    face_ratio,
//                    brow_h_w,
//                    eye_h_w,
//                    mouth_h_w);
                    
#ifdef __ANDROID__
                if(mouth_h_w <= 0.385) {   //没有张嘴：正常、伤心、气愤
                    if(mouth_pull_down_avg >= 2.0f){
                        [_delegate faceExpression:self Type:FACE_EXPRESSION_SAD];
                    } else if(mouth_pull_down_avg <= 1.0) {
                        [_delegate faceExpression:self Type:FACE_EXPRESSION_NATURE];
                    } else {
                        [_delegate faceExpression:self Type:FACE_EXPRESSION_ANGRY];
                    }
                } else {    //张嘴：高兴、气愤、悲伤、惊讶
                    if((mouth_h_w > 0.667) &&(eye_mouth_rate <= 2.0f)) {
                        [_delegate faceExpression:self Type:FACE_EXPRESSION_SURPRISE];
                    } else {
                        if ((eye_h_w <= 0.222) && (mouth_pull_down_avg >= 1.0f)) {
                            [_delegate faceExpression:self Type:FACE_EXPRESSION_SAD];
                        } else {
                            if ((eye_mouth_rate >= 3.0f) && ((brow_height_mouth_avg >= 2.0f) /*|| (eye_h_w >= 0.167)*/)) {
                                [_delegate faceExpression:self Type:FACE_EXPRESSION_HAPPY];
                            } else if (eye_mouth_rate < 2.0f) {
                                [_delegate faceExpression:self Type:FACE_EXPRESSION_ANGRY];
                            }
                        }
                    }
                }
#else // __ANDROID__
                if((mouth_h_w <= 0.35)) { //没有张嘴：正常、伤心、气愤
                    if(eye_h_w >= 0.35) {
                        [_delegate faceExpression:self Type:FACE_EXPRESSION_ANGRY];
                    } else {
                        if(eye_mouth_rate < 3.85) {   //brow_line_avg*(-10) >= 3.5
                            [_delegate faceExpression:self Type:FACE_EXPRESSION_ANGRY];
                        } else {
                            [_delegate faceExpression:self Type:FACE_EXPRESSION_NATURE];
                        }
                    }
                } else {    //张嘴：高兴、气愤、悲伤、惊讶
                    if(eye_h_w >= 0.36) {
                        [_delegate faceExpression:self Type:FACE_EXPRESSION_SURPRISE];
                    } else {
                        if(eye_h_w <= 0.3) {
//                            if((eye_mouth_rate >= 7.0) &&(mouth_pull_down_avg > 2.5)) {
                                [_delegate faceExpression:self Type:FACE_EXPRESSION_HAPPY];
//                            } else {
//                                [_delegate faceExpression:self Type:FACE_EXPRESSION_ANGRY];
//                            }
                        } else {
                            [_delegate faceExpression:self Type:FACE_EXPRESSION_SAD];
                        }
                    }
                }
#endif
                total_log_cnt = 0;
            }
        }
#endif
      }

}

@end

@implementation Landmark

- (instancetype)initWithX:(float)x y:(float)y z:(float)z {
    self = [super init];
    if (self) {
        _x = x;
        _y = y;
        _z = z;
    }
    return self;
}

@end
