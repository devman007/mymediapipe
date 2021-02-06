package com.example.handtracking;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import android.annotation.SuppressLint;
import android.content.pm.ApplicationInfo;
import android.graphics.Color;
import android.graphics.SurfaceTexture;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;
import android.util.Size;
import android.view.GestureDetector;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.fx.handspipe.HandGesture;
import com.fx.handspipe.IHandGestureState;
import com.google.mediapipe.components.CameraHelper;
import com.google.mediapipe.components.CameraXPreviewHelper;
import com.google.mediapipe.components.ExternalTextureConverter;
import com.google.mediapipe.components.FrameProcessor;
import com.google.mediapipe.components.PermissionHelper;
import com.google.mediapipe.formats.proto.LandmarkProto;
import com.google.mediapipe.framework.AndroidAssetUtil;
import com.google.mediapipe.framework.Packet;
import com.google.mediapipe.framework.PacketCallback;
import com.google.mediapipe.framework.PacketGetter;
import com.google.mediapipe.glutil.EglManager;
import com.google.protobuf.InvalidProtocolBufferException;

import java.io.IOException;
import java.util.List;

import static com.fx.handspipe.HandGesture.getAngle;
import static com.fx.handspipe.HandGesture.getDegree;
import static com.fx.handspipe.HandGesture.getDistance;

public class MainActivity extends AppCompatActivity {
    private static final String TAG = "MainActivity";

    private SurfaceView previewDisplayView;

    private static TextView gestureview;
    private TextView gesturemovement;
    private HandGesture handGesture = null;

    @SuppressLint("HandlerLeak")
    static Handler textHandle = new Handler() {
        @Override
        public void handleMessage(@NonNull Message msg) {
            super.handleMessage(msg);
            if (msg.what == 1) {
                //update ui
                Bundle bundle = msg.getData();
                String s = bundle.getString("msg");
                gestureview.setText(s);
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        gestureview = (TextView) findViewById(R.id.handgesture);
        gestureview.setTextColor(Color.GREEN);
        handGesture = new HandGesture(this);
        previewDisplayView = handGesture.getSurfaceView();

        ViewGroup viewGroup = findViewById(R.id.preview_display_layout);
        viewGroup.addView(previewDisplayView);

        handGesture.setHandGestureStateListener(new IHandGestureState() {
            @Override
            public void onGestureStateListener(int type, String name) {
                Log.i(TAG, "handGesture: type = "+type+", name = "+name);
                String txt = "";
                switch (type) {
                    case HAND_FIST:
                        txt = "Fist";
                        break;
//                    case HAND_THUMB:
//                        txt = "很棒";
//                        break;
//                    case HAND_INDEX:
//                        txt = "食指";
//                        break;
//                    case HAND_MIDDLE:
//                        txt = "中指";
//                        break;
//                    case HAND_RING:
//                        txt = "无名指";
//                        break;
//                    case HAND_PINKY:
//                        txt = "小手指";
//                        break;
                    case HAND_FINGER1:
                        txt = "One";
                        break;
                    case HAND_FINGER2:
                        txt = "Two";
                        break;
                    case HAND_FINGER3:
                        txt = "Three";
                        break;
                    case HAND_FINGER4:
                        txt = "Four";
                        break;
                    case HAND_FINGER5:
                        txt = "Five";
                        break;
                    case HAND_FINGER6:
                        txt = "Six";
                        break;
                    case HAND_OK:
                        txt = "OK";
                        break;
                    case HAND_YEAH:
                        txt = "Yeah";
                        break;
                    case HAND_WONDERFUL:
                        txt = "Wonderful";
                        break;
                    case HAND_SPIDERMAN:
                        txt = "SpiderMan";
                        break;
                    default:
                        break;
                }
                Bundle bundle = new Bundle();
                bundle.putString("msg", txt);
                Message msg = Message.obtain();
                msg.what = 1;
                msg.setData(bundle);
                textHandle.sendMessageDelayed(msg, 1000);
            }
        });
        handGesture.startCamera();
    }

    @Override
    protected void onResume() {
        super.onResume();
    }

    @Override
    protected void onPause() {
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        handGesture.closeCamera();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        return super.onTouchEvent(event);
    }

//    // 解析关键点
//    private static String getLandmarksDebugString(LandmarkProto.NormalizedLandmarkList landmarks) {
//        int landmarkIndex = 0;
//        String landmarksString = "";
//        float total_z = 0f;
//        float avg_z = 0f;
//        for (LandmarkProto.NormalizedLandmark landmark : landmarks.getLandmarkList()) {
//                landmarksString += "\t\tLandmark["
//                                + landmarkIndex + "]: ("
//                                + landmark.getX() + ", "
//                                + landmark.getY() + ", "
//                                + landmark.getZ() + ")\n";
//            total_z += landmark.getZ();
//            ++landmarkIndex;
//        }
//        avg_z = total_z / landmarks.getLandmarkCount();
//        Log.i(TAG, "getLandmarksDebugString: count = "+landmarks.getLandmarkCount()+", total_z = "+total_z+", avg_z = "+avg_z);
//        //分析得出，全部landmark 21个取其中的12个为，0~3，5，6，9，10，13，14，17，18
//        return landmarksString.toString();
//    }
//
//    float previousXCenter;
//    float previousYCenter;
//    float previousAngle; // angle between the hand and the x-axis. in radian
//    float previous_rectangle_width;
//    float previousRectangleHeight;
//    boolean frameCounter;
//    private String handGestureMoveCalculator(List<RectProto.NormalizedRect> normalizedRectList, LandmarkProto.NormalizedLandmarkList multiHandLandmarks) {
//        RectProto.NormalizedRect normalizedRect = normalizedRectList.get(0);
//        float height = normalizedRect.getHeight();
//        float centerX = normalizedRect.getXCenter();
//        float centerY = normalizedRect.getYCenter();
//        if (previousXCenter != 0) {
//            double mouvementDistance = getDistance(centerX, centerY,
//                    previousXCenter, previousYCenter);
//            // LOG(INFO) << "Distance: " << mouvementDistance;
//
//            double mouvementDistanceFactor = 0.02; // only large mouvements will be recognized.
//
//            // the height is normed [0.0, 1.0] to the camera window height.
//            // so the mouvement (when the hand is near the camera) should be equivalent to the mouvement when the hand is far.
//            double mouvementDistanceThreshold = mouvementDistanceFactor * height;
//            if (mouvementDistance > mouvementDistanceThreshold) {
//                double angle = getDegree(getAngle(centerX, centerY,
//                        previousXCenter, previousYCenter, previousXCenter + 0.1,
//                        previousYCenter));
//                // LOG(INFO) << "Angle: " << angle;
//                if (angle >= -45 && angle < 45) {
//                    return "Scrolling right";
//                } else if (angle >= 45 && angle < 135) {
//                    return "Scrolling up";
//                } else if (angle >= 135 || angle < -135) {
//                    return "Scrolling left";
//                } else if (angle >= -135 && angle < -45) {
//                    return "Scrolling down";
//                }
//            }
//        }
//
//        previousXCenter = centerX;
//        previousYCenter = centerY;
//        // 2. FEATURE - Zoom in/out
//        if (previousRectangleHeight != 0) {
//            double heightDifferenceFactor = 0.03;
//
//            // the height is normed [0.0, 1.0] to the camera window height.
//            // so the mouvement (when the hand is near the camera) should be equivalent to the mouvement when the hand is far.
//            double heightDifferenceThreshold = height * heightDifferenceFactor;
//            if (height < previousRectangleHeight - heightDifferenceThreshold) {
//                return "Zoom out";
//            } else if (height > previousRectangleHeight + heightDifferenceThreshold) {
//                return "Zoom in";
//            }
//        }
//        previousRectangleHeight = height;
//        // each odd Frame is skipped. For a better result.
//        frameCounter = !frameCounter;
//        if (frameCounter && multiHandLandmarks != null) {
//            for (int i = 0; i < multiHandLandmarks.getLandmarkCount(); i++) {
////                List<LandmarkProto.NormalizedLandmark> landmarkList = landmarks.getLandmarkList();
//                LandmarkProto.NormalizedLandmark wrist = multiHandLandmarks.getLandmark(0);
//                LandmarkProto.NormalizedLandmark MCP_of_second_finger = multiHandLandmarks.getLandmark(9);
//
//                // angle between the hand (wirst and MCP) and the x-axis.
//                double ang_in_radian =
//                        getAngle(MCP_of_second_finger.getX(), MCP_of_second_finger.getY(),
//                                wrist.getX(), wrist.getY(), wrist.getX() + 0.1, wrist.getY());
//                int ang_in_degree = getDegree(ang_in_radian);
//                // LOG(INFO) << "Angle: " << ang_in_degree;
//                if (previousAngle != 0) {
//                    double angleDifferenceTreshold = 12;
//                    if (previousAngle >= 80 && previousAngle <= 100) {
//                        if (ang_in_degree > previousAngle + angleDifferenceTreshold) {
//                            return "Slide left";
//
//                        } else if (ang_in_degree < previousAngle - angleDifferenceTreshold) {
//                            return "Slide right";
//                        }
//                    }
//                }
//                previousAngle = ang_in_degree;
//            }
//        }
//        return "";
//    }
}
