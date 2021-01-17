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

#ifndef MEDIAPIPE_UTIL_CPU_UTIL_H_
#define MEDIAPIPE_UTIL_CPU_UTIL_H_

#include <set>

// add by jacky
#define FACE_EXPRESSION_UNKNOW      0
#define FACE_EXPRESSION_HAPPY       1
#define FACE_EXPRESSION_SURPRISE    2
#define FACE_EXPRESSION_CRY         3
#define FACE_EXPRESSION_NATURE      4
#define FACE_EXPRESSION_SAD         5
#define FACE_EXPRESSION_ANGRY       6
#define FACE_EXPRESSION_NERVOUS     7
#define FACE_EXPRESSION_HEADFALSE   8

// 坐标点
typedef struct POINTS {
    double x;
    double y;
    double z;
} POINTS;

// 存储double
typedef struct DOUBLE {
    double v;
} DOUBLE;

// 五官宽高
typedef struct MOUTH {
    double w;
    double h;
    double down;
    double brow_h_mouth;
} MOUTHS;

typedef struct EYES {
    double w;
    double h;
    double eye_mouth;
} EYES;

typedef struct EYEBROWS {
    double w;
    double h;
    double up;
} EYEBROWS;

typedef struct FACE {
    double w;
    double h;
    double ratio;
} FACE;
// end add.

namespace mediapipe {
// Returns the number of CPU cores. Compatible with Android.
int NumCPUCores();
// Returns a set of inferred CPU ids of lower cores.
std::set<int> InferLowerCoreIds();
// Returns a set of inferred CPU ids of higher cores.
std::set<int> InferHigherCoreIds();
// add by jacky
/**
 * 拟合曲线
 * for ios
 */
double getCurveFit(POINTS P[], int num);
/*
 * for android
 */
double getCurveFit_android(double pX[], double pY[], int num);
/**
 * 平均数
 * for ios
 */
double getAverage(DOUBLE arr[], int num);
/*
 * for android
 */
double getAverage_android(double arr[], int num);
/**
 * 脸部参数
 * w - 宽
 * h - 高
 * ratio - 脸部倾斜度
 */
int setFaceExpressionFace(double w, double h, double ratio);
/**
 * 眉毛参数
 * w - 宽
 * h - 高
 * up - 眉毛上扬度
 */
int setFaceExpressionBrow(double w, double h, double up);
/**
 * 眼睛参数
 * w - 宽
 * h - 高
 * eye_mouth - 眼角到嘴角距离
 */
int setFaceExpressionEye(double w, double h, double eye_mouth);
/**
 * 嘴巴参数
 * w - 宽
 * h - 高
 * down - 嘴角下拉度
 * brow_h_mouth - 眉毛高度与嘴巴宽度比
 */
int setFaceExpressionMouth(double w, double h, double down, double brow_h_mouth); 
/**
 * 表情算法
 */
int getFaceExpressionType();
// end add.
}  // namespace mediapipe

#endif  // MEDIAPIPE_UTIL_CPU_UTIL_H_
