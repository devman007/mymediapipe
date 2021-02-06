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

#import "UpperBodyPoseTrackingViewController.h"

#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/util/cpu_util.h"

static const char* kLandmarksOutputStream = "pose_landmarks";

UILabel *_expresLabel;

@implementation UpperBodyPoseTrackingViewController

#pragma mark - UIViewController methods

- (void)viewDidLoad {
  [super viewDidLoad];
    //add by jacky.
    _expresLabel = [[UILabel alloc] init];
    CGFloat width = self.view.frame.size.width;
    CGFloat height= self.view.frame.size.height;
    CGFloat x     = (width - 200)/2;
    CGFloat y     = 30;
    _expresLabel.frame = CGRectMake(x, y, 200, 30);
    _expresLabel.textAlignment = NSTextAlignmentCenter;
    _expresLabel.textColor = [UIColor greenColor];
    _expresLabel.numberOfLines = 1;
    _expresLabel.font = [UIFont systemFontOfSize:30.f];
    _expresLabel.font = [UIFont boldSystemFontOfSize:25.f];
    _expresLabel.font = [UIFont italicSystemFontOfSize:20.f];
    _expresLabel.text = @"";
    [self.view addSubview:_expresLabel];

  [self.mediapipeGraph addFrameOutputStream:kLandmarksOutputStream
                           outputPacketType:MPPPacketTypeRaw];
}

- (void)showCapture:(int)type Capture:(NSString*)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (type) {
            case 0:
                break;
            case 1:
                break;
            default:
                break;
        }
        _expresLabel.text = text;
    });
}

double getAverage(double arr[], int num) {
    double ret = 0;
    double sum = 0;
    for (int i = 0; i < num; i++) {
        sum += arr[i];
    }
    ret = sum/num;
    return ret;
}

#define ARR_CNT     10
static int arr_cnt = 0;
static double dLeftArr_wrist_elbow_w[ARR_CNT];
static double dLeftArr_wrist_elbow_h[ARR_CNT];
static double dLeftArr_elbow_shoulder_w[ARR_CNT];
static double dLeftArr_elbow_shoulder_h[ARR_CNT];
static double dLeftArr_wrist_shoulder_w[ARR_CNT];
static double dLeftArr_wrist_shoulder_h[ARR_CNT];
static double dRightArr_wrist_elbow_w[ARR_CNT];
static double dRightArr_wrist_elbow_h[ARR_CNT];
static double dRightArr_elbow_shoulder_w[ARR_CNT];
static double dRightArr_elbow_shoulder_h[ARR_CNT];
static double dRightArr_wrist_shoulder_w[ARR_CNT];
static double dRightArr_wrist_shoulder_h[ARR_CNT];
static double dLeftArr_wrist_nose_w[ARR_CNT];
static double dLeftArr_wrist_nose_h[ARR_CNT];
static double dLeftArr_elbow_nose_w[ARR_CNT];
static double dLeftArr_elbow_nose_h[ARR_CNT];
static double dRightArr_wrist_nose_w[ARR_CNT];
static double dRightArr_wrist_nose_h[ARR_CNT];
static double dRightArr_elbow_nose_w[ARR_CNT];
static double dRightArr_elbow_nose_h[ARR_CNT];
#pragma mark - MPPGraphDelegate methods

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
     didOutputPacket:(const ::mediapipe::Packet&)packet
          fromStream:(const std::string&)streamName {
  if (streamName == kLandmarksOutputStream) {
    if (packet.IsEmpty()) {
      NSLog(@"[TS:%lld] No pose landmarks", packet.Timestamp().Value());
      return;
    }
    const auto& landmarks = packet.Get<::mediapipe::NormalizedLandmarkList>();
//    NSLog(@"[TS:%lld] Number of pose landmarks: %d", packet.Timestamp().Value(),
//          landmarks.landmark_size());
//    for (int i = 0; i < landmarks.landmark_size(); ++i) {
//      NSLog(@"\tLandmark[%d]: (%f, %f, %f)", i, landmarks.landmark(i).x(),
//            landmarks.landmark(i).y(), landmarks.landmark(i).z());
//    }
      Boolean isHighLefthand = false;
      Boolean isHighRighthand = false;
      Boolean isLeftRightAcross = false;
      NSString* landmarksString = @"";
      
      mediapipe::NormalizedLandmark nose = landmarks.landmark(0);
      mediapipe::NormalizedLandmark left_eye_inner = landmarks.landmark(1);
      mediapipe::NormalizedLandmark left_eye = landmarks.landmark(2);
      mediapipe::NormalizedLandmark left_eye_outer = landmarks.landmark(3);
      mediapipe::NormalizedLandmark right_eye_inner = landmarks.landmark(4);
      mediapipe::NormalizedLandmark right_eye = landmarks.landmark(5);
      mediapipe::NormalizedLandmark right_eye_outer = landmarks.landmark(6);
      mediapipe::NormalizedLandmark left_ear = landmarks.landmark(7);
      mediapipe::NormalizedLandmark right_ear = landmarks.landmark(8);
      mediapipe::NormalizedLandmark mouth_left = landmarks.landmark(9);
      mediapipe::NormalizedLandmark mouth_right = landmarks.landmark(10);
      mediapipe::NormalizedLandmark left_shoulder = landmarks.landmark(11);
      mediapipe::NormalizedLandmark right_shoulder = landmarks.landmark(12);
      mediapipe::NormalizedLandmark left_elbow = landmarks.landmark(13);
      mediapipe::NormalizedLandmark right_elbow = landmarks.landmark(14);
      mediapipe::NormalizedLandmark left_wrist = landmarks.landmark(15);
      mediapipe::NormalizedLandmark right_wrist = landmarks.landmark(16);
      mediapipe::NormalizedLandmark left_pinky = landmarks.landmark(17);
      mediapipe::NormalizedLandmark right_pinky = landmarks.landmark(18);
      mediapipe::NormalizedLandmark left_index = landmarks.landmark(19);
      mediapipe::NormalizedLandmark right_index = landmarks.landmark(20);
      mediapipe::NormalizedLandmark left_thumb = landmarks.landmark(21);
      mediapipe::NormalizedLandmark right_thumb = landmarks.landmark(22);
      mediapipe::NormalizedLandmark left_hip = landmarks.landmark(23);
      mediapipe::NormalizedLandmark right_hip = landmarks.landmark(24);

      //左手腕 - 左肘
      double left_wrist_elbow_w = left_wrist.x() - left_elbow.x();
      double left_wrist_elbow_h = left_wrist.y() - left_elbow.y();
      //左肘 - 左肩
      double left_elbow_shoulder_w = left_elbow.x() - left_shoulder.x();
      double left_elbow_shoulder_h = left_elbow.y() - left_shoulder.y();
      //左手腕 - 左肩
      double left_wrist_shoulder_w = left_wrist.x() - left_shoulder.x();
      double left_wrist_shoulder_h = left_wrist.y() - left_shoulder.y();
      //右手腕 - 右肘
      double right_wrist_elbow_w = right_wrist.x() - right_elbow.x();
      double right_wrist_elbow_h = right_wrist.y() - right_elbow.y();
      //右肘 - 右肩
      double right_elbow_shoulder_w = right_elbow.x() - right_shoulder.x();
      double right_elbow_shoulder_h = right_elbow.y() - right_shoulder.y();
      //右手腕 - 右肩
      double right_wrist_shoulder_w = right_wrist.x() - right_shoulder.x();
      double right_wrist_shoulder_h = right_wrist.y() - right_shoulder.y();
      //左手腕 - 鼻子
      double left_wrist_nose_w = left_wrist.x() - nose.x();
      double left_wrist_nose_h = left_wrist.y() - nose.y();
      //左肘 - 鼻子
      double left_elbow_nose_w = left_elbow.x() - nose.x();
      double left_elbow_nose_h = left_elbow.y() - nose.y();
      //右手腕 - 鼻子
      double right_wrist_nose_w = right_wrist.x() - nose.x();
      double right_wrist_nose_h = right_wrist.y() - nose.y();
      //右肘 - 鼻子
      double right_elbow_nose_w = right_elbow.x() - nose.x();
      double right_elbow_nose_h = right_elbow.y() - nose.y();
      
      if(arr_cnt < ARR_CNT) {
          dLeftArr_wrist_elbow_w[arr_cnt] = left_wrist_elbow_w;
          dLeftArr_wrist_elbow_h[arr_cnt] = left_wrist_elbow_h;
          dLeftArr_elbow_shoulder_w[arr_cnt] = left_elbow_shoulder_w;
          dLeftArr_elbow_shoulder_h[arr_cnt] = left_elbow_shoulder_h;
          dRightArr_wrist_elbow_w[arr_cnt] = right_wrist_elbow_w;
          dLeftArr_wrist_shoulder_w[arr_cnt] = left_wrist_shoulder_w;
          dLeftArr_wrist_shoulder_h[arr_cnt] = left_wrist_shoulder_h;
          dRightArr_wrist_elbow_h[arr_cnt] = right_wrist_elbow_h;
          dRightArr_elbow_shoulder_w[arr_cnt] = right_elbow_shoulder_w;
          dRightArr_elbow_shoulder_h[arr_cnt] = right_elbow_shoulder_h;
          dRightArr_wrist_shoulder_w[arr_cnt] = right_wrist_shoulder_w;
          dRightArr_wrist_shoulder_h[arr_cnt] = right_wrist_shoulder_h;
          dLeftArr_wrist_nose_w[arr_cnt] = left_wrist_nose_w;
          dLeftArr_wrist_nose_h[arr_cnt] = left_wrist_nose_h;
          dLeftArr_elbow_nose_w[arr_cnt] = left_elbow_nose_w;
          dLeftArr_elbow_nose_h[arr_cnt] = left_elbow_nose_h;
          dRightArr_wrist_nose_w[arr_cnt] = right_wrist_nose_w;
          dRightArr_wrist_nose_h[arr_cnt] = right_wrist_nose_h;
          dRightArr_elbow_nose_w[arr_cnt] = right_elbow_nose_w;
          dRightArr_elbow_nose_h[arr_cnt] = right_elbow_nose_h;
          arr_cnt++;
      }
      double AvgLeft_wrist_elbow_w, AvgLeft_elbow_shoulder_w, AvgRight_wrist_elbow_w, AvgRight_elbow_shoulder_w, AvgLeft_wrist_shoulder_w, AvgRight_wrist_shoulder_w;
      double AvgLeft_wrist_elbow_h, AvgLeft_elbow_shoulder_h, AvgRight_wrist_elbow_h, AvgRight_elbow_shoulder_h, AvgLeft_wrist_shoulder_h, AvgRight_wrist_shoulder_h;
      double AvgLeft_wrist_nose_w, AvgLeft_wrist_nose_h, AvgLeft_elbow_nose_w, AvgLeft_elbow_nose_h;
      double AvgRight_wrist_nose_w, AvgRight_wrist_nose_h, AvgRight_elbow_nose_w, AvgRight_elbow_nose_h;
      
      if(arr_cnt >= ARR_CNT) {
          AvgLeft_wrist_elbow_w = getAverage(dLeftArr_wrist_elbow_w, 10);
          AvgLeft_wrist_elbow_h = getAverage(dLeftArr_wrist_elbow_h, 10);
          AvgLeft_elbow_shoulder_w = getAverage(dLeftArr_elbow_shoulder_w, 10);
          AvgLeft_elbow_shoulder_h = getAverage(dLeftArr_elbow_shoulder_h, 10);
          AvgLeft_wrist_shoulder_w = getAverage(dLeftArr_wrist_shoulder_w, 10);
          AvgLeft_wrist_shoulder_h = getAverage(dLeftArr_wrist_shoulder_h, 10);
          AvgRight_wrist_elbow_w = getAverage(dRightArr_wrist_elbow_w, 10);
          AvgRight_wrist_elbow_h = getAverage(dRightArr_wrist_elbow_h, 10);
          AvgRight_elbow_shoulder_w = getAverage(dRightArr_elbow_shoulder_w, 10);
          AvgRight_elbow_shoulder_h = getAverage(dRightArr_elbow_shoulder_h, 10);
          AvgRight_wrist_shoulder_w = getAverage(dRightArr_wrist_shoulder_w, 10);
          AvgRight_wrist_shoulder_h = getAverage(dRightArr_wrist_shoulder_h, 10);
          AvgLeft_wrist_nose_w = getAverage(dLeftArr_wrist_nose_w, 10);
          AvgLeft_wrist_nose_h = getAverage(dLeftArr_wrist_nose_h, 10);
          AvgLeft_elbow_nose_w = getAverage(dLeftArr_elbow_nose_w, 10);
          AvgLeft_elbow_nose_h = getAverage(dLeftArr_elbow_nose_h, 10);
          AvgRight_wrist_nose_w = getAverage(dRightArr_wrist_nose_w, 10);
          AvgRight_wrist_nose_h = getAverage(dRightArr_wrist_nose_h, 10);
          AvgRight_elbow_nose_w = getAverage(dRightArr_elbow_nose_w, 10);
          AvgRight_elbow_nose_h = getAverage(dRightArr_elbow_nose_h, 10);
          arr_cnt = 0;
          
          memset(dLeftArr_wrist_elbow_w, 0, sizeof(dLeftArr_wrist_elbow_w));
          memset(dLeftArr_wrist_elbow_h, 0, sizeof(dLeftArr_wrist_elbow_h));
          memset(dLeftArr_elbow_shoulder_w, 0, sizeof(dLeftArr_elbow_shoulder_w));
          memset(dLeftArr_elbow_shoulder_h, 0, sizeof(dLeftArr_elbow_shoulder_h));
          memset(dLeftArr_wrist_shoulder_w, 0, sizeof(dLeftArr_wrist_shoulder_w));
          memset(dLeftArr_wrist_shoulder_h, 0, sizeof(dLeftArr_wrist_shoulder_h));
          memset(dRightArr_wrist_elbow_w, 0, sizeof(dRightArr_wrist_elbow_w));
          memset(dRightArr_wrist_elbow_h, 0, sizeof(dRightArr_wrist_elbow_h));
          memset(dRightArr_elbow_shoulder_w, 0, sizeof(dRightArr_elbow_shoulder_w));
          memset(dRightArr_elbow_shoulder_h, 0, sizeof(dRightArr_elbow_shoulder_h));
          memset(dRightArr_wrist_shoulder_w, 0, sizeof(dRightArr_wrist_shoulder_w));
          memset(dRightArr_wrist_shoulder_h, 0, sizeof(dRightArr_wrist_shoulder_h));
          memset(dLeftArr_wrist_nose_w, 0, sizeof(dLeftArr_wrist_nose_w));
          memset(dLeftArr_wrist_nose_h, 0, sizeof(dLeftArr_wrist_nose_h));
          memset(dLeftArr_elbow_nose_w, 0, sizeof(dLeftArr_elbow_nose_w));
          memset(dLeftArr_elbow_nose_h, 0, sizeof(dLeftArr_elbow_nose_h));
          memset(dRightArr_wrist_nose_w, 0, sizeof(dRightArr_wrist_nose_w));
          memset(dRightArr_wrist_nose_h, 0, sizeof(dRightArr_wrist_nose_h));
          memset(dRightArr_elbow_nose_w, 0, sizeof(dRightArr_elbow_nose_w));
          memset(dRightArr_elbow_nose_h, 0, sizeof(dRightArr_elbow_nose_h));
          
          if((AvgLeft_wrist_nose_h < 0) && (AvgLeft_elbow_nose_h < 0) && (AvgLeft_wrist_elbow_h < 0))   {
              isHighLefthand = true;
          }
          //(Avgleft_wrist_elbow_h > 0) && (AvgLeft_elbow_shoulder_h > 0) &&
          if((AvgRight_wrist_nose_h < 0) && (AvgRight_elbow_nose_h < 0) && (AvgRight_wrist_elbow_h < 0))   {
              isHighRighthand = true;
          }
          if((AvgLeft_wrist_elbow_w < 0) && (AvgLeft_elbow_shoulder_w < 0) && (AvgLeft_wrist_shoulder_w < 0) &&
                  (AvgRight_wrist_elbow_w > 0) && (AvgRight_elbow_shoulder_w > 0) && (AvgRight_wrist_shoulder_w > 0)) {
              isLeftRightAcross = true;
          }
          
          if(isHighLefthand && !isHighRighthand) {
              landmarksString = @"举左手";
          } else if(!isHighLefthand && isHighRighthand) {
              landmarksString = @"举右手";
          } else if(isHighLefthand && isHighRighthand) {
              if(isLeftRightAcross) {
                  landmarksString = @"双手上举并交叉";
              } else {
                  landmarksString = @"双手上举";
              }
          } else if(isLeftRightAcross) {
              landmarksString = @"双手前交叉";
          } else {
              landmarksString = @"";
          }
          
          [self showCapture:0 Capture:landmarksString];
      }
  }
}

@end
