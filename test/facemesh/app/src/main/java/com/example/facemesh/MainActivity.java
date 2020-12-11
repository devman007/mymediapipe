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

import java.util.HashMap;
import java.util.List;
import java.util.Map;

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

    private static float getAverage(String type, float[] arr) {
        float avg = 0f, sum = 0f;
        int len = arr.length;
        for(int i = 0; i < len; i++) {
            sum += arr[i];
        }
        avg = sum/len;
//        Log.i(TAG, "faceEC average: "+type+", avg = "+avg);
        return avg;
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
    static float M_Array[] = new float[60];
    static float M_MIN = 0.0f, M_MAX = 0.0f;
    static int M_cnt = 0;
    static float N_Array[] = new float[60];
    static float N_MIN = 0.0f, N_MAX = 0.0f;
    static int N_cnt = 0;
    static float O_Array[] = new float[60];
    static float O_MIN = 0.0f, O_MAX = 0.0f;
    static int O_cnt = 0;
    static float P_Array[] = new float[60];
    static float P_MIN = 0.0f, P_MAX = 0.0f;
    static int P_cnt = 0;
    static float Q_Array[] = new float[60];
    static float Q_MIN = 0.0f, Q_MAX = 0.0f;
    static int Q_cnt = 0;
    static float R_Array[] = new float[60];
    static float R_MIN = 0.0f, R_MAX = 0.0f;
    static int R_cnt = 0;
    static float brow_width_arr[] = new float[AVG_CNT];
    static int brow_width_arr_cnt = 0;
    static float brow_height_arr[] = new float[AVG_CNT];
    static int brow_height_arr_cnt = 0;
    static float brow_line_arr[] = new float[AVG_CNT];
    static int brow_line_arr_cnt = 0;
    static float eye_height_arr[] = new float[AVG_CNT];
    static int eye_height_arr_cnt = 0;
    static float eye_width_arr[] = new float[AVG_CNT];
    static int eye_width_arr_cnt = 0;
    static float mouth_width_arr[] = new float[AVG_CNT];
    static int mouth_width_arr_cnt = 0;
    static float mouth_height_arr[] = new float[AVG_CNT];
    static int mouth_height_arr_cnt = 0;
    static int total_log_cnt = 0;
    private static String faceExpressCalculator(List<LandmarkProto.NormalizedLandmarkList> multiFaceLandmarks) {
//        boolean laughMotion = true;   // 开心
        boolean smallLaughMotion = true;// 微笑
        boolean heaveLaughMotion = true;// 大笑
        boolean angryMotion = true;     // 生气
        boolean cryMotion = true;       // 哭啼
        boolean badMotion = true;       // 伤心
        boolean emegencyMotion = true;  // 紧张
        boolean supriseMotion = true;   // 惊讶

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
        float distance_brow_left_right_sum = 0f;
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
        brow_width = brow_left_width + brow_right_width;

        //眉毛高度之和
        brow_left_height =      landmarkList.getLandmark(53).getY()+
                                landmarkList.getLandmark(52).getY()+
                                landmarkList.getLandmark(65).getY()+
                                landmarkList.getLandmark(55).getY()+
                                landmarkList.getLandmark(70).getY()+
                                landmarkList.getLandmark(63).getY()+
                                landmarkList.getLandmark(105).getY()+
                                landmarkList.getLandmark(66).getY();
        brow_right_height =     landmarkList.getLandmark(283).getY()+
                                landmarkList.getLandmark(282).getY()+
                                landmarkList.getLandmark(295).getY()+
                                landmarkList.getLandmark(285).getY()+
                                landmarkList.getLandmark(300).getY()+
                                landmarkList.getLandmark(293).getY()+
                                landmarkList.getLandmark(334).getY()+
                                landmarkList.getLandmark(296).getY();
        brow_hight_sum = brow_left_height + brow_right_height;
        // 两边眉毛距离之和
        distance_brow_left_right_sum = landmarkList.getLandmark(296).getX() - landmarkList.getLandmark(66).getX() +
                                        landmarkList.getLandmark(334).getX() - landmarkList.getLandmark(105).getX() +
                                        landmarkList.getLandmark(293).getX() - landmarkList.getLandmark(63).getX() +
                                        landmarkList.getLandmark(300).getX() - landmarkList.getLandmark(70).getX() +
                                        landmarkList.getLandmark(285).getX() - landmarkList.getLandmark(55).getX() +
                                        landmarkList.getLandmark(295).getX() - landmarkList.getLandmark(65).getX() +
                                        landmarkList.getLandmark(282).getX() - landmarkList.getLandmark(52).getX() +
                                        landmarkList.getLandmark(283).getX() - landmarkList.getLandmark(53).getX();
        //  眉毛高度与识别框高度之比: 眉毛抬高(惊奇、恐惧、悲伤), 眉毛压低(厌恶, 愤怒) - Solution 1(7-1)
        float brow_hight_rate = brow_width/face_width;
        //  眉毛间距与识别框高度之比
        float brow_width_rate = (distance_brow_left_right_sum/8)/face_width;
        // 分析挑眉程度和皱眉程度
        brow_line_left = (landmarkList.getLandmark(105).getY() - landmarkList.getLandmark(52).getY())/(landmarkList.getLandmark(105).getX() - landmarkList.getLandmark(52).getX());
        brow_line_right = (landmarkList.getLandmark(282).getY() - landmarkList.getLandmark(334).getY())/(landmarkList.getLandmark(282).getX() - landmarkList.getLandmark(334).getX());
        float brow_line_rate = brow_line_left;  // + brow_line_right;

        // 眉毛变化程度: 变弯(高兴、惊奇) - 上扬  - 下拉 - Solution 1(7-2)
        float brow_left_left_rate = (landmarkList.getLandmark(55).getY()-landmarkList.getLandmark(53).getY())/(landmarkList.getLandmark(55).getX()-landmarkList.getLandmark(53).getX());
        float brow_right_left_rate = (landmarkList.getLandmark(300).getY()-landmarkList.getLandmark(296).getY())/(landmarkList.getLandmark(300).getX()-landmarkList.getLandmark(296).getX());
        float brow_left_right_rate = (landmarkList.getLandmark(70).getY()-landmarkList.getLandmark(66).getY())/(landmarkList.getLandmark(70).getX()-landmarkList.getLandmark(66).getX());
        float brow_right_right_rate = (landmarkList.getLandmark(285).getY()-landmarkList.getLandmark(283).getY())/(landmarkList.getLandmark(285).getX()-landmarkList.getLandmark(283).getX());
        float brow_left_rate = brow_left_left_rate + brow_right_left_rate;   //  >0
        float brow_right_rate = brow_left_right_rate + brow_right_right_rate;   //  <0
        Log.i(TAG, "faceEC: brow_left_rate = "+brow_left_rate+", brow_right_rate = "+brow_right_rate);

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

        // 眼内角抬高(悲伤) - Solution 1(7-5)
        float eye_left_line_rate = (landmarkList.getLandmark(133).getY()-landmarkList.getLandmark(33).getY())/eye_left_width;
        float eye_right_line_rate = (landmarkList.getLandmark(263).getY() - landmarkList.getLandmark(362).getY())/eye_right_width;
        Log.i(TAG, "faceEC: eye_left_line_rate = "+eye_left_line_rate+", eye_right_line_rate = "+eye_right_line_rate);

        // 注: 嘴巴Y坐标 上 > 下, X坐标 右 > 左
        //  两嘴角间距离- 用于计算嘴巴的宽度
        mouth_width_out = landmarkList.getLandmark(291).getX() - landmarkList.getLandmark(61).getX();
        mouth_width_in = landmarkList.getLandmark(308).getX() - landmarkList.getLandmark(78).getX();

        //上下嘴唇间距离 - 嘴巴（外）
        mouth_height_out[0] = landmarkList.getLandmark(191).getY() - landmarkList.getLandmark(146).getY();
        mouth_height_out[1] = landmarkList.getLandmark(80).getY() - landmarkList.getLandmark(91).getY();
        mouth_height_out[2] = landmarkList.getLandmark(81).getY() - landmarkList.getLandmark(181).getY();
        mouth_height_out[3] = landmarkList.getLandmark(82).getY() - landmarkList.getLandmark(84).getY();
        mouth_height_out[4] = landmarkList.getLandmark(13).getY() - landmarkList.getLandmark(17).getY();  // 中心
        mouth_height_out[5] = landmarkList.getLandmark(312).getY() - landmarkList.getLandmark(314).getY();
        mouth_height_out[6] = landmarkList.getLandmark(311).getY() - landmarkList.getLandmark(405).getY();
        mouth_height_out[7] = landmarkList.getLandmark(310).getY() - landmarkList.getLandmark(321).getY();
        mouth_height_out[8] = landmarkList.getLandmark(415).getY() - landmarkList.getLandmark(375).getY();

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
        distance_brow_left_mouth = landmarkList.getLandmark(107).getY() - landmarkList.getLandmark(78).getY();
        distance_brow_right_mouth = landmarkList.getLandmark(336).getY() - landmarkList.getLandmark(308).getY();
        distance_brow_mouth = distance_brow_left_mouth + distance_brow_right_mouth;

        // 归一化
        float M = (2 * mouth_width_in)/distance_eye_mouth;           // 嘴角 / 眼角嘴角距离, 高兴(0.85),愤怒/生气(0.7),惊讶(0.6),大哭(0.75)
        float N = (2 * mouth_width_in)/distance_brow_mouth;          // 嘴角 / 眉毛嘴角距离
        float O = (2 * mouth_width_in)/eye_height_sum;               // 嘴角 / 上下眼睑距离
        float P = eye_width_sum/distance_brow_mouth;                 // 眼角距离 / 眉毛嘴角距离
        float Q = eye_width_sum/eye_height_sum;                      // 眼角距离 / 上下眼睑距离
        float R = 2 * mouth_width_in/mouth_height_sum;               // 嘴角 / 上下嘴唇距离
        float MM = 0, NN = 0, OO = 0, PP = 0, QQ = 0, RR = 0;

        // M与state8综合判断表情

        // 眼睛睁开距离与识别框高度之比
        float eye_height_rate = eye_height_sum/face_width;
        float eye_width_rate = eye_width_sum/face_width;
        // 张开嘴巴距离与识别框高度之比
        float mouth_width_rate = mouth_width_in/face_width;
        float mouth_height_rate = mouth_height_sum/face_width;

        brow_width_arr[brow_width_arr_cnt] = brow_width_rate;
        brow_width_arr_cnt++;
        float brow_width_avg = 0f;
        if(brow_width_arr_cnt >= AVG_CNT) {
            brow_width_avg = getAverage("眉宽", brow_width_arr);
            brow_width_arr_cnt = 0;
        }

        brow_height_arr[brow_height_arr_cnt] = brow_hight_rate;
        brow_height_arr_cnt++;
        float brow_height_avg = 0f;
        if(brow_height_arr_cnt >= AVG_CNT) {
            brow_height_avg = getAverage("眉高", brow_height_arr);
            brow_height_arr_cnt = 0;
        }

        brow_line_arr[brow_line_arr_cnt] = brow_line_rate;
        brow_line_arr_cnt++;
        float brow_line_avg = 0f;
        if(brow_line_arr_cnt >= AVG_CNT) {
            brow_line_avg = getAverage("挑眉", brow_line_arr);
            brow_line_arr_cnt = 0;
        }

        eye_height_arr[eye_height_arr_cnt] = eye_height_rate;
        eye_height_arr_cnt++;
        float eye_height_avg = 0f;
        if(eye_height_arr_cnt >= AVG_CNT) {
            eye_height_avg = getAverage("眼睁", eye_height_arr);
            eye_height_arr_cnt = 0;
        }

        eye_width_arr[eye_width_arr_cnt] = eye_width_rate;
        eye_width_arr_cnt++;
        float eye_width_avg = 0f;
        if(eye_width_arr_cnt >= AVG_CNT) {
            eye_width_avg = getAverage("眼宽", eye_width_arr);
            eye_width_arr_cnt = 0;
        }

        mouth_width_arr[mouth_width_arr_cnt] = mouth_width_rate;
        mouth_width_arr_cnt++;
        float mouth_width_avg = 0f;
        if(mouth_width_arr_cnt >= AVG_CNT) {
            mouth_width_avg = getAverage("嘴宽", mouth_width_arr);
            mouth_width_arr_cnt = 0;
        }

        mouth_height_arr[mouth_height_arr_cnt] = mouth_height_rate;
        mouth_height_arr_cnt++;
        float mouth_height_avg = 0f;
        if(mouth_height_arr_cnt >= AVG_CNT) {
            mouth_height_avg = getAverage("嘴张", mouth_height_arr);
            mouth_height_arr_cnt = 0;
        }

        if(M <= 0.7) {
            MM = M * 0;
        } else if((M > 0.7) &&(M <= 0.75)) {    // 微笑
            MM = (float)(M * 1.38);
            smallLaughMotion = true;
        } else if((M > 0.75) &&(M <= 0.8)) {
            MM = (float)(M * 2.58);
            smallLaughMotion = true;
        } else if((M > 0.8) &&(M <= 0.9)) {
            MM = (float)(M * 3.54);
            smallLaughMotion = true;
        } else if((M > 0.9) &&(M <= 1.0)) {     //大笑
            MM = (float)(M * 4.22);
            heaveLaughMotion = true;
        } else if(M > 1) {
            MM = (float)(M * 5.0);
            heaveLaughMotion = true;
        }
        float brow_height_width_rate = brow_hight_rate/brow_width_rate;
        float eye_width_height_rate = eye_width_avg/eye_height_avg;
        float mouth_width_height_rate = mouth_width_avg/mouth_height_avg;
        total_log_cnt++;
        if(total_log_cnt >= AVG_CNT) {
            Log.i(TAG, "faceEC: \t眉高 = " + brow_hight_rate + ", \t眉宽 = " + brow_width_rate + ", \t挑眉 = " + brow_line_avg + ", \t眼睁 = " + eye_height_rate + ", \t嘴宽 = " + mouth_width_rate + ", \t嘴张 = " + mouth_height_rate+", M = "+M);
            total_log_cnt = 0;
            Log.i(TAG, "faceEC: \t眉高宽比 = "+brow_height_width_rate+", \t眼宽高比 = "+eye_width_height_rate+", \t嘴宽高比 = "+mouth_width_height_rate+", M = "+M+", MM = "+MM);
        }
//        眉高宽比 >= 6           正常

//        眼宽高比 >= 4           悲伤
//        眼宽高比 3 ~ 4          高兴,愤怒
//
//        嘴宽高比 >= 6           正常
//        嘴宽高比 >= 4           愤怒
//        嘴宽高比 2 ~ 3          高兴,悲伤
//        嘴宽高比 < 2            惊讶
//        MM >= 3                高兴
        // 张嘴，可能是开心/惊讶/大哭(悲伤)
        // 没有张嘴，可能是正常(自然)/生气
        if(mouth_width_height_rate >= 6) {
            Log.i(TAG, "faceEC: =====================自然=================");
        } else if((mouth_width_height_rate >= 4) &&(mouth_width_height_rate < 6) &&(mouth_line_rate <= 1)) {
            Log.i(TAG, "faceEC: =====================愤怒=================");
        } else if(mouth_width_height_rate < 2) {
            Log.i(TAG, "faceEC: =====================惊讶=================");
        } else {
            if(eye_width_height_rate >= 4) {
                Log.i(TAG, "faceEC: =====================悲伤=================");
            } else {
                if(MM > 4.0f) {
                    Log.i(TAG, "faceEC: =====================高兴=================");
                } else {
//                    Log.i(TAG, "faceEC: =====================愤怒=================");
                }
            }
        }
//        if((browRate >= 2.5f) &&(MM <= 0)) {
////            Log.i(TAG, "faceEC: =====================生气=================");
//        } else if((browRate < 2.5f) &&(browRate + 0.05f >= 2.0f) &&(eyeRate - 0.5f <= 1.0f)) {
//            Log.i(TAG, "faceEC: =====================悲伤=================");
//        }
//        if((eyeRate >= 2.2f) &&(mouthRate >= 3.0f)) {
//            Log.i(TAG, "faceEC: =====================惊讶=================");
//        } else if((eyeRate + 0.05f >= 2.0f) &&(mouthRate - 0.2f <= 1.0f)) {
//            Log.i(TAG, "faceEC: =====================自然=================");
//        }
//        if((mouthRate >= 2.5f) &&(MM >= 2.0f)) {
//            Log.i(TAG, "faceEC: =====================高兴=================");
//        }
//
//        if(mouth_height_avg >= 1.30) {
//            if(eye_height_avg >= 1.00){
//                //惊讶
//                Log.i(TAG, "faceEC: =====================惊讶=================");
//            } else {
//                //高兴
//                Log.i(TAG, "faceEC: =====================高兴=================");
//            }
//        } else if((mouth_height_avg >= 1.0)&&(mouth_height_avg < 1.30)) {
//            if(eye_height_avg + 0.3f >= 1.00f) {
//                //生气
//                Log.i(TAG, "faceEC: =====================生气=================");
//            } else {
//                //悲伤
//                Log.i(TAG, "faceEC: =====================悲伤=================");
//            }
//        } else {
//            if (brow_line_avg <= 0.2) {
//                //愤怒
////                Log.i(TAG, "faceEC: =====================愤怒=================");
//            } else {
//                //自然
//                Log.i(TAG, "faceEC: =====================自然=================");
//            }
//        }

//        if((M_cnt >= 5) &&(M_cnt <= 60)) {
//            M_Array[M_cnt-5] = M;
//            if(M_cnt >= 49) {
//                getLandmarkMinMax("M", M_Array);
//            }
//        }
//        M_cnt++;
//
//        if((N_cnt >= 5) &&(N_cnt <= 60)) {
//            N_Array[N_cnt-5] = N;
//            if(N_cnt >= 49) {
//                getLandmarkMinMax("N", N_Array);
//            }
//        }
//        N_cnt++;
//
//        if((O_cnt >= 5) &&(O_cnt <= 60)) {
//            O_Array[O_cnt-5] = O;
//            if(O_cnt >= 49) {
//                getLandmarkMinMax("O", O_Array);
//            }
//        }
//        O_cnt++;
//
//        if((P_cnt >= 5) &&(P_cnt <= 60)) {
//            P_Array[P_cnt-5] = P;
//            if(P_cnt >= 49) {
//                getLandmarkMinMax("P", P_Array);
//            }
//        }
//        P_cnt++;
//
//        if((Q_cnt >= 5) &&(Q_cnt <= 60)) {
//            Q_Array[Q_cnt-5] = Q;
//            if(Q_cnt >= 49) {
//                getLandmarkMinMax("Q", Q_Array);
//            }
//        }
//        Q_cnt++;
//
//        if((R_cnt >= 5) &&(R_cnt <= 60)) {
//            R_Array[R_cnt-5] = R;
//            if(R_cnt >= 49) {
//                getLandmarkMinMax("R", R_Array);
//            }
//        }
//        R_cnt++;
//        Log.i(TAG, "faceExpressCalculator: \tM = "+M+", MM = "+MM);
//        Log.i(TAG, "faceExpressCalculator: \ts0 = "+state0+", \ts1 = "+state1+", \ts2 = "+state2+", \ts3 = "+state3+", \ts4 = "+state4+", \ts5 = "+state5+", \ts6 = "+state6+", state7 = "+state7+", state8 = "+state8);
//            N += 0.5f;
//            if(N <= 0.7) {
//                NN = N * 0;
//            } else if((N > 0.7) &&(N <= 0.75)) {    // 微笑
//                NN = (float)(N * 1.38);
//            } else if((N > 0.75) &&(N <= 0.8)) {
//                NN = (float)(N * 2.58);
//            } else if((N > 0.8) &&(N <= 0.9)) {
//                NN = (float)(N * 3.54);
//            } else if((N > 0.9) &&(N <= 1.0)) {     //大笑
//                NN = (float)(N * 4.22);
//            } else if(N > 1) {
//                NN = (float)(N * 5.0);
//            }
//            O -= 5;
//            if(O <= 0.7) {
//                OO = O * 0;
//            } else if((O > 0.7) &&(O <= 0.75)) {    // 微笑
//                OO = (float)(O * 1.38);
//            } else if((O > 0.75) &&(O <= 0.8)) {
//                OO = (float)(O * 2.58);
//            } else if((O > 0.8) &&(O <= 0.9)) {
//                OO = (float)(O * 3.54);
//            } else if((O > 0.9) &&(O <= 1.0)) {     //大笑
//                OO = (float)(O * 4.22);
//            } else if(O > 1) {
//                OO = (float)(O * 5.0);
//            }
//            P += 0.5f;
//            if(P <= 0.7) {
//                PP = P * 0;
//            } else if((P > 0.7) &&(P <= 0.75)) {    // 微笑
//                PP = (float)(P * 1.38);
//            } else if((P > 0.75) &&(P <= 0.8)) {
//                PP = (float)(P * 2.58);
//            } else if((P > 0.8) &&(P <= 0.9)) {
//                PP = (float)(P * 3.54);
//            } else if((P > 0.9) &&(P <= 1.0)) {     //大笑
//                PP = (float)(P * 4.22);
//            } else if(P > 1) {
//                PP = (float)(P * 5.0);
//            }
//            Q = 5 - Q;
//            if(Q <= 0.7) {
//                QQ = Q * 0;
//            } else if((Q > 0.7) &&(Q <= 0.75)) {    // 微笑
//                QQ = (float)(Q * 1.38);
//            } else if((Q > 0.75) &&(Q <= 0.8)) {
//                QQ = (float)(Q * 2.58);
//            } else if((Q > 0.8) &&(Q <= 0.9)) {
//                QQ = (float)(Q * 3.54);
//            } else if((Q > 0.9) &&(M <= 1.0)) {     //大笑
//                QQ = (float)(Q * 4.22);
//            } else if(Q > 1) {
//                QQ = (float)(Q * 5.0);
//            }
//            R = Math.abs(R);
//            R -= 5;
//            if(R <= 0.7) {
//                RR = R * 0;
//            } else if((R > 0.7) &&(R <= 0.75)) {    // 微笑
//                RR = (float)(R * 1.38);
//            } else if((R > 0.75) &&(R <= 0.8)) {
//                RR = (float)(R * 2.58);
//            } else if((R > 0.8) &&(R <= 0.9)) {
//                RR = (float)(R * 3.54);
//            } else if((R > 0.9) &&(R <= 1.0)) {     //大笑
//                RR = (float)(R * 4.22);
//            } else if(R > 1) {
//                RR = (float)(R * 5.0);
//            }
//        }
//        for(int i = 0; i < 36; i++) {
//            Log.i(TAG, "faceExpressCalculator: distanceY["+i+"] = "+distanceY[i]+", M = "+M+", MM = "+MM);
//        }
//        Log.i(TAG, "faceExpressCalculator: 眼角到嘴角 左 = "+distanceY[36]+", 右 = "+distanceY[37]);
//        Log.i(TAG, "faceExpressCalculator: 睫毛到眼角 左 = "+distanceY[38]+", 右 = "+distanceY[39]);
//        Log.i(TAG, "faceExpressCalculator: 上下眼帘 左 = "+distanceY[4]+", 右 = "+distanceY[12]);
//        Log.i(TAG, "faceExpressCalculator: 两嘴角 = "+distanceX[2]);
//        Log.i(TAG, "faceExpressCalculator: 眉嘴角眼比 左 = "+distanceX[3]+", 右 = "+distanceX[4]);
//        Log.i(TAG, "faceExpressCalculator: \tM = "+M+", \tN = "+N+", \tO = "+O+", \tP = "+P+", \tQ = "+Q+", \tR = "+R);
//        Log.i(TAG, "faceExpressCalculator: \tMM = "+MM+", \tNN = "+NN+", \tOO = "+OO+", \tPP = "+PP+", \tQQ = "+QQ+", \tRR = "+RR);
        return "";
    }
}
