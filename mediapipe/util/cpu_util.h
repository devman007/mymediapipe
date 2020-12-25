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

#define FACE_EXPRESSION_UNKNOW      0
#define FACE_EXPRESSION_HAPPY       1
#define FACE_EXPRESSION_SUPRISE     2
#define FACE_EXPRESSION_CRY         3
#define FACE_EXPRESSION_NATURE      4
#define FACE_EXPRESSION_SAD         5
#define FACE_EXPRESSION_ANGRY       6
#define FACE_EXPRESSION_NERVOUS     7

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

namespace mediapipe {
// Returns the number of CPU cores. Compatible with Android.
int NumCPUCores();
// Returns a set of inferred CPU ids of lower cores.
std::set<int> InferLowerCoreIds();
// Returns a set of inferred CPU ids of higher cores.
std::set<int> InferHigherCoreIds();
/**
 * 拟合曲线
 */
double getCurveFit(POINTS P[], int num);
/**
 * 平均数
 */
double getAverage(DOUBLE arr[], int num);
}  // namespace mediapipe

#endif  // MEDIAPIPE_UTIL_CPU_UTIL_H_
