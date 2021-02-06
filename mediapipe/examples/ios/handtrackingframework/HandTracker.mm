#import "HandTracker.h"
#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"
#include "mediapipe/framework/formats/landmark.pb.h"

static NSString* const kGraphName = @"hand_tracking_mobile_gpu";
static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kLandmarksOutputStream = "hand_landmarks";
static const char* kVideoQueueLabel = "com.google.mediapipe.example.videoQueue";

@interface HandTracker() <MPPGraphDelegate>
@property(nonatomic) MPPGraph* mediapipeGraph;
@end

#define TICKTOTALNUMBER 10
#define TICKTHRESHOLDNUMBER 6

static int tickNumber = 0;
static int NumberFinger1 = 0;
static int NumberFinger2 = 0;
static int NumberFinger3 = 0;
static int NumberFinger4 = 0;
static int NumberFinger5 = 0;
static int NumberFinger6 = 0;
static int NumberFingerFist = 0;
static int NumberFingerOK = 0;
static int NumberFingerYeah = 0;
static int NumberFingerWonderful = 0;
static int NumberFingerSpiderMan = 0;
static int NumberFingerUnknown = 0;

@interface Landmark()
- (instancetype)initWithX:(float)x y:(float)y z:(float)z;
@end

@implementation HandTracker {}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.mediapipeGraph = [[self class] loadGraphFromResource:kGraphName];
        self.mediapipeGraph.delegate = self;
        // Set maxFramesInFlight to a small value to avoid memory contention for real-time processing.
        self.mediapipeGraph.maxFramesInFlight = 2;
    }
    return self;
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
    
    // Parse the graph config resource into mediapipe::CalculatorGraphConfig proto object.
    mediapipe::CalculatorGraphConfig config;
    config.ParseFromArray(data.bytes, data.length);
    
    // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
    MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];
    [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
    [newGraph addFrameOutputStream:kLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];
    return newGraph;
}

- (void)startGraph {
    // Start running self.mediapipeGraph.
    NSError* error;
    if (![self.mediapipeGraph startWithError:&error]) {
        NSLog(@"Failed to start graph: %@", error);
    }
}

- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer {
    [self.mediapipeGraph sendPixelBuffer:imageBuffer
                              intoStream:kInputStream
                              packetType:MPPPacketTypePixelBuffer];
}

double getDistance(double a_x, double a_y, double b_x, double b_y) {
    double dist = pow(a_x - b_x, 2) + pow(a_y - b_y, 2);
    return sqrt(dist);
}

bool IsThumbConnectFinger_1(mediapipe::NormalizedLandmark point1, mediapipe::NormalizedLandmark point2) {
    double distance = getDistance(point1.x(), point1.y(), point2.x(), point2.y());
    return distance < 0.1;
}

#pragma mark - MPPGraphDelegate methods

// Receives CVPixelBufferRef from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
  didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer
            fromStream:(const std::string&)streamName {
      if (streamName == kOutputStream) {
          [_delegate handTracker: self didOutputPixelBuffer: pixelBuffer];
      }
}

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const mediapipe::Packet&)packet
            fromStream:(const std::string&)streamName {
    if (streamName == kLandmarksOutputStream) {
        if (packet.IsEmpty()) { return; }
        // const auto landmarks = packet.Get<std::vector<mediapipe::NormalizedLandmarkList>>();//packet.Get<mediapipe::NormalizedLandmarkList>();//
        
        //        for (int i = 0; i < landmarks.landmark_size(); ++i) {
        //            NSLog(@"\tLandmark[%d]: (%f, %f, %f)", i, landmarks.landmark(i).x(),
        //                  landmarks.landmark(i).y(), landmarks.landmark(i).z());
        //        }
//        // for send landmark to app lay.
//        NSMutableArray<Landmark *> *result = [NSMutableArray array];
//        for (int i = 0; i < landmarks.landmark_size(); ++i) {
//            Landmark *landmark = [[Landmark alloc] initWithX:landmarks.landmark(i).x()
//                                                           y:landmarks.landmark(i).y()
//                                                           z:landmarks.landmark(i).z()];
//            [result addObject:landmark];
//        }
//        [_delegate handTracker: self didOutputLandmarks: result];
        //for send pose type to app lay.
        bool IsThumb = false;
        bool IsFinger_1 = false;
        bool IsFinger_2 = false;
        bool IsFinger_3 = false;
        bool IsFinger_4 = false;

//         if (landmarks.landmark(2).x() < landmarks.landmark(9).x()) {
//             if (landmarks.landmark(3).x() < landmarks.landmark(2).x() && landmarks.landmark(4).x() < landmarks.landmark(2).x()) {
//                 IsThumb = true;
//             }
//         }
//         if (landmarks.landmark(2).x() > landmarks.landmark(9).x()) {
//             if (landmarks.landmark(3).x() > landmarks.landmark(2).x() && landmarks.landmark(4).x() > landmarks.landmark(2).x()) {
//                 IsThumb = true;
//             }
//         }

//         if (landmarks.landmark(7).y() < landmarks.landmark(6).y() && landmarks.landmark(7).y() > landmarks.landmark(8).y()) {
//             IsFinger_1 = true;
//         }
//         if (landmarks.landmark(11).y() < landmarks.landmark(10).y() && landmarks.landmark(11).y() > landmarks.landmark(12).y()) {
//             IsFinger_2 = true;
//         }
//         if (landmarks.landmark(15).y() < landmarks.landmark(14).y() && landmarks.landmark(15).y() > landmarks.landmark(16).y()) {
//             IsFinger_3 = true;
//         }
//         if (landmarks.landmark(19).y() < landmarks.landmark(18).y() && landmarks.landmark(19).y() > landmarks.landmark(20).y()) {
//             IsFinger_4 = true;
//         }

//         if (IsThumb && IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4) {
//             NSString* str = @"handTracker -- Five\n";
//             NSLog(str);
//             NumberFinger5++;
//     //        return str;
//         } else if (IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && IsFinger_4) {
//             NSString* str = @"handTracker -- Six\n";
//             NSLog(str);
//             NumberFinger6++;
//     //        return str;
//         } else if (!IsThumb && IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4) {
//             NSString* str = @"handTracker -- Four\n";
//             NSLog(str);
//             NumberFinger4++;
//     //        return str;
//         } else if (IsThumb && IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
//             NSString* str = @"handTracker -- Three\n";
//             NSLog(str);
//             NumberFinger3++;
//     //        return str;
//         } else if (IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
//             NSString* str = @"handTracker -- Two\n";
//             NSLog(str);
//             NumberFinger2++;
//     //        return str;
//         } else if ((!IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) ||
//                     (!IsThumb && !IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) ||
//                     (!IsThumb && !IsFinger_1 && !IsFinger_2 && IsFinger_3 && !IsFinger_4) ||
//                     (!IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && IsFinger_4)) {
//             NSString* str = @"handTracker -- One\n";
//             NSLog(str);
//             NumberFinger1++;
//     //        return str;
//         } else if (!IsThumb && IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
//             NSString* str = @"handTracker -- Yeah\n";
//             NSLog(str);
//             NumberFingerYeah++;
//     //        return str;
//         } else if (!IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
//             NSString* str = @"handTracker -- Fist\n";
//             NSLog(str);
//             NumberFingerFist++;
//     //        return str;
//         } else if (IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
//             NSString* str = @"handTracker -- Wonderful\n";
//             NSLog(str);
//             NumberFingerWonderful++;
//     //        return str;
//         } else if(IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && IsFinger_4) {
//             NumberFingerSpiderMan++;
//         } else if (!IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4 && IsThumbConnectFinger_1(landmarks.landmark(4), landmarks.landmark(8))) {
//             NSString* str = @"handTracker -- OK\n";
//             NSLog(str);
//     //        return str;
//             NumberFingerOK++;
//         } else {
//     //        return @"";
//             NumberFingerUnknown++;
//         }
        
        tickNumber++;
        if(tickNumber >= TICKTOTALNUMBER) {
            if(NumberFinger1 >= TICKTHRESHOLDNUMBER) {
                [_delegate handTracker: self Type:HAND_FINGER1 Name:@"One"];
            } else if(NumberFinger2 >= TICKTHRESHOLDNUMBER) {
                [_delegate handTracker: self Type:HAND_FINGER2 Name:@"Two"];
            } else if(NumberFinger3 >= TICKTHRESHOLDNUMBER) {
                [_delegate handTracker: self Type:HAND_FINGER3 Name:@"Three"];
            } else if(NumberFinger4 >= TICKTHRESHOLDNUMBER) {
                [_delegate handTracker: self Type:HAND_FINGER4 Name:@"Four"];
            } else if(NumberFinger5 >= TICKTHRESHOLDNUMBER) {
                [_delegate handTracker: self Type:HAND_FINGER5 Name:@"Five"];
            } else if(NumberFinger6 >= TICKTHRESHOLDNUMBER) {
                [_delegate handTracker: self Type:HAND_FINGER6 Name:@"Six"];
            } else if(NumberFingerFist >= TICKTHRESHOLDNUMBER) {
                [_delegate handTracker: self Type:HAND_FIST Name:@"Fist"];
            } else if(NumberFingerOK >= TICKTHRESHOLDNUMBER) {
                [_delegate handTracker: self Type:HAND_OK Name:@"OK"];
            } else if(NumberFingerYeah >= TICKTHRESHOLDNUMBER) {
                [_delegate handTracker: self Type:HAND_YEAH Name:@"Yeah"];
            } else if(NumberFingerWonderful >= TICKTHRESHOLDNUMBER) {
                [_delegate handTracker: self Type:HAND_WONDERFUL Name:@"Wonderful"];
            } else if(NumberFingerSpiderMan >= TICKTHRESHOLDNUMBER) {
                [_delegate handTracker: self Type:HAND_SPIDERMAN Name:@"SpiderMan"];
            } else {
                [_delegate handTracker: self Type:HAND_UNKNOWN Name:@""];
            }
            tickNumber = 0;
            NumberFinger1 = 0;
            NumberFinger2 = 0;
            NumberFinger3 = 0;
            NumberFinger4 = 0;
            NumberFinger5 = 0;
            NumberFinger6 = 0;
            NumberFingerFist = 0;
            NumberFingerOK = 0;
            NumberFingerYeah = 0;
            NumberFingerWonderful = 0;
            NumberFingerSpiderMan = 0;
            NumberFingerUnknown = 0;
        }
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
