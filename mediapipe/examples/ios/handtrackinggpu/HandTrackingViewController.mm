// Copyright 2019 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "HandTrackingViewController.h"

#include "mediapipe/framework/formats/landmark.pb.h"

static const char* kLandmarksOutputStream = "hand_landmarks";

@implementation HandTrackingViewController

#pragma mark - UIViewController methods

- (void)viewDidLoad {
  [super viewDidLoad];

  [self.mediapipeGraph addFrameOutputStream:kLandmarksOutputStream
                           outputPacketType:MPPPacketTypeRaw];
}

#pragma mark - MPPGraphDelegate methods

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (NSString*)mediapipeGraph:(MPPGraph*)graph
     didOutputPacket:(const ::mediapipe::Packet&)packet
          fromStream:(const std::string&)streamName {
  if (streamName == kLandmarksOutputStream) {
    if (packet.IsEmpty()) {
      NSLog(@"[TS:%lld] No hand landmarks", packet.Timestamp().Value());
      return @"";
    }
    const auto& landmarks = packet.Get<::mediapipe::NormalizedLandmarkList>();
    NSLog(@"[TS:%lld] Number of landmarks on hand: %d", packet.Timestamp().Value(),
          landmarks.landmark_size());
//    for (int i = 0; i < landmarks.landmark_size(); ++i) {
//      NSLog(@"\tLandmark[%d]: (%f, %f, %f)", i, landmarks.landmark(i).x(),
//            landmarks.landmark(i).y(), landmarks.landmark(i).z());
//    }
    
    bool IsThumb = false;
    bool IsFinger_1 = false;
    bool IsFinger_2 = false;
    bool IsFinger_3 = false;
    bool IsFinger_4 = false;

    if (landmarks.landmark(2).x() < landmarks.landmark(9).x()) {
        if (landmarks.landmark(3).x() < landmarks.landmark(2).x() && landmarks.landmark(4).x() < landmarks.landmark(2).x()) {
            IsThumb = true;
        }
    }
    if (landmarks.landmark(2).x() > landmarks.landmark(9).x()) {
        if (landmarks.landmark(3).x() > landmarks.landmark(2).x() && landmarks.landmark(4).x() > landmarks.landmark(2).x()) {
            IsThumb = true;
        }
    }

    if (landmarks.landmark(7).y() < landmarks.landmark(6).y() && landmarks.landmark(7).y() > landmarks.landmark(8).y()) {
        IsFinger_1 = true;
    }
    if (landmarks.landmark(11).y() < landmarks.landmark(10).y() && landmarks.landmark(11).y() > landmarks.landmark(12).y()) {
        IsFinger_2 = true;
    }
    if (landmarks.landmark(15).y() < landmarks.landmark(14).y() && landmarks.landmark(15).y() > landmarks.landmark(16).y()) {
        IsFinger_3 = true;
    }
    if (landmarks.landmark(19).y() < landmarks.landmark(18).y() && landmarks.landmark(19).y() > landmarks.landmark(20).y()) {
        IsFinger_4 = true;
    }

    if (IsThumb && IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4) {
        NSString* str = @"Five\n";
        NSLog(str);
        return str;
    } else if (!IsThumb && IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4) {
        NSString* str = @"Four\n";
        NSLog(str);
        return str;
    } else if (IsThumb && IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
        NSString* str = @"Three\n";
        NSLog(str);
        return str;
    } else if (IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
        NSString* str = @"Two\n";
        NSLog(str);
        return str;
    } else if ((!IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) ||
                (!IsThumb && !IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) ||
                (!IsThumb && !IsFinger_1 && !IsFinger_2 && IsFinger_3 && !IsFinger_4) ||
                (!IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4)
    ) {
        NSString* str = @"One\n";
        NSLog(str);
        return str;
    } else if (!IsThumb && IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
        NSString* str = @"Yeah\n";
        NSLog(str);
        return str;
    } else if (!IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
        NSString* str = @"Fist\n";
        NSLog(str);
        return str;
    } else if (IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
        NSString* str = @"Wonderful\n";
        NSLog(str);
        return str;
    } else if (!IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4 && IsThumbConnectFinger_1(landmarks.landmark(4), landmarks.landmark(8))) {
        NSString* str = @"OK\n";
        NSLog(str);
        return str;
    } else {
        return @"";
    }
  }
}

double getDistance(double a_x, double a_y, double b_x, double b_y) {
    double dist = pow(a_x - b_x, 2) + pow(a_y - b_y, 2);
    return sqrt(dist);
}

bool IsThumbConnectFinger_1(::mediapipe::NormalizedLandmark point1, ::mediapipe::NormalizedLandmark point2) {
    double distance = getDistance(point1.x(), point1.y(), point2.x(), point2.y());
    return distance < 0.1;
}

@end
