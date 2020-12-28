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

#include "mediapipe/util/cpu_util.h"

#include <cmath>

#ifdef __ANDROID__
#include "ndk/sources/android/cpufeatures/cpu-features.h"
#elif _WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif
#include <fstream>

#include "absl/algorithm/container.h"
#include "absl/strings/numbers.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/substitute.h"
#include "mediapipe/framework/port/canonical_errors.h"
#include "mediapipe/framework/port/integral_types.h"
#include "mediapipe/framework/port/statusor.h"

namespace mediapipe {
namespace {

constexpr uint32 kBufferLength = 64;

::mediapipe::StatusOr<std::string> GetFilePath(int cpu) {
  return absl::Substitute(
      "/sys/devices/system/cpu/cpu$0/cpufreq/cpuinfo_max_freq", cpu);
}

::mediapipe::StatusOr<uint64> GetCpuMaxFrequency(int cpu) {
  auto path_or_status = GetFilePath(cpu);
  if (!path_or_status.ok()) {
    return path_or_status.status();
  }
  std::ifstream file;
  file.open(path_or_status.ValueOrDie());
  if (file.is_open()) {
    char buffer[kBufferLength];
    file.getline(buffer, kBufferLength);
    file.close();
    uint64 frequency;
    if (absl::SimpleAtoi(buffer, &frequency)) {
      return frequency;
    } else {
      return mediapipe::InvalidArgumentError(
          absl::StrCat("Invalid frequency: ", buffer));
    }
  } else {
    return mediapipe::NotFoundError(
        absl::StrCat("Couldn't read ", path_or_status.ValueOrDie()));
  }
}

std::set<int> InferLowerOrHigherCoreIds(bool lower) {
  std::vector<std::pair<int, uint64>> cpu_freq_pairs;
  for (int cpu = 0; cpu < NumCPUCores(); ++cpu) {
    auto freq_or_status = GetCpuMaxFrequency(cpu);
    if (freq_or_status.ok()) {
      cpu_freq_pairs.push_back({cpu, freq_or_status.ValueOrDie()});
    }
  }
  if (cpu_freq_pairs.empty()) {
    return {};
  }

  absl::c_sort(cpu_freq_pairs, [lower](const std::pair<int, uint64>& left,
                                       const std::pair<int, uint64>& right) {
    return (lower && left.second < right.second) ||
           (!lower && left.second > right.second);
  });
  uint64 edge_freq = cpu_freq_pairs[0].second;

  std::set<int> inferred_cores;
  for (const auto& cpu_freq_pair : cpu_freq_pairs) {
    if ((lower && cpu_freq_pair.second > edge_freq) ||
        (!lower && cpu_freq_pair.second < edge_freq)) {
      break;
    }
    inferred_cores.insert(cpu_freq_pair.first);
  }

  // If all the cores have the same frequency, there are no "lower" or "higher"
  // cores.
  if (inferred_cores.size() == cpu_freq_pairs.size()) {
    return {};
  } else {
    return inferred_cores;
  }
}
}  // namespace

int NumCPUCores() {
#ifdef __ANDROID__
  return android_getCpuCount();
#elif _WIN32
  SYSTEM_INFO sysinfo;
  GetSystemInfo(&sysinfo);
  return sysinfo.dwNumberOfProcessors;
#else
  return sysconf(_SC_NPROCESSORS_ONLN);
#endif
}

std::set<int> InferLowerCoreIds() {
  return InferLowerOrHigherCoreIds(/* lower= */ true);
}

std::set<int> InferHigherCoreIds() {
  return InferLowerOrHigherCoreIds(/* lower= */ false);
}

/*
 要求的方程为: y=ax+b。
          N∑xy-∑x∑y
 其中：a = ----------------
          N∑(x^2)-(∑x)^2
      
             b=y-ax
           ∑y∑(x^2)-∑x∑xy
      b = ---------------
          N∑(x^2)-(∑x)^2
 设：A=∑xy  B=∑x  C=∑y  D=∑(x^2)
 注：N为要拟合的点数量
 
参数说明：
P[POINT_NUM]：传入要线性拟合的点数据（结构体数组）
N：线性拟合的点的数量
b0:直线截距参数存放地址
返回值：曲线斜率, 自左向右 >0(上扬), <0(下拉)
*/
double getCurveFit(POINTS P[], int num) {
    double K = 0, A = 0, B = 0, C = 0, D = 0;
    for(int i = 0; i < num; i++){
        A += P[i].x * P[i].y;
        B += P[i].x;
        C += P[i].y;
        D += P[i].x * P[i].x;
    }
    K = (num*A-B*C)/(num*D-B*B);
    return K;
}

double getCurveFit_android(double pX[], double pY[], int num) {
  double K = 0, A = 0, B = 0, C = 0, D = 0;
  for(int i = 0; i < num; i++){
      A += pX[i] * pY[i];
      B += pX[i];
      C += pY[i];
      D += pX[i] * pX[i];
  }
  K = (num*A-B*C)/(num*D-B*B);
  return K;
}

/**
* 求平均数
* @param type - 类型标签
* @param arr - 数值数值
* @param num - 保留有效数
* @return
*/
double getAverage(DOUBLE arr[], int num) {
    double avg = 0, sum = 0;
    int len = num;
    for(int i = 0; i < len; i++) {
        sum += arr[i].v;
    }
    avg = sum/len;

    return avg;
}

double getAverage_android(double arr[], int num) {
    double avg = 0, sum = 0;
    int len = num;
    for(int i = 0; i < len; i++) {
        sum += arr[i];
    }
    avg = sum/len;

    return avg;
}

static FACE g_face;
static EYEBROWS g_brow;
static EYES g_eye;
static MOUTH g_mouth;
int setFaceExpressionFace(double w, double h, double ratio) {
  int ret = 0;
  g_face.w = w;
  g_face.h = h;
  g_face.ratio = ratio;
  return ret;
}

int setFaceExpressionBrow(double w, double h, double up) {
  int ret = 0;
  g_brow.w = w;
  g_brow.h = h;
  g_brow.up = up;
  return ret;
}

int setFaceExpressionEye(double w, double h, double eye_mouth) {
  int ret = 0;
  g_eye.w = w;
  g_eye.h = h;
  g_eye.eye_mouth = eye_mouth;
  return ret;
}

int setFaceExpressionMouth(double w, double h, double down, double brow_h_mouth) {
  int ret = 0;
  g_mouth.w = w;
  g_mouth.h = h;
  g_mouth.down = down;
  g_mouth.brow_h_mouth = brow_h_mouth;
  return ret;
}

int getFaceExpressionType() {
    int ret = 0;
    double mouth_h_w, eye_h_w, brow_h_w;
    double eye_rate, brow_rate, eye_mouth_rate;
    
    if(abs(g_face.ratio) >= 0.5f) {    //判断头部倾斜度
        return FACE_EXPRESSION_HEADFALSE;
    }
    
    mouth_h_w = g_mouth.h/g_mouth.w;
    brow_h_w = g_brow.h/g_brow.w;
    eye_h_w = g_eye.h/g_eye.w;
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
    if(g_eye.eye_mouth <= 0.7) {
        eye_mouth_rate = g_eye.eye_mouth * 0;
    } else if((g_eye.eye_mouth > 0.7) &&(g_eye.eye_mouth <= 0.75)) {    // 微笑
        eye_mouth_rate = (g_eye.eye_mouth * 1.38);
    } else if((g_eye.eye_mouth > 0.75) &&(g_eye.eye_mouth <= 0.8)) {
        eye_mouth_rate = (g_eye.eye_mouth * 2.58);
    } else if((g_eye.eye_mouth > 0.8) &&(g_eye.eye_mouth <= 0.9)) {
        eye_mouth_rate = (g_eye.eye_mouth * 3.54);
    } else if((g_eye.eye_mouth > 0.9) &&(g_eye.eye_mouth <= 1.0)) {     //大笑
        eye_mouth_rate = (g_eye.eye_mouth * 4.22);
    } else if(g_eye.eye_mouth > 1) {
        eye_mouth_rate = (g_eye.eye_mouth * 5.0);
    }
    
    printf("faceEC: %s 挑眉(%f), \t嘴角下拉(%f), \t眼角嘴(%f), \t眼角嘴2(%f)\n",
          __FUNCTION__,
          g_brow.up,
          g_mouth.down,
          g_eye.eye_mouth,
          eye_mouth_rate);
    printf("faceEC: %s 眉高宽比(%f), \t眼高宽比(%f), \t嘴高宽比(%f)\n",
          __FUNCTION__,
          brow_h_w,
          eye_h_w,
          mouth_h_w);
          
#ifdef __ANDROID__
    if(mouth_h_w <= 0.385) {   //没有张嘴：正常、伤心、气愤
        if(g_mouth.down >= 2.0f){
            return FACE_EXPRESSION_SAD;
        } else if(g_mouth.down <= 1.0) {
            return FACE_EXPRESSION_NATURE;
        } else {
            return FACE_EXPRESSION_ANGRY;
        }
    } else {    //张嘴：高兴、气愤、悲伤、惊讶
        if((mouth_h_w > 0.667) &&(eye_mouth_rate <= 2.0f)) {
            return FACE_EXPRESSION_SURPRISE;
        } else {
            if ((eye_h_w <= 0.222) && (g_mouth.down >= 1.0f)) {
                return FACE_EXPRESSION_SAD;
            } else {
                if ((eye_mouth_rate >= 3.0f) && ((g_mouth.brow_h_mouth >= 4.0f) /*|| (eye_h_w >= 0.167)*/)) {
                    return FACE_EXPRESSION_HAPPY;
                } else if (eye_mouth_rate < 2.0f) {
                    return FACE_EXPRESSION_ANGRY;
                }
            }
        }
    }
#else // __ANDROID__
    if((mouth_h_w <= 0.25)) { //没有张嘴：正常、伤心、气愤
        if(eye_mouth_rate >= 7.5f) {
            return FACE_EXPRESSION_SAD;
        } else {
            if(g_mouth.down >= 0.90) {   //brow_line_avg*(-10) >= 3.5
                return FACE_EXPRESSION_ANGRY;
            } else {
                return FACE_EXPRESSION_NATURE;
            }
        }
    } else {    //张嘴：高兴、气愤、悲伤、惊讶
        if((mouth_h_w > 0.286) &&(eye_mouth_rate <= 7.10)) {
            return FACE_EXPRESSION_SURPRISE;
        } else {
            if(eye_h_w <= 0.5) {
                if((eye_mouth_rate >= 7.0) &&(g_mouth.down > 2.5)) {
                    return FACE_EXPRESSION_HAPPY;
                } else {
                    return FACE_EXPRESSION_ANGRY;
                }
            } else {
                return FACE_EXPRESSION_SAD;
            }
        }
    }
#endif   

    return ret;
}

}  // namespace mediapipe.
