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

#import "FaceMeshGpuViewController.h"

#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/util/cpu_util.h"

static NSString* const kGraphName = @"face_mesh_mobile_gpu";

static const char* kNumFacesInputSidePacket = "num_faces";
static const char* kLandmarksOutputStream = "multi_face_landmarks";

// Max number of faces to detect/process.
static const int kNumFaces = 1;

#define AVG_CNT 10
#define DETECT_TIMES 2

DOUBLE brow_width_arr[AVG_CNT];
DOUBLE brow_height_arr[AVG_CNT];
DOUBLE brow_line_arr[AVG_CNT];
DOUBLE brow_mouth_arr[AVG_CNT];
DOUBLE brow_height_mouth_arr[AVG_CNT];
DOUBLE eye_height_arr[AVG_CNT];
DOUBLE eye_width_arr[AVG_CNT];
DOUBLE eye_height_mouth_arr[AVG_CNT];
DOUBLE mouth_width_arr[AVG_CNT];
DOUBLE mouth_height_arr[AVG_CNT];
DOUBLE mouth_pull_down_arr[AVG_CNT];
static int arr_cnt = 0;
static int normal_times = 0, suprise_times = 0, sad_times = 0, happy_times = 0, angry_times = 0;
static int total_log_cnt = 0;
NSString* showString = @"";

UILabel* expreLabel = nil;

@implementation FaceMeshGpuViewController

#pragma mark - UIViewController methods

- (void)viewDidLoad {
  [super viewDidLoad];

  [self.mediapipeGraph setSidePacket:(mediapipe::MakePacket<int>(kNumFaces))
                               named:kNumFacesInputSidePacket];
  [self.mediapipeGraph addFrameOutputStream:kLandmarksOutputStream
                           outputPacketType:MPPPacketTypeRaw];
    
    CGRect frame = CGRectMake(100, 50, 200, 50);
    expreLabel = [[UILabel alloc]initWithFrame:frame];
    [self.view addSubview:expreLabel];
    [expreLabel setText:@""];
    expreLabel.font = [UIFont systemFontOfSize:30.f];
    expreLabel.font = [UIFont boldSystemFontOfSize:30.f];
    expreLabel.textAlignment = NSTextAlignmentCenter;
    expreLabel.textColor = [UIColor greenColor];
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

- (void)setExpression_happy {
    happy_times++;
    if(happy_times >= DETECT_TIMES) {
//            happyMotion = true;
        NSLog(@"faceEC: =====================高兴=================");
        happy_times = 0;
        showString = @"高兴";
    }
}

- (void)setExpression_normal {
    normal_times++;
    if (normal_times >= DETECT_TIMES) {
//            normalMotion = true;
        NSLog(@"faceEC: =====================自然=================");
        normal_times = 0;
        showString = @"自然";
    }
}

- (void)setExpression_sad {
    sad_times++;
    if(sad_times >= DETECT_TIMES) {
//            sadMotion = true;
        NSLog(@"faceEC: =====================悲伤=================");
        sad_times = 0;
        showString = @"悲伤";
    }
}

- (void)setExpression_angry {
    angry_times++;
    if(angry_times >= DETECT_TIMES) {
//            angryMotion = true;
        NSLog(@"faceEC: =====================愤怒=================");
        angry_times = 0;
        showString = @"愤怒";
    }
}

- (void)setExpression_surprise {
    suprise_times++;
    if(suprise_times >= DETECT_TIMES) {
//            supriseMotion = true;
        NSLog(@"faceEC: =====================惊讶=================");
        suprise_times = 0;
        showString = @"惊讶";
    }
}

#define POINT_NUM  4  //输入线性拟和点

#pragma mark - MPPGraphDelegate methods

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
//    NSLog(@"[TS:%lld] Number of face instances with landmarks: %lu", packet.Timestamp().Value(),
//          multi_face_landmarks.size());
    for (int face_index = 0; face_index < multi_face_landmarks.size(); ++face_index) {
      const auto& landmarks = multi_face_landmarks[face_index];
//      NSLog(@"\tNumber of landmarks for face[%d]: %d", face_index, landmarks.landmark_size());
//      for (int i = 0; i < landmarks.landmark_size(); ++i) {
//        NSLog(@"\t\tLandmark[%d]: (%f, %f, %f)", i, landmarks.landmark(i).x(),
//              landmarks.landmark(i).y(), landmarks.landmark(i).z());
//      }
        //脸宽
        double face_width = 0;
        double face_height = 0;
        //眉毛
        double brow_left_height = 0;
        double brow_right_height = 0;
        double brow_hight = 0;
        double brow_line_left = 0;
        double brow_width = 0;
//        double brow_left_up = 0;
//        double brow_right_up = 0;
        //眼睛
        double eye_left_height = 0;
        double eye_left_width = 0;
        double eye_right_height = 0;
        double eye_right_width = 0;
        double eye_height = 0;
        double eye_width = 0;
        //嘴巴
        double mouth_width = 0;
        double mouth_height = 0;

        //眼角嘴角距离
        double distance_eye_left_mouth = 0;
        double distance_eye_right_mouth = 0;
        double distance_eye_mouth = 0;

//        for (int i = 0; i < landmarkList.getLandmarkCount(); i++) {
//            faceLandmarksStr  += "\t\tLandmark ["
//                                + i + "], "
//                                + landmarks.landmark(i).x() + ", "
//                                + landmarks.landmark(i).y() + ", "
//                                + landmarks.landmark(i).z() + ")\n";
//            Log.i(TAG, faceLandmarksStr);
//        }
        // 1、计算人脸识别框边长(注: 脸Y坐标 下 > 上, X坐标 右 > 左)
        face_width = landmarks.landmark(361).x() - landmarks.landmark(132).x();
        face_height = landmarks.landmark(152).y() - landmarks.landmark(10).y();

        //2、眉毛宽度(注: 脸Y坐标 下 > 上, X坐标 右 > 左 眉毛变短程度: 皱变短(恐惧、愤怒、悲伤))
        brow_width = landmarks.landmark(296).x()-landmarks.landmark(53).x() +
                     landmarks.landmark(334).x()-landmarks.landmark(52).x() +
                     landmarks.landmark(293).x()-landmarks.landmark(65).x() +
                     landmarks.landmark(300).x()-landmarks.landmark(55).x() +
                     landmarks.landmark(285).x()-landmarks.landmark(70).x() +
                     landmarks.landmark(295).x()-landmarks.landmark(63).x() +
                     landmarks.landmark(282).x()-landmarks.landmark(105).x() +
                     landmarks.landmark(283).x()-landmarks.landmark(66).x();

        //2.1、眉毛高度之和
        brow_left_height =      landmarks.landmark(53).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(52).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(65).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(55).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(70).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(63).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(105).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(66).y() - landmarks.landmark(10).y();
        brow_right_height =     landmarks.landmark(283).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(282).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(295).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(285).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(300).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(293).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(334).y() - landmarks.landmark(10).y() +
                                landmarks.landmark(296).y() - landmarks.landmark(10).y();
        brow_hight = brow_left_height + brow_right_height;
        //2.2、眉毛高度与识别框高度之比: 眉毛抬高(惊奇、恐惧、悲伤), 眉毛压低(厌恶, 愤怒)
        double brow_hight_rate = brow_hight/16;
        double brow_width_rate = brow_width/8;
//        // 分析挑眉程度和皱眉程度, 左眉拟合曲线(53-52-65-55-70-63-105-66) - 暂时未使用
        POINTS brow_line_points[POINT_NUM];
        brow_line_points[0].x = landmarks.landmark(55).x();
        brow_line_points[1].x = landmarks.landmark(70).x();
        brow_line_points[2].x = landmarks.landmark(105).x();
        brow_line_points[3].x = landmarks.landmark(107).x();
        
        brow_line_points[0].y = landmarks.landmark(55).y();
        brow_line_points[1].y = landmarks.landmark(70).y();
        brow_line_points[2].y = landmarks.landmark(105).y();
        brow_line_points[3].y = landmarks.landmark(107).y();

        //2.3、眉毛变化程度: 变弯(高兴、惊奇) - 上扬  - 下拉
//        brow_line_left = (landmarks.landmark(105).y() - landmarks.landmark(52).y())/(landmarks.landmark(105).x() - landmarks.landmark(52).x());
        brow_line_left = (-10) * (::mediapipe::getCurveFit(brow_line_points, POINT_NUM)); //调函数拟合直线
        double brow_line_rate = brow_line_left;  // + brow_line_right;
//        brow_left_up = landmarks.landmark(70).y()-landmarks.landmark(10).y()/* + landmarks.landmark(66).y()-landmarks.landmark(10).y()*/;
//        brow_right_up = landmarks.landmark(300).y()-landmarks.landmark(10).y()/* + landmarks.landmark(283).y()-landmarks.landmark(10).y()*/;

        //3、眼睛高度 (注: 眼睛Y坐标 下 > 上, X坐标 右 > 左)
        eye_left_height = landmarks.landmark(23).y() - landmarks.landmark(27).y();   //中心 以后尝试修改为 Y(145) - Y(159) -> Y(23) - Y(27)
        eye_left_width = landmarks.landmark(133).x() - landmarks.landmark(33).x();
        eye_right_height = landmarks.landmark(253).y() - landmarks.landmark(257).y();  // 中心 以后尝试修改为 Y(374) - Y(386) -> Y(253) - Y(257)
        eye_right_width = landmarks.landmark(263).x() - landmarks.landmark(362).x();

        //3.1、眼睛睁开程度: 上下眼睑拉大距离(惊奇、恐惧)
        eye_height = (eye_left_height + eye_right_height)/2;
        eye_width = (eye_left_width + eye_right_width)/2;

        //4、嘴巴宽高(两嘴角间距离- 用于计算嘴巴的宽度 注: 嘴巴Y坐标 上 > 下, X坐标 右 > 左 嘴巴睁开程度- 用于计算嘴巴的高度: 上下嘴唇拉大距离(惊奇、恐惧、愤怒、高兴))
        mouth_width = landmarks.landmark(308).x() - landmarks.landmark(78).x();
        mouth_height = landmarks.landmark(17).y() - landmarks.landmark(0).y();  // 中心

        //4.1、嘴角下拉(厌恶、愤怒、悲伤),    > 1 上扬， < 1 下拉
        double mouth_pull_down = (landmarks.landmark(14).y() - landmarks.landmark(324).y())/(landmarks.landmark(14).y() + landmarks.landmark(324).x());
        //对嘴角进行一阶拟合，曲线斜率
        POINTS lips_line_points[POINT_NUM];
        lips_line_points[0].x = landmarks.landmark(318).x();
        lips_line_points[1].x = landmarks.landmark(324).x();
        lips_line_points[2].x = landmarks.landmark(308).x();
        lips_line_points[3].x = landmarks.landmark(291).x();
        
        lips_line_points[0].y = landmarks.landmark(318).y();
        lips_line_points[1].y = landmarks.landmark(324).y();
        lips_line_points[2].y = landmarks.landmark(308).y();
        lips_line_points[3].y = landmarks.landmark(291).y();
        double mouth_pull_down_rate = (-10) * (::mediapipe::getCurveFit(lips_line_points, POINT_NUM)); //调函数拟合直线
//        Log.i(TAG, "faceEC: mouth_pull_down = "+mouth_pull_down);

        //5、两侧眼角到同侧嘴角距离
        distance_eye_left_mouth = landmarks.landmark(78).y() - landmarks.landmark(133).y();
        distance_eye_right_mouth = landmarks.landmark(308).y() - landmarks.landmark(362).y();
        distance_eye_mouth = distance_eye_left_mouth + distance_eye_right_mouth;

        //6、归一化
        double MM = 0, NN = 0, PP = 0, QQ = 0;
        double dis_eye_mouth_rate = (2 * mouth_width)/distance_eye_mouth;             // 嘴角 / 眼角嘴角距离, 高兴(0.85),愤怒/生气(0.7),惊讶(0.6),大哭(0.75)
        double distance_brow = landmarks.landmark(296).x() - landmarks.landmark(66).x();
        double dis_brow_mouth_rate = mouth_width/distance_brow;                       // 嘴角 / 两眉间距
        double dis_eye_height_mouth_rate = mouth_width/eye_height;                    // 嘴角 / 上下眼睑距离
        double dis_brow_height_mouth_rate = (2 * mouth_width)/(landmarks.landmark(145).y() - landmarks.landmark(70).y());
        // 眉毛上扬与识别框宽度之比
//        double brow_up_rate = (brow_left_up + brow_right_up)/(2*face_width);
//        // 眼睛睁开距离与识别框高度之比
//        double eye_height_rate = eye_height/face_width;
//        double eye_width_rate = eye_width/face_width;
//        // 张开嘴巴距离与识别框高度之比
//        double mouth_width_rate = mouth_width/face_width;
//        double mouth_height_rate = mouth_height/face_width;
//        Log.i(TAG, "faceEC: 眼角嘴 = "+dis_eye_mouth_rate+", \t眉角嘴 = "+dis_brow_mouth_rate+", \t眼高嘴 = "+dis_eye_height_mouth_rate+", \t眉高嘴 = "+dis_brow_height_mouth_rate);

        //7、 求连续多次的平均值
        if(arr_cnt < AVG_CNT) {
            brow_mouth_arr[arr_cnt].v = dis_brow_mouth_rate;
            brow_height_mouth_arr[arr_cnt].v = dis_brow_height_mouth_rate;
            brow_width_arr[arr_cnt].v = brow_width_rate;
            brow_height_arr[arr_cnt].v = brow_hight_rate;
            brow_line_arr[arr_cnt].v = brow_line_rate;
            eye_height_arr[arr_cnt].v = eye_height;
            eye_width_arr[arr_cnt].v = eye_width;
            eye_height_mouth_arr[arr_cnt].v = dis_eye_height_mouth_rate;
            mouth_width_arr[arr_cnt].v = mouth_width;
            mouth_height_arr[arr_cnt].v = mouth_height;
            mouth_pull_down_arr[arr_cnt].v = mouth_pull_down_rate;
        }
        double brow_mouth_avg = 0, brow_height_mouth_avg = 0;
        double brow_width_avg = 0, brow_height_avg = 0, brow_line_avg = 0;
        double eye_height_avg = 0, eye_width_avg = 0, eye_height_mouth_avg = 0;
        double mouth_width_avg = 0, mouth_height_avg = 0, mouth_pull_down_avg = 0;
        arr_cnt++;
        if(arr_cnt >= AVG_CNT) {
            brow_mouth_avg = ::mediapipe::getAverage(brow_mouth_arr, AVG_CNT);
            brow_height_mouth_avg = ::mediapipe::getAverage(brow_height_mouth_arr, AVG_CNT);
            brow_width_avg = ::mediapipe::getAverage(brow_width_arr, AVG_CNT);
            brow_height_avg = ::mediapipe::getAverage(brow_height_arr, AVG_CNT);
            brow_line_avg = ::mediapipe::getAverage(brow_line_arr, AVG_CNT);
            eye_height_avg = ::mediapipe::getAverage(eye_height_arr, AVG_CNT);
            eye_width_avg = ::mediapipe::getAverage(eye_width_arr, AVG_CNT);
            eye_height_mouth_avg = ::mediapipe::getAverage(eye_height_mouth_arr, AVG_CNT);
            mouth_width_avg = ::mediapipe::getAverage(mouth_width_arr, AVG_CNT);
            mouth_height_avg = ::mediapipe::getAverage(mouth_height_arr, AVG_CNT);
            mouth_pull_down_avg = ::mediapipe::getAverage(mouth_pull_down_arr, AVG_CNT);
            arr_cnt = 0;
        }
        if(arr_cnt == 0) {
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
        }

        //8、表情算法
        FACE face;
        face.w = face_width;
        face.h = face_height;
        face.ratio = (landmarks.landmark(362).y() - landmarks.landmark(133).y())/(landmarks.landmark(362).x() - landmarks.landmark(133).x());
        EYEBROWS eyebrows;
        eyebrows.w = brow_width_avg;
        eyebrows.h = brow_height_avg;
        eyebrows.up = brow_line_avg;
        EYES eye;
        eye.w = eye_width_avg;
        eye.h = eye_height_avg;
        MOUTH mouth;
        mouth.w = mouth_width_avg;
        mouth.h = mouth_height_avg;
        mouth.down = mouth_pull_down_avg;

        //9、抛出表情结果
        total_log_cnt++;
        if(total_log_cnt >= AVG_CNT) {
            int expression = ::mediapipe::getFaceExpressionType(face, eyebrows, eye, mouth, dis_eye_mouth_rate);
            switch (expression) {
                case FACE_EXPRESSION_HAPPY:
                    [self setExpression_happy];
                    break;
                case FACE_EXPRESSION_SURPRISE:
                    [self setExpression_surprise];
                    break;
                case FACE_EXPRESSION_NATURE:
                    [self setExpression_normal];
                    break;
                case FACE_EXPRESSION_CRY:
                case FACE_EXPRESSION_SAD:
                    [self setExpression_sad];
                    break;
                case FACE_EXPRESSION_ANGRY:
                    [self setExpression_angry];
                    break;
                case FACE_EXPRESSION_HEADFALSE:
                    NSLog(@"faceEC: ============头部太偏=============");
                    showString = @"头部太偏";
                    break;
                default:
                    break;
            }
//            NSLog(@"faceEC: 挑眉(%f), \t嘴角下拉(%f), \tM(%f), \tMM(%f)\n",
//                  brow_line_avg,
//                  mouth_pull_down_avg,
//                  dis_eye_mouth_rate,
//                  MM);
//            NSLog(@"faceEC: 眉高宽比(%f), \t眼高宽比(%f), \t嘴高宽比(%f), \t眉高嘴(%f), \t眼高嘴(%f)\n",
//                  brow_height_width_rate,
//                  eye_height_width_rate,
//                  mouth_height_width_rate,
//                  brow_height_mouth_avg,
//                  eye_height_mouth_avg);
            total_log_cnt = 0;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [expreLabel setText:showString];
        });
    }
  }
}

@end
