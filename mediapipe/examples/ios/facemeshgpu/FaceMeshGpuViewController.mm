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

static NSString* const kGraphName = @"face_mesh_mobile_gpu";

static const char* kNumFacesInputSidePacket = "num_faces";
static const char* kLandmarksOutputStream = "multi_face_landmarks";

// Max number of faces to detect/process.
static const int kNumFaces = 1;

#define AVG_CNT 10
#define DETECT_TIMES 2

NSMutableArray* brow_up_arr;
NSMutableArray* brow_width_arr;
NSMutableArray* brow_height_arr;
NSMutableArray* brow_line_arr;
NSMutableArray* brow_mouth_arr;
NSMutableArray* brow_height_mouth_arr;
NSMutableArray* eye_height_arr;
NSMutableArray* eye_width_arr;
NSMutableArray* eye_height_mouth_arr;
NSMutableArray* mouth_width_arr;
NSMutableArray* mouth_height_arr;
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
    brow_up_arr = [[NSMutableArray alloc] init];
    brow_width_arr = [[NSMutableArray alloc] init];
    brow_height_arr = [[NSMutableArray alloc] init];
    brow_line_arr = [[NSMutableArray alloc] init];
    brow_mouth_arr = [[NSMutableArray alloc] init];
    brow_height_mouth_arr = [[NSMutableArray alloc] init];
    eye_height_arr = [[NSMutableArray alloc] init];
    eye_width_arr = [[NSMutableArray alloc] init];
    eye_height_mouth_arr = [[NSMutableArray alloc] init];
    mouth_width_arr = [[NSMutableArray alloc] init];
    mouth_height_arr = [[NSMutableArray alloc] init];
    
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
 * 求平均数
 * @param type - 类型标签
 * @param arr - 数值数值
 * @param num - 保留有效数
 * @return
 */
- (float)getAverage:(NSString*)type Arr:(NSMutableArray*)arr Num:(int)num {
    float avg = 0, sum = 0;
    int len = [arr count];
    for(int i = 0; i < len; i++) {
        float tmp = [[arr objectAtIndex:i] floatValue];
        sum += tmp;
    }
    avg = sum/len;
//    Log.i(TAG, "faceEC average: "+type+", avg = "+avg);
    return avg;
}

/**
 四舍五入字符串
 @param round 小数位 eg: 4
 @param numberString 数字 eg 0.125678
 @return 四舍五入之后的 eg: 0.1257
 */
- (float)getRound:(float)val Num:(int)round {
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
        float face_width = 0;
        float face_height = 0;
        //眉毛
        float brow_left_height = 0;
        float brow_right_height = 0;
        float brow_hight = 0;
        float brow_line_left = 0;
        float brow_width = 0;
        float brow_left_up = 0;
        float brow_right_up = 0;
        //眼睛
        float eye_left_height = 0;
        float eye_left_width = 0;
        float eye_right_height = 0;
        float eye_right_width = 0;
        float eye_height = 0;
        //嘴巴
        float mouth_width = 0;
        float mouth_height = 0;

        //眼角嘴角距离
        float distance_eye_left_mouth = 0;
        float distance_eye_right_mouth = 0;
        float distance_eye_mouth = 0;

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
        //2.2、眉毛高度与识别框高度之比: 眉毛抬高(惊奇、恐惧、悲伤), 眉毛压低(厌恶, 愤怒) - Solution 1(7-1)
        float brow_hight_rate = (brow_hight/16)/face_width;
        float brow_width_rate = (brow_width/8)/face_width;
//        // 分析挑眉程度和皱眉程度, 左眉拟合曲线(53-52-65-55-70-63-105-66) - 暂时未使用
//        float line_brow_x[] = new float[3];
//        line_brow_x[0] = landmarks.landmark(52).x();
//        line_brow_x[1] = landmarks.landmark(70).x();
//        line_brow_x[2] = landmarks.landmark(105).x();
//        float line_brow_y[] = new float[3];
//        line_brow_y[0] = landmarks.landmark(52).y();
//        line_brow_y[1] = landmarks.landmark(70).y();
//        line_brow_y[2] = landmarks.landmark(105).y();
//        WeightedObservedPoints points = new WeightedObservedPoints();
//        for(int i = 0; i < line_brow_x.length; i++) {
//            points.add(line_brow_x[i], line_brow_y[i]);
//        }
//        PolynomialCurveFitter fitter = PolynomialCurveFitter.create(1); //指定为1阶数
//        double[] result = fitter.fit(points.toList());
//        if(result[1]*(-10) < 1.0) { //倒八眉
//
//        } else {                     //八字眉 或平眉
//
//        }

        //2.3、眉毛变化程度: 变弯(高兴、惊奇) - 上扬  - 下拉 - Solution 1(7-2) - 临时关闭(未使用)
        brow_line_left = (landmarks.landmark(105).y() - landmarks.landmark(52).y())/(landmarks.landmark(105).x() - landmarks.landmark(52).x());
        float brow_line_rate = brow_line_left;  // + brow_line_right;
        brow_left_up = landmarks.landmark(70).y()-landmarks.landmark(10).y()/* + landmarks.landmark(66).y()-landmarks.landmark(10).y()*/;
        brow_right_up = landmarks.landmark(300).y()-landmarks.landmark(10).y()/* + landmarks.landmark(283).y()-landmarks.landmark(10).y()*/;

        //3、眼睛高度 (注: 眼睛Y坐标 下 > 上, X坐标 右 > 左)
        eye_left_height = landmarks.landmark(145).y() - landmarks.landmark(159).y();   //中心
        eye_left_width = landmarks.landmark(133).x() - landmarks.landmark(33).x();
        eye_right_height = landmarks.landmark(374).y() - landmarks.landmark(386).y();  // 中心
        eye_right_width = landmarks.landmark(263).x() - landmarks.landmark(362).x();

        //3.1、眼睛睁开程度: 上下眼睑拉大距离(惊奇、恐惧) - Solution 1(7-4)
        eye_height = eye_left_height + eye_right_height;
        // 两眼角距离
        float eye_width_sum = eye_left_width + eye_right_width;

        //4、嘴巴宽高(两嘴角间距离- 用于计算嘴巴的宽度 注: 嘴巴Y坐标 上 > 下, X坐标 右 > 左 嘴巴睁开程度- 用于计算嘴巴的高度: 上下嘴唇拉大距离(惊奇、恐惧、愤怒、高兴))
        mouth_width = landmarks.landmark(308).x() - landmarks.landmark(78).x();
        mouth_height = landmarks.landmark(14).y() - landmarks.landmark(0).y();  // 中心

        //4.1、嘴角下拉(厌恶、愤怒、悲伤),    > 1 上扬， < 1 下拉 - Solution 1(7-7)
        float mouth_line_rate = ((landmarks.landmark(78).y() + landmarks.landmark(308).y()))/(landmarks.landmark(14).y() + landmarks.landmark(0).y());
//        Log.i(TAG, "faceEC: mouth_line_rate = "+mouth_line_rate);

        //5、两侧眼角到同侧嘴角距离
        distance_eye_left_mouth = landmarks.landmark(78).y() - landmarks.landmark(133).y();
        distance_eye_right_mouth = landmarks.landmark(308).y() - landmarks.landmark(362).y();
        distance_eye_mouth = distance_eye_left_mouth + distance_eye_right_mouth;

        //6、归一化
        float MM = 0, NN = 0, PP = 0, QQ = 0;
        float dis_eye_mouth_rate = (2 * mouth_width)/distance_eye_mouth;             // 嘴角 / 眼角嘴角距离, 高兴(0.85),愤怒/生气(0.7),惊讶(0.6),大哭(0.75)
        float distance_brow = landmarks.landmark(296).x() - landmarks.landmark(66).x();
        float dis_brow_mouth_rate = mouth_width/distance_brow;                       // 嘴角 / 两眉间距
        float dis_eye_height_mouth_rate = (1 * mouth_width)/((eye_height)/2);        // 嘴角 / 上下眼睑距离
        float dis_brow_height_mouth_rate = (2 * mouth_width)/(landmarks.landmark(145).y() - landmarks.landmark(70).y());
        // 眉毛上扬与识别框宽度之比
        float brow_up_rate = (brow_left_up + brow_right_up)/(2*face_width);
        // 眼睛睁开距离与识别框高度之比
        float eye_height_rate = eye_height/(2*face_width);
        float eye_width_rate = eye_width_sum/(2*face_width);
        // 张开嘴巴距离与识别框高度之比
        float mouth_width_rate = mouth_width/face_width;
        float mouth_height_rate = mouth_height/face_width;
//        Log.i(TAG, "faceEC: 眼角嘴 = "+dis_eye_mouth_rate+", \t眉角嘴 = "+dis_brow_mouth_rate+", \t眼高嘴 = "+dis_eye_height_mouth_rate+", \t眉高嘴 = "+dis_brow_height_mouth_rate);

        //7、 求连续多次的平均值
        [brow_mouth_arr addObject:[NSNumber numberWithFloat:dis_brow_mouth_rate]];
        [brow_height_mouth_arr addObject:[NSNumber numberWithFloat:dis_brow_height_mouth_rate]];
        [eye_height_mouth_arr addObject:[NSNumber numberWithFloat:dis_eye_height_mouth_rate]];
        [brow_up_arr addObject:[NSNumber numberWithFloat:brow_up_rate]];
        [brow_width_arr addObject:[NSNumber numberWithFloat:brow_width_rate]];
        [brow_height_arr addObject:[NSNumber numberWithFloat:brow_hight_rate]];
        [brow_line_arr addObject:[NSNumber numberWithFloat:brow_line_rate]];
        [eye_height_arr addObject:[NSNumber numberWithFloat:eye_height_rate]];
        [eye_width_arr addObject:[NSNumber numberWithFloat:eye_width_rate]];
        [mouth_width_arr addObject:[NSNumber numberWithFloat:mouth_width_rate]];
        [mouth_height_arr addObject:[NSNumber numberWithFloat:mouth_height_rate]];
        float brow_mouth_avg = 0, brow_height_mouth_avg = 0;
        float brow_up_avg = 0, brow_width_avg = 0, brow_height_avg = 0, brow_line_avg = 0;
        float eye_height_avg = 0, eye_width_avg = 0, eye_height_mouth_avg = 0;
        float mouth_width_avg = 0, mouth_height_avg = 0;
        arr_cnt++;
        if(arr_cnt >= AVG_CNT) {
            brow_mouth_avg = [self getAverage:@"眉角嘴" Arr:brow_mouth_arr Num:4];
            brow_height_mouth_avg = [self getAverage:@"眉高嘴" Arr:brow_height_mouth_arr Num:4];
            brow_up_avg = [self getAverage:@"眉上扬" Arr:brow_up_arr Num:4];
            brow_width_avg = [self getAverage:@"眉宽" Arr:brow_width_arr Num:4];
            brow_height_avg = [self getAverage:@"眉高" Arr:brow_height_arr Num:4];
            brow_line_avg = [self getAverage:@"挑眉" Arr:brow_line_arr Num:4];
            eye_height_avg = [self getAverage:@"眼睁" Arr:eye_height_arr Num:4];
            eye_width_avg = [self getAverage:@"眼宽" Arr:eye_width_arr Num:4];
            eye_height_mouth_avg = [self getAverage:@"眼高嘴" Arr:eye_height_mouth_arr Num:4];
            mouth_width_avg = [self getAverage:@"嘴宽" Arr:mouth_width_arr Num:4];
            mouth_height_avg = [self getAverage:@"嘴张" Arr:mouth_height_arr Num:4];
            arr_cnt = 0;
        }

        //8、表情算法
        float brow_height_width_rate = brow_height_avg/brow_width_avg;
        float eye_width_height_rate = eye_width_avg/eye_height_avg;
        float mouth_width_height_rate = mouth_width_avg/mouth_height_avg;

        if(dis_eye_mouth_rate <= 0.7) {
            MM = dis_eye_mouth_rate * 0;
        } else if((dis_eye_mouth_rate > 0.7) &&(dis_eye_mouth_rate <= 0.75)) {    // 微笑
            MM = (float)(dis_eye_mouth_rate * 1.38);
        } else if((dis_eye_mouth_rate > 0.75) &&(dis_eye_mouth_rate <= 0.8)) {
            MM = (float)(dis_eye_mouth_rate * 2.58);
        } else if((dis_eye_mouth_rate > 0.8) &&(dis_eye_mouth_rate <= 0.9)) {
            MM = (float)(dis_eye_mouth_rate * 3.54);
        } else if((dis_eye_mouth_rate > 0.9) &&(dis_eye_mouth_rate <= 1.0)) {     //大笑
            MM = (float)(dis_eye_mouth_rate * 4.22);
        } else if(dis_eye_mouth_rate > 1) {
            MM = (float)(dis_eye_mouth_rate * 5.0);
        }

        if(brow_height_width_rate <= 0.365f) {
            NN = (brow_height_width_rate * 0);
        } else if((brow_height_width_rate > 0.365f)&&(brow_height_width_rate <= 0.405f)) {
            NN = (brow_height_width_rate * 3.58f);
        } else if((brow_height_width_rate > 0.405f)&&(brow_height_width_rate <= 0.455f)) {
            NN = (brow_height_width_rate * 4.22f);
        } else if(brow_height_width_rate > 0.455f) {
            NN = (brow_height_width_rate * 5);
        }

        if(eye_width_height_rate <= 3.10f) {
            PP = (eye_width_height_rate * 0);
        } else if((eye_width_height_rate > 3.10f ) &&(eye_width_height_rate <= 4.10f)){
            PP = (eye_width_height_rate * 3.58f);
        } else {
            PP = (eye_width_height_rate * 4.58f);
        }

        //9、判断头部倾斜度
        float head_line_rate = (landmarks.landmark(362).y() - landmarks.landmark(133).y())/(landmarks.landmark(362).x() - landmarks.landmark(133).x());
        if(abs(head_line_rate) >= 0.5f) {
            NSLog(@"faceEC: ============头部太偏=============");
            showString = @"头部太偏";
        }

        //10、抛出表情结果
        total_log_cnt++;
        if(total_log_cnt >= AVG_CNT) {
            if((mouth_width_height_rate >= 6.0) /*&&(MM == 0)*/) {
                if(MM >= 2.5f) {
                    [self setExpression_sad];
                } else {
                    if(PP >= 11.0) {
//                        [self setExpression_angry];
//                    } else {
                        [self setExpression_normal];
                    }
                }
            } else if((mouth_width_height_rate < 4.0) &&(MM <= 2.0)) {
                [self setExpression_surprise];
            } else {
                if((eye_width_height_rate >= 4.5f) &&(mouth_line_rate >= 1.0)) {
                    [self setExpression_sad];
                } else {
                    if((brow_up_avg * 10 >= 2.6) &&(MM >= 3.0) &&((dis_brow_height_mouth_rate >= 4.0)||(eye_width_height_rate >= 6.0))){
                        [self setExpression_happy];
                    } else if(MM < 2.0) {
                        [self setExpression_angry];
                    }
                }
            }
            NSLog(@"faceEC: 眉高(%f), \t眉宽(%f), \t眉上扬(%f), \t挑眉(%f), \t眼睁(%f), \t嘴宽(%f), \t嘴张(%f)\n",
                  brow_height_avg, brow_width_avg, brow_up_avg*100, brow_line_avg,
                  eye_height_avg,
                  mouth_width_avg, mouth_height_avg);
            NSLog(@"faceEC: 眉高宽比(%f), \t眉角嘴(%f), \t眉高嘴(%f), \t眼宽高比(%f), \t眼高嘴(%f), \t嘴宽高比(%f)\n",
                  brow_height_width_rate,
                  brow_mouth_avg,
                  brow_height_mouth_avg,
                  eye_width_height_rate,
                  eye_height_mouth_avg,
                  mouth_width_height_rate);
            NSLog(@"faceEC: M(%f), \tMM(%f), \tN(%f), \tNN(%f), \tP(%f), \tPP(%f)\n",
                  dis_eye_mouth_rate, MM,
                  brow_height_width_rate, NN,
                  eye_width_height_rate, PP);
            total_log_cnt = 0;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [expreLabel setText:showString];
        });
    }
  }
}

@end
