//
//  FaceExpresser.mm
//  _idx_CommonMediaPipeLibrary_CommonMediaPipeAppLibrary_9824EFBB_ios_min13.2
//
//  Created by 岳传真 on 2021/1/8.
//

#import <Foundation/Foundation.h>

#import "FaceExpresser.h"
//#import "mediapipe/examples/ios/common_lib/CommonViewController.h"

//#include "mediapipe/framework/formats/landmark.pb.h"
//#include "mediapipe/util/cpu_util.h"

static const char* kNumFacesInputSidePacket = "num_faces";
static const char* kLandmarksOutputStream = "multi_face_landmarks";
// Max number of faces to detect/process.
static const int kNumFaces = 1;

//@interface FaceExpresser : CommonViewController
//
//
//@end

@implementation FaceExpresser {}

- (void)startMediagraph {
    [self.mediapipeGraph setSidePacket:(mediapipe::MakePacket<int>(kNumFaces))
                                 named:kNumFacesInputSidePacket];
    [self.mediapipeGraph addFrameOutputStream:kLandmarksOutputStream
                             outputPacketType:MPPPacketTypeRaw];
}

@end
