package com.example.facemesh;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import android.graphics.SurfaceTexture;
import android.os.Bundle;
import android.util.Log;
import android.util.Size;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.google.mediapipe.components.CameraHelper;
import com.google.mediapipe.components.CameraXPreviewHelper;
import com.google.mediapipe.components.ExternalTextureConverter;
import com.google.mediapipe.components.FrameProcessor;
import com.google.mediapipe.components.PermissionHelper;
import com.google.mediapipe.formats.proto.LandmarkProto;
import com.google.mediapipe.framework.AndroidAssetUtil;
import com.google.mediapipe.framework.AndroidPacketCreator;
import com.google.mediapipe.framework.Packet;
import com.google.mediapipe.framework.PacketGetter;
import com.google.mediapipe.glutil.EglManager;

import org.apache.commons.math3.fitting.PolynomialCurveFitter;
import org.apache.commons.math3.fitting.WeightedObservedPoints;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import static java.lang.Float.NaN;

public class MainActivity extends AppCompatActivity {
    private static final String TAG = "MainActivity";

    //
    // 加载动态库
    //
    static {
        System.loadLibrary("mediapipe_jni");
        try {
            System.loadLibrary("opencv_java3");
        } catch (Exception e) {
            System.loadLibrary("opencv_java4");
        }
    }

    //
    //  basic modules.
    //
    // Sends camera-preview frames into a MediaPipe graph for processing, and displays the processed
    // frames onto a {@link Surface}.
    protected FrameProcessor processor;
    // Handles camera access via the {@link CameraX} Jetpack support library.
    protected CameraXPreviewHelper cameraHelper;

    // {@link SurfaceTexture} where the camera-preview frames can be accessed.
    private SurfaceTexture previewFrameTexture;
    // {@link SurfaceView} that displays the camera-preview frames processed by a MediaPipe graph.
    private SurfaceView previewDisplayView;

    // Creates and manages an {@link EGLContext}.
    private EglManager eglManager;
    // Converts the GL_TEXTURE_EXTERNAL_OES texture from Android camera into a regular texture to be
    // consumed by {@link FrameProcessor} and the underlying MediaPipe graph.
    private ExternalTextureConverter converter;

//    //
//    //  for face detection.
//    //
//    private static final String BINARY_GRAPH_NAME = "mobile_gpu.binarypb";
//    private static final String INPUT_VIDEO_STREAM_NAME = "input_video";
//    private static final String OUTPUT_VIDEO_STREAM_NAME = "output_video";

//    //
//    // hand tracking
//    //
//    private static final String OUTPUT_HAND_PRESENCE_STREAM_NAME = "hand_presence";
//    private static final String OUTPUT_LANDMARKS_STREAM_NAME = "hand_landmarks";
//
//    private boolean handPresence;

    // face mesh
    private static final String BINARY_GRAPH_NAME = "face_mesh_mobile_gpu.binarypb";
    private static final String INPUT_VIDEO_STREAM_NAME = "input_video";
    private static final String OUTPUT_VIDEO_STREAM_NAME = "output_video";

    private static final String INPUT_NUM_FACES_SIDE_PACKET_NAME = "num_faces";
    private static final String OUTPUT_LANDMARKS_STREAM_NAME = "multi_face_landmarks";
    // Max number of faces to detect/process.
    private static final int NUM_FACES = 4;

    //
    // camera
    //
    // Flips the camera-preview frames vertically before sending them into FrameProcessor to be
    // processed in a MediaPipe graph, and flips the processed frames back when they are displayed.
    // This is needed because OpenGL represents images assuming the image origin is at the bottom-left
    // corner, whereas MediaPipe in general assumes the image origin is at top-left.
    private static final boolean FLIP_FRAMES_VERTICALLY = true;
    private static final boolean USE_FRONT_CAMERA = true;

    private static TextView faceexpress;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        previewDisplayView = new SurfaceView(this);
        setupPreviewDisplayView();

        faceexpress = (TextView)findViewById(R.id.faceexpress);
        // Initialize asset manager so that MediaPipe native libraries can access the app assets, e.g.,
        // binary graphs.
        AndroidAssetUtil.initializeNativeAssetManager(this);
        eglManager = new EglManager(null);
        processor = new FrameProcessor(
                        this,
                        eglManager.getNativeContext(),
                        BINARY_GRAPH_NAME,
                        INPUT_VIDEO_STREAM_NAME,
                        OUTPUT_VIDEO_STREAM_NAME);

        processor.getVideoSurfaceOutput().setFlipY(FLIP_FRAMES_VERTICALLY);

        PermissionHelper.checkAndRequestCameraPermissions(this);

        AndroidPacketCreator packetCreator = processor.getPacketCreator();
        Map<String, Packet> inputSidePackets = new HashMap<>();
        inputSidePackets.put(INPUT_NUM_FACES_SIDE_PACKET_NAME, packetCreator.createInt32(NUM_FACES));
        processor.setInputSidePackets(inputSidePackets);

        // To show verbose logging, run:
        processor.addPacketCallback(
                OUTPUT_LANDMARKS_STREAM_NAME,
                (packet) -> {
                    Log.v(TAG, "Received multi face landmarks packet.");
                    List<LandmarkProto.NormalizedLandmarkList> multiFaceLandmarks =
                            PacketGetter.getProtoVector(packet, LandmarkProto.NormalizedLandmarkList.parser());
//                    Log.v(TAG, "[TS:"
//                                    + packet.getTimestamp()
//                                    + "] "
//                                    + getMultiFaceLandmarksDebugString(multiFaceLandmarks));
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            faceexpress.setText(faceExpressCalculator(multiFaceLandmarks));
                        }
                    });
                });
    }

    @Override
    protected void onResume() {
        super.onResume();
        converter = new ExternalTextureConverter(eglManager.getContext());
        converter.setFlipY(FLIP_FRAMES_VERTICALLY);
        converter.setConsumer(processor);
        if (PermissionHelper.cameraPermissionsGranted(this)) {
            startCamera();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        converter.close();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        PermissionHelper.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        return super.onTouchEvent(event);

    }

    protected Size computeViewSize(int width, int height) {
        return new Size(width, height);
    }

    protected void onPreviewDisplaySurfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        // (Re-)Compute the ideal size of the camera-preview display (the area that the
        // camera-preview frames get rendered onto, potentially with scaling and rotation)
        // based on the size of the SurfaceView that contains the display.
        Size viewSize = computeViewSize(width, height);
        Size displaySize = cameraHelper.computeDisplaySizeFromViewSize(viewSize);

        // Connect the converter to the camera-preview frames as its input (via
        // previewFrameTexture), and configure the output width and height as the computed
        // display size.
		boolean isCameraRotated = cameraHelper.isCameraRotated();
        converter.setSurfaceTextureAndAttachToGLContext(
                                previewFrameTexture,
                                isCameraRotated ? displaySize.getHeight() : displaySize.getWidth(),
                                isCameraRotated ? displaySize.getWidth() : displaySize.getHeight());
    }

    private void setupPreviewDisplayView() {
        previewDisplayView.setVisibility(View.GONE);
        ViewGroup viewGroup = findViewById(R.id.preview_display_layout);
        viewGroup.addView(previewDisplayView);

        previewDisplayView.getHolder().addCallback(new SurfaceHolder.Callback() {
            @Override
            public void surfaceCreated(@NonNull SurfaceHolder holder) {
                processor.getVideoSurfaceOutput().setSurface(holder.getSurface());
            }

            @Override
            public void surfaceChanged(@NonNull SurfaceHolder holder, int format, int width, int height) {
                onPreviewDisplaySurfaceChanged(holder, format, width, height);
            }

            @Override
            public void surfaceDestroyed(@NonNull SurfaceHolder holder) {
                processor.getVideoSurfaceOutput().setSurface(null);
            }
        });
    }
	
    private void startCamera() {
        cameraHelper = new CameraXPreviewHelper();
        cameraHelper.setOnCameraStartedListener(
                surfaceTexture -> {
                    previewFrameTexture = surfaceTexture;
                    // Make the display view visible to start showing the preview. This triggers the
                    // SurfaceHolder.Callback added to (the holder of) previewDisplayView.
                    previewDisplayView.setVisibility(View.VISIBLE);
                });
        CameraHelper.CameraFacing cameraFacing =
                USE_FRONT_CAMERA ? CameraHelper.CameraFacing.FRONT
                        : CameraHelper.CameraFacing.BACK;
        cameraHelper.startCamera(
                this, cameraFacing, /*surfaceTexture=*/ null, cameraTargetResolution());
    }

    // 设置相机大小
    protected Size cameraTargetResolution() {
        return null;
    }

    // 解析关键点
    private static String getMultiFaceLandmarksDebugString(List<LandmarkProto.NormalizedLandmarkList> multiFaceLandmarks) {
        if (multiFaceLandmarks.isEmpty()) {
            return "No face landmarks";
        }
        String multiFaceLandmarksStr = "Number of faces detected: " + multiFaceLandmarks.size() + "\n";
        int faceIndex = 0;
        for (LandmarkProto.NormalizedLandmarkList landmarks : multiFaceLandmarks) {
            multiFaceLandmarksStr += "\t#Face landmarks for face[" + faceIndex + "]: " + landmarks.getLandmarkCount() + "\n";
            int landmarkIndex = 0;
            for (LandmarkProto.NormalizedLandmark landmark : landmarks.getLandmarkList()) {
                multiFaceLandmarksStr += "\t\tLandmark ["
                                    + landmarkIndex + "]: ("
                                    + landmark.getX() + ", "
                                    + landmark.getY() + ", "
                                    + landmark.getZ() + ")\n";
                ++landmarkIndex;
            }
            ++faceIndex;
        }
        return multiFaceLandmarksStr;
    }

    /**
     * 求平均数
     * @param type - 类型标签
     * @param arr - 数值数值
     * @param num - 保留有效数
     * @return
     */
    private static float getAverage(String type, float[] arr, int num) {
        float avg = 0f, sum = 0f;
        int len = arr.length;
        for(int i = 0; i < len; i++) {
            sum += arr[i];
        }
        try {
            BigDecimal bigD = new BigDecimal(sum/len);
            avg = (float) (bigD.setScale(num, BigDecimal.ROUND_HALF_UP).doubleValue());
        } catch (NumberFormatException e) {

        }
//        Log.i(TAG, "faceEC average: "+type+", avg = "+avg);
        return avg;
    }

    /**
     * 四舍五入
     * @param val - 数值
     * @param num - 保留小数点后的有效数位
     * @return
     */
    private static float getRound(float val, int num) {
        float ret = 0f;
        if((num < 1) ||(val == 0f) ||(val == NaN)) {
            return val;
        }
        try {
            BigDecimal bigD = new BigDecimal(val);
            ret = (float) (bigD.setScale(num, BigDecimal.ROUND_HALF_UP).doubleValue());
        } catch (NumberFormatException e) {

        }

        return ret;
    }

    private static void setExpression_happy() {
        happy_times++;
        if(happy_times >= DETECT_TIMES) {
//            happyMotion = true;
            Log.i(TAG, "faceEC: =====================高兴=================");
            happy_times = 0;
            showString = "高兴";
        }
    }

    private static void setExpression_normal() {
        normal_times++;
        if (normal_times >= DETECT_TIMES) {
//            normalMotion = true;
            Log.i(TAG, "faceEC: =====================自然=================");
            normal_times = 0;
            showString = "自然";
        }
    }

    private static void setExpression_sad() {
        sad_times++;
        if(sad_times >= DETECT_TIMES) {
//            sadMotion = true;
            Log.i(TAG, "faceEC: =====================悲伤=================");
            sad_times = 0;
            showString = "悲伤";
        }
    }

    private static void setExpression_angry() {
        angry_times++;
        if(angry_times >= DETECT_TIMES) {
//            angryMotion = true;
            Log.i(TAG, "faceEC: =====================愤怒=================");
            angry_times = 0;
            showString = "愤怒";
        }
    }

    private static void setExpression_surprise() {
        suprise_times++;
        if(suprise_times >= DETECT_TIMES) {
//            supriseMotion = true;
            Log.i(TAG, "faceEC: =====================惊讶=================");
            suprise_times = 0;
            showString = "惊讶";
        }
    }

    private static void getLandmarkMinMax(String key, float[] arr) {
        int cnt = arr.length;
        float min = 0.0f, max = 0.0f;
        for(int i = 0; i < cnt; i++) {
            if((min == 0.0f) && (max == 0.0f)) {
                min = arr[i];
                max = arr[i];
            }
            if (arr[i] > max) {
                max = arr[i];
            } else if ((arr[i] < min) &&(arr[i] != 0.0f)){
                min = arr[i];
            }
        }
        Log.i(TAG, "faceExpressCalculator: "+ key +", min = "+ min +", max = "+ max);
    }

    private static final int AVG_CNT = 10;
    private static final int DETECT_TIMES = 2;
    static float brow_up_arr[] = new float[AVG_CNT];
    static float brow_width_arr[] = new float[AVG_CNT];
    static float brow_height_arr[] = new float[AVG_CNT];
    static float brow_line_arr[] = new float[AVG_CNT];
    static float brow_mouth_arr[] = new float[AVG_CNT];
    static float brow_height_mouth_arr[] = new float[AVG_CNT];
    static float eye_height_arr[] = new float[AVG_CNT];
    static float eye_width_arr[] = new float[AVG_CNT];
    static float eye_height_mouth_arr[] = new float[AVG_CNT];
    static float mouth_width_arr[] = new float[AVG_CNT];
    static float mouth_height_arr[] = new float[AVG_CNT];
    static int arr_cnt = 0;
    static int normal_times = 0, suprise_times = 0, sad_times = 0, happy_times = 0, angry_times = 0;
    static int total_log_cnt = 0;
    static String showString = "";
    private static String faceExpressCalculator(List<LandmarkProto.NormalizedLandmarkList> multiFaceLandmarks) {
        boolean normalMotion = false;    // 正常
        boolean supriseMotion = false;   // 惊讶
        boolean sadMotion = false;       // 伤心
        boolean happyMotion = false;     // 开心
        boolean angryMotion = false;     // 生气
        boolean smallLaughMotion = false;// 微笑
        boolean heaveLaughMotion = false;// 大笑
        boolean emegencyMotion = false;  // 紧张

        LandmarkProto.NormalizedLandmarkList landmarkList = multiFaceLandmarks.get(0);
        String faceLandmarksStr = "";
        faceLandmarksStr += "\t\tLandmark count: " + landmarkList.getLandmarkCount() + "\n";
        //眉毛
        float brow_left_width = 0f;
        float brow_left_height = 0f;
        float brow_right_width = 0f;
        float brow_right_height = 0f;
        float brow_hight_sum = 0f;
        float brow_line_left = 0f;
        float brow_line_right = 0f;
        float brow_width = 0f;
//        float distance_brow_left_right_sum = 0f;
        float brow_left_up = 0f;
        float brow_right_up = 0f;
        //眼睛
        float eye_left_height[] = new float[7];
        float eye_left_width = 0f;
        float eye_right_height[] = new float[7];
        float eye_right_width = 0f;
        float eye_height_sum = 0f;
        //嘴巴
        float mouth_height_out[] = new float[9];
        float mouth_width_out = 0f;
        float mouth_height_in[] = new float[9];
        float mouth_width_in = 0f;
        float mouth_height_sum = 0f;

        //眼角嘴角距离
        float distance_eye_left_mouth = 0f;
        float distance_eye_right_mouth = 0f;
        float distance_eye_mouth = 0f;

        //睫毛嘴角距离
        float distance_brow_left_mouth = 0f;
        float distance_brow_right_mouth = 0f;
        float distance_brow_mouth = 0f;

//        for (int i = 0; i < landmarkList.getLandmarkCount(); i++) {
//            faceLandmarksStr  += "\t\tLandmark ["
//                                + i + "], "
//                                + landmarkList.getLandmark(i).getX() + ", "
//                                + landmarkList.getLandmark(i).getY() + ", "
//                                + landmarkList.getLandmark(i).getZ() + ")\n";
//            Log.i(TAG, faceLandmarksStr);
//        }
        // 参考DLIB
        // 1、计算人脸识别框边长
        // 注: 脸Y坐标 下 > 上, X坐标 右 > 左
        float face_width = landmarkList.getLandmark(361).getX() - landmarkList.getLandmark(132).getX();
        float face_height = landmarkList.getLandmark(152).getY() - landmarkList.getLandmark(10).getY();

        //眉毛宽度
        // 注: 脸Y坐标 下 > 上, X坐标 右 > 左
        brow_left_width = landmarkList.getLandmark(66).getX()-landmarkList.getLandmark(53).getX();
        brow_right_width = landmarkList.getLandmark(283).getX()-landmarkList.getLandmark(296).getX();
        // 眉毛变短程度: 皱变短(恐惧、愤怒、悲伤) - Solution 1(7-3)
        brow_width = landmarkList.getLandmark(296).getX()-landmarkList.getLandmark(53).getX() +
                     landmarkList.getLandmark(334).getX()-landmarkList.getLandmark(52).getX() +
                     landmarkList.getLandmark(293).getX()-landmarkList.getLandmark(65).getX() +
                     landmarkList.getLandmark(300).getX()-landmarkList.getLandmark(55).getX() +
                     landmarkList.getLandmark(285).getX()-landmarkList.getLandmark(70).getX() +
                     landmarkList.getLandmark(295).getX()-landmarkList.getLandmark(63).getX() +
                     landmarkList.getLandmark(282).getX()-landmarkList.getLandmark(105).getX() +
                     landmarkList.getLandmark(283).getX()-landmarkList.getLandmark(66).getX();

        //眉毛高度之和
        brow_left_height =      landmarkList.getLandmark(53).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(52).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(65).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(55).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(70).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(63).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(105).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(66).getY() - landmarkList.getLandmark(10).getY();
        brow_right_height =     landmarkList.getLandmark(283).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(282).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(295).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(285).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(300).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(293).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(334).getY() - landmarkList.getLandmark(10).getY() +
                                landmarkList.getLandmark(296).getY() - landmarkList.getLandmark(10).getY();
        brow_hight_sum = brow_left_height + brow_right_height;
        //  眉毛高度与识别框高度之比: 眉毛抬高(惊奇、恐惧、悲伤), 眉毛压低(厌恶, 愤怒) - Solution 1(7-1)
        float brow_hight_rate = (brow_hight_sum/16)/face_width;
        //  眉毛间距与识别框高度之比
        float brow_width_rate = (brow_width/8)/face_width;
//        // 分析挑眉程度和皱眉程度, 左眉拟合曲线(53-52-65-55-70-63-105-66) - 暂时未使用
//        float line_brow_x[] = new float[3];
//        line_brow_x[0] = landmarkList.getLandmark(52).getX();
//        line_brow_x[1] = landmarkList.getLandmark(70).getX();
//        line_brow_x[2] = landmarkList.getLandmark(105).getX();
//        float line_brow_y[] = new float[3];
//        line_brow_y[0] = landmarkList.getLandmark(52).getY();
//        line_brow_y[1] = landmarkList.getLandmark(70).getY();
//        line_brow_y[2] = landmarkList.getLandmark(105).getY();
//        WeightedObservedPoints points = new WeightedObservedPoints();
//        for(int i = 0; i < line_brow_x.length; i++) {
//            points.add(line_brow_x[i], line_brow_y[i]);
//        }
//        PolynomialCurveFitter fitter = PolynomialCurveFitter.create(1); //指定为1阶数
//        double[] result = fitter.fit(points.toList());
//        if(result[1]*(-10) < 1.0f) { //倒八眉
//
//        } else {                     //八字眉 或平眉
//
//        }
        brow_line_left = (landmarkList.getLandmark(105).getY() - landmarkList.getLandmark(52).getY())/(landmarkList.getLandmark(105).getX() - landmarkList.getLandmark(52).getX());
        brow_line_right = (landmarkList.getLandmark(282).getY() - landmarkList.getLandmark(334).getY())/(landmarkList.getLandmark(282).getX() - landmarkList.getLandmark(334).getX());
        float brow_line_rate = brow_line_left;  // + brow_line_right;

        // 眉毛变化程度: 变弯(高兴、惊奇) - 上扬  - 下拉 - Solution 1(7-2) - 临时关闭(未使用)
        brow_left_up = landmarkList.getLandmark(70).getY()-landmarkList.getLandmark(10).getY()/* + landmarkList.getLandmark(66).getY()-landmarkList.getLandmark(10).getY()*/;
        brow_right_up = landmarkList.getLandmark(300).getY()-landmarkList.getLandmark(10).getY()/* + landmarkList.getLandmark(283).getY()-landmarkList.getLandmark(10).getY()*/;

        // 注: 眼睛Y坐标 下 > 上, X坐标 右 > 左
        //左侧上下眼睑距离
        eye_left_height[0] = landmarkList.getLandmark(7).getY() - landmarkList.getLandmark(246).getY();
        eye_left_height[1] = landmarkList.getLandmark(163).getY() - landmarkList.getLandmark(161).getY();
        eye_left_height[2] = landmarkList.getLandmark(144).getY() - landmarkList.getLandmark(160).getY();
        eye_left_height[3] = landmarkList.getLandmark(145).getY() - landmarkList.getLandmark(159).getY();   //中心
        eye_left_height[4] = landmarkList.getLandmark(153).getY() - landmarkList.getLandmark(158).getY();
        eye_left_height[5] = landmarkList.getLandmark(154).getY() - landmarkList.getLandmark(157).getY();
        eye_left_height[6] = landmarkList.getLandmark(155).getY() - landmarkList.getLandmark(173).getY();

        // 左侧眼角距离
        eye_left_width = landmarkList.getLandmark(133).getX() - landmarkList.getLandmark(33).getX();

        // 右侧上下眼睑距离
        eye_right_height[0] = landmarkList.getLandmark(382).getY() - landmarkList.getLandmark(398).getY();
        eye_right_height[1] = landmarkList.getLandmark(381).getY() - landmarkList.getLandmark(384).getY();
        eye_right_height[2] = landmarkList.getLandmark(380).getY() - landmarkList.getLandmark(385).getY();
        eye_right_height[3] = landmarkList.getLandmark(374).getY() - landmarkList.getLandmark(386).getY();  // 中心
        eye_right_height[4] = landmarkList.getLandmark(373).getY() - landmarkList.getLandmark(387).getY();
        eye_right_height[5] = landmarkList.getLandmark(390).getY() - landmarkList.getLandmark(388).getY();
        eye_right_height[6] = landmarkList.getLandmark(249).getY() - landmarkList.getLandmark(466).getY();

        // 右侧眼角距离
        eye_right_width = landmarkList.getLandmark(263).getX() - landmarkList.getLandmark(362).getX();

        // 眼睛睁开程度: 上下眼睑拉大距离(惊奇、恐惧) - Solution 1(7-4)
        eye_height_sum = eye_left_height[3] + eye_right_height[3];

        // 两眼角距离
        float eye_width_sum = eye_left_width + eye_right_width;

        // 注: 嘴巴Y坐标 上 > 下, X坐标 右 > 左
        //  两嘴角间距离- 用于计算嘴巴的宽度
        mouth_width_out = landmarkList.getLandmark(291).getX() - landmarkList.getLandmark(61).getX();
        mouth_width_in = landmarkList.getLandmark(308).getX() - landmarkList.getLandmark(78).getX();

        //上下嘴唇间距离 - 嘴巴（内）
        mouth_height_in[0] = landmarkList.getLandmark(95).getY() - landmarkList.getLandmark(185).getY();
        mouth_height_in[1] = landmarkList.getLandmark(88).getY() - landmarkList.getLandmark(40).getY();
        mouth_height_in[2] = landmarkList.getLandmark(178).getY() - landmarkList.getLandmark(39).getY();
        mouth_height_in[3] = landmarkList.getLandmark(87).getY() - landmarkList.getLandmark(37).getY();
        mouth_height_in[4] = landmarkList.getLandmark(14).getY() - landmarkList.getLandmark(0).getY();  // 中心
        mouth_height_in[5] = landmarkList.getLandmark(317).getY() - landmarkList.getLandmark(267).getY();
        mouth_height_in[6] = landmarkList.getLandmark(402).getY() - landmarkList.getLandmark(269).getY();
        mouth_height_in[7] = landmarkList.getLandmark(318).getY() - landmarkList.getLandmark(270).getY();
        mouth_height_in[8] = landmarkList.getLandmark(324).getY() - landmarkList.getLandmark(409).getY();

        //嘴巴睁开程度- 用于计算嘴巴的高度: 上下嘴唇拉大距离(惊奇、恐惧、愤怒、高兴) - Solution 1(7-6)
        mouth_height_sum = mouth_height_in[4];
        // 嘴角下拉(厌恶、愤怒、悲伤),    > 1 上扬， < 1 下拉 - Solution 1(7-7)
        float mouth_line_rate = ((landmarkList.getLandmark(78).getY() + landmarkList.getLandmark(308).getY()))/(landmarkList.getLandmark(14).getY() + landmarkList.getLandmark(0).getY());
//        Log.i(TAG, "faceEC: mouth_line_rate = "+mouth_line_rate);

        // 两侧眼角到同侧嘴角距离
        distance_eye_left_mouth = landmarkList.getLandmark(78).getY() - landmarkList.getLandmark(133).getY();
        distance_eye_right_mouth = landmarkList.getLandmark(308).getY() - landmarkList.getLandmark(362).getY();
        distance_eye_mouth = distance_eye_left_mouth + distance_eye_right_mouth;

        // 两侧睫毛到同侧嘴角距离
        distance_brow_left_mouth = landmarkList.getLandmark(78).getY() - landmarkList.getLandmark(107).getY();
        distance_brow_right_mouth = landmarkList.getLandmark(308).getY() - landmarkList.getLandmark(336).getY();
        distance_brow_mouth = distance_brow_left_mouth + distance_brow_right_mouth;

        // 归一化
        float MM = 0, NN = 0, PP = 0, QQ = 0;
        float dis_eye_mouth_rate = getRound((2 * mouth_width_in)/distance_eye_mouth, 4);             // 嘴角 / 眼角嘴角距离, 高兴(0.85),愤怒/生气(0.7),惊讶(0.6),大哭(0.75)
        float distance_brow = landmarkList.getLandmark(296).getX() - landmarkList.getLandmark(66).getX();
        float dis_brow_mouth_rate = getRound(mouth_width_in/distance_brow, 4);                       // 嘴角 / 两眉间距
        float dis_eye_height_mouth_rate = getRound((1 * mouth_width_in)/((eye_height_sum)/2), 4);    // 嘴角 / 上下眼睑距离
        float dis_brow_height_mouth_rate = getRound((2 * mouth_width_in)/(landmarkList.getLandmark(145).getY() - landmarkList.getLandmark(70).getY()), 4);
//        Log.i(TAG, "faceEC: 眼角嘴 = "+dis_eye_mouth_rate+", \t眉角嘴 = "+dis_brow_mouth_rate+", \t眼高嘴 = "+dis_eye_height_mouth_rate+", \t眉高嘴 = "+dis_brow_height_mouth_rate);

        brow_mouth_arr[arr_cnt] = dis_brow_mouth_rate;
        brow_height_mouth_arr[arr_cnt] = dis_brow_height_mouth_rate;
        eye_height_mouth_arr[arr_cnt] = dis_eye_height_mouth_rate;

        // 眉毛上扬与识别框宽度之比
        float brow_up_rate = (brow_left_up + brow_right_up)/(2*face_width);
        // 眼睛睁开距离与识别框高度之比
        float eye_height_rate = eye_height_sum/(2*face_width);
        float eye_width_rate = eye_width_sum/(2*face_width);
        // 张开嘴巴距离与识别框高度之比
        float mouth_width_rate = mouth_width_in/face_width;
        float mouth_height_rate = mouth_height_sum/face_width;

        brow_up_arr[arr_cnt] = brow_up_rate;
        brow_width_arr[arr_cnt] = brow_width_rate;
        brow_height_arr[arr_cnt] = brow_hight_rate;
        brow_line_arr[arr_cnt] = brow_line_rate;
        eye_height_arr[arr_cnt] = eye_height_rate;
        eye_width_arr[arr_cnt] = eye_width_rate;
        mouth_width_arr[arr_cnt] = mouth_width_rate;
        mouth_height_arr[arr_cnt] = mouth_height_rate;
        float brow_mouth_avg = 0f, brow_height_mouth_avg = 0f;
        float brow_up_avg = 0f, brow_width_avg = 0f, brow_height_avg = 0f, brow_line_avg = 0f;
        float eye_height_avg = 0f, eye_width_avg = 0f, eye_height_mouth_avg = 0f;
        float mouth_width_avg = 0f, mouth_height_avg = 0f;
        arr_cnt++;
        if(arr_cnt >= AVG_CNT) {
            brow_mouth_avg = getAverage("眉角嘴", brow_mouth_arr, 4);
            brow_height_mouth_avg = getAverage("眉高嘴", brow_height_mouth_arr, 4);
            brow_up_avg = getAverage("眉上扬", brow_up_arr, 4);
            brow_width_avg = getAverage("眉宽", brow_width_arr, 4);
            brow_height_avg = getAverage("眉高", brow_height_arr, 4);
            brow_line_avg = getAverage("挑眉", brow_line_arr, 4);
            eye_height_avg = getAverage("眼睁", eye_height_arr, 4);
            eye_width_avg = getAverage("眼宽", eye_width_arr, 4);
            eye_height_mouth_avg = getAverage("眼高嘴", eye_height_mouth_arr, 4);
            mouth_width_avg = getAverage("嘴宽", mouth_width_arr, 4);
            mouth_height_avg = getAverage("嘴张", mouth_height_arr, 4);
            arr_cnt = 0;
        }

        if(dis_eye_mouth_rate <= 0.7) {
            MM = getRound(dis_eye_mouth_rate * 0, 4);
        } else if((dis_eye_mouth_rate > 0.7) &&(dis_eye_mouth_rate <= 0.75)) {    // 微笑
            MM = getRound((float)(dis_eye_mouth_rate * 1.38), 4);
        } else if((dis_eye_mouth_rate > 0.75) &&(dis_eye_mouth_rate <= 0.8)) {
            MM = getRound((float)(dis_eye_mouth_rate * 2.58), 4);
        } else if((dis_eye_mouth_rate > 0.8) &&(dis_eye_mouth_rate <= 0.9)) {
            MM = getRound((float)(dis_eye_mouth_rate * 3.54), 4);
        } else if((dis_eye_mouth_rate > 0.9) &&(dis_eye_mouth_rate <= 1.0)) {     //大笑
            MM = getRound((float)(dis_eye_mouth_rate * 4.22), 4);
        } else if(dis_eye_mouth_rate > 1) {
            MM = getRound((float)(dis_eye_mouth_rate * 5.0), 4);
        }
        float brow_height_width_rate = getRound(brow_height_avg/brow_width_avg, 4);
        float eye_width_height_rate = getRound(eye_width_avg/eye_height_avg, 4);
        float mouth_width_height_rate = getRound(mouth_width_avg/mouth_height_avg, 4);

        if(brow_height_width_rate <= 0.365f) {
            NN = getRound((brow_height_width_rate * 0f), 4);
        } else if((brow_height_width_rate > 0.365f)&&(brow_height_width_rate <= 0.405f)) {
            NN = getRound((brow_height_width_rate * 3.58f), 4);
        } else if((brow_height_width_rate > 0.405f)&&(brow_height_width_rate <= 0.455f)) {
            NN = getRound((brow_height_width_rate * 4.22f), 4);
        } else if(brow_height_width_rate > 0.455f) {
            NN = getRound((brow_height_width_rate * 5), 4);
        }

        if(eye_width_height_rate <= 3.10f) {
            PP = getRound((eye_width_height_rate * 0f), 4);
        } else if((eye_width_height_rate > 3.10f ) &&(eye_width_height_rate <= 4.10f)){
            PP = getRound((eye_width_height_rate * 3.58f), 4);
        } else {
            PP = getRound((eye_width_height_rate * 4.58f), 4);
        }
//        判断头部倾斜度
        float head_line_rate = (landmarkList.getLandmark(362).getY() - landmarkList.getLandmark(133).getY())/(landmarkList.getLandmark(362).getX() - landmarkList.getLandmark(133).getX());
        if(Math.abs(head_line_rate) >= 0.5f) {
            Log.i(TAG, "faceEC: ============头部太偏=============");
            showString = "头部太偏";
        }
        total_log_cnt++;
        if(total_log_cnt >= AVG_CNT) {
            if((mouth_width_height_rate >= 6.0f) /*&&(MM == 0f)*/) {
                if(MM >= 2.5f) {
                    setExpression_sad();
                } else {
                    if(PP >= 11.0f) {
//                        setExpression_angry();
//                    } else {
                        setExpression_normal();
                    }
                }
            } else if((mouth_width_height_rate < 4.0f) &&(MM <= 2.0f)) {
                setExpression_surprise();
            } else {
                if((eye_width_height_rate >= 4.5f) &&(mouth_line_rate >= 1.0f)) {
                    setExpression_sad();
                } else {
                    if((brow_up_avg * 10 >= 2.6) &&(MM >= 3.0f) &&((dis_brow_height_mouth_rate >= 4.0f)||(eye_width_height_rate >= 6.0f))){
                        setExpression_happy();
                    } else if(MM < 2.0f) {
                        setExpression_angry();
                    }
                }
            }
            Log.i(TAG, "faceEC: 眉高 = " + brow_height_avg + ", \t眉宽 = " + brow_width_avg + ", \t眉上扬 = "+brow_up_avg*100 + ", \t挑眉 = " + brow_line_avg + ", \t眼睁 = " + eye_height_avg + ", \t嘴宽 = " + mouth_width_avg + ", \t嘴张 = " + mouth_height_avg);
            Log.i(TAG, "faceEC: 眉高宽比 = "+brow_height_width_rate+", \t眼宽高比 = "+eye_width_height_rate+", \t嘴宽高比 = "+mouth_width_height_rate+"\t,  眼高嘴 = "+eye_height_mouth_avg+", 眉角嘴 = "+brow_mouth_avg+", 眉高嘴 = "+brow_height_mouth_avg);
            Log.i(TAG, "faceEC: M = "+dis_eye_mouth_rate+", \tMM = "+MM+", \tN = "+brow_height_width_rate+", \tNN = "+NN+", \tP = "+eye_width_height_rate+", PP = "+PP);
            total_log_cnt = 0;
        }
        return showString;
    }
}
