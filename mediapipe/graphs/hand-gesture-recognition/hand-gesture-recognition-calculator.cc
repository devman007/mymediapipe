#include <cmath>
#include "mediapipe/framework/calculator_framework.h"
#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/framework/formats/rect.pb.h"

namespace mediapipe {

namespace {
constexpr char normRectTag[] = "NORM_RECT";
constexpr char normalizedLandmarkListTag[] = "NORM_LANDMARKS";
constexpr char recognizedHandGestureTag[] = "RECOGNIZED_HAND_GESTURE";
} // namespace

// Graph config:
//
// node {
//   calculator: "HandGestureRecognitionCalculator"
//   input_stream: "NORM_LANDMARKS:scaled_landmarks"
//   input_stream: "NORM_RECT:hand_rect_for_next_frame"
// }
class HandGestureRecognitionCalculator : public CalculatorBase {
public:
    static ::mediapipe::Status GetContract(CalculatorContract *cc);
    ::mediapipe::Status Open(CalculatorContext *cc) override;

    ::mediapipe::Status Process(CalculatorContext *cc) override;

private:
    float get_Euclidean_DistanceAB(float a_x, float a_y, float b_x, float b_y) {
        float dist = std::pow(a_x - b_x, 2) + pow(a_y - b_y, 2);
        return std::sqrt(dist);
    }

    bool isThumbConnectFinger_1(NormalizedLandmark point1, NormalizedLandmark point2) {
        float distance = this->get_Euclidean_DistanceAB(point1.x(), point1.y(), point2.x(), point2.y());
        return distance < 0.1;
    }
};

REGISTER_CALCULATOR(HandGestureRecognitionCalculator);

::mediapipe::Status HandGestureRecognitionCalculator::GetContract(CalculatorContract *cc) {
    RET_CHECK(cc->Inputs().HasTag(normalizedLandmarkListTag));
    cc->Inputs().Tag(normalizedLandmarkListTag).Set<mediapipe::NormalizedLandmarkList>();

    RET_CHECK(cc->Inputs().HasTag(normRectTag));
    cc->Inputs().Tag(normRectTag).Set<NormalizedRect>();

    RET_CHECK(cc->Outputs().HasTag(recognizedHandGestureTag));
    cc->Outputs().Tag(recognizedHandGestureTag).Set<std::string>();

    return ::mediapipe::OkStatus();
}

::mediapipe::Status HandGestureRecognitionCalculator::Open(CalculatorContext *cc) {
    cc->SetOffset(TimestampDiff(0));
    return ::mediapipe::OkStatus();
}

::mediapipe::Status HandGestureRecognitionCalculator::Process(CalculatorContext *cc) {
    std::string *recognized_hand_gesture;

    // hand closed (red) rectangle
    const auto rect = &(cc->Inputs().Tag(normRectTag).Get<NormalizedRect>());
    float width = rect->width();
    float height = rect->height();

    if (width < 0.01 || height < 0.01) {
        // LOG(INFO) << "No Hand Detected";
        recognized_hand_gesture = new std::string("__");
        cc->Outputs()
            .Tag(recognizedHandGestureTag)
            .Add(recognized_hand_gesture, cc->InputTimestamp());
        return ::mediapipe::OkStatus();
    }

    const auto &landmarkList = cc->Inputs()
                                   .Tag(normalizedLandmarkListTag)
                                   .Get<mediapipe::NormalizedLandmarkList>();
    RET_CHECK_GT(landmarkList.landmark_size(), 0) << "Input landmark vector is empty.";

    // finger states
    bool isThumb = false;
    bool isFinger_1 = false;
    bool isFinger_2 = false;
    bool isFinger_3 = false;
    bool isFinger_4 = false;

    if (landmarkList.landmark(3).x() < landmarkList.landmark(2).x() && landmarkList.landmark(4).x() < landmarkList.landmark(2).x()) {
        isThumb = true;
    }
    if (landmarkList.landmark(7).y() < landmarkList.landmark(6).y() && landmarkList.landmark(8).y() < landmarkList.landmark(6).y()) {
        isFinger_1 = true;
    }
    if (landmarkList.landmark(11).y() < landmarkList.landmark(10).y() && landmarkList.landmark(12).y() < landmarkList.landmark(10).y()) {
        isFinger_2 = true;
    }
    if (landmarkList.landmark(15).y() < landmarkList.landmark(14).y() && landmarkList.landmark(16).y() < landmarkList.landmark(14).y()) {
        isFinger_3 = true;
    }
    if (landmarkList.landmark(19).y() < landmarkList.landmark(18).y() && landmarkList.landmark(20).y() < landmarkList.landmark(18).y()) {
        isFinger_4 = true;
    }

    // Hand gesture recognition
    if (isThumb && isFinger_1 && isFinger_2 && isFinger_3 && isFinger_4) {
        recognized_hand_gesture = new std::string("FIVE");
    } else if (!isThumb && isFinger_1 && isFinger_2 && isFinger_3 && isFinger_4) {
        recognized_hand_gesture = new std::string("FOUR");
    } else if (isThumb && isFinger_1 && isFinger_2 && !isFinger_3 && !isFinger_4) {
        recognized_hand_gesture = new std::string("TREE");
    } else if (isThumb && isFinger_1 && !isFinger_2 && !isFinger_3 && !isFinger_4) {
        recognized_hand_gesture = new std::string("TWO");
    } else if (!isThumb && isFinger_1 && !isFinger_2 && !isFinger_3 && !isFinger_4) {
        recognized_hand_gesture = new std::string("ONE");
    } else if (!isThumb && isFinger_1 && isFinger_2 && !isFinger_3 && !isFinger_4) {
        recognized_hand_gesture = new std::string("YEAH");
    } else if (!isThumb && isFinger_1 && !isFinger_2 && !isFinger_3 && isFinger_4) {
        recognized_hand_gesture = new std::string("ROCK");
    } else if (isThumb && isFinger_1 && !isFinger_2 && !isFinger_3 && isFinger_4) {
        recognized_hand_gesture = new std::string("SPIDERMAN");
    } else if (!isThumb && !isFinger_1 && !isFinger_2 && !isFinger_3 && !isFinger_4) {
        recognized_hand_gesture = new std::string("FIST");
    } else if (!isFinger_1 && isFinger_2 && isFinger_3 && isFinger_4 && this->isThumbConnectFinger_1(landmarkList.landmark(4), landmarkList.landmark(8))) {
        recognized_hand_gesture = new std::string("OK");
    } else {
        recognized_hand_gesture = new std::string("__");
        // LOG(INFO) << "Finger States: " << isThumb << isFinger_1 << isFinger_2 << isFinger_3 << isFinger_4;
    }
    // LOG(INFO) << recognized_hand_gesture;

    cc->Outputs()
        .Tag(recognizedHandGestureTag)
        .Add(recognized_hand_gesture, cc->InputTimestamp());

    return ::mediapipe::OkStatus();
} // namespace mediapipe
} // namespace mediapipe
