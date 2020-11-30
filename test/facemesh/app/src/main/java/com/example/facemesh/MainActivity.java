package com.example.facemesh;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import android.content.pm.ApplicationInfo;
import android.graphics.Color;
import android.graphics.SurfaceTexture;
import android.os.Bundle;
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
import com.google.protobuf.InvalidProtocolBufferException;

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
        faceLandmarksStr      += "\t\tLandmark count: " + landmarkList.getLandmarkCount() + "\n";
        for (int i = 0; i < landmarkList.getLandmarkCount(); i++) {
            faceLandmarksStr  += "\t\tLandmark ["
                                + i + "], "
                                + landmarkList.getLandmark(i).getX() + ", "
                                + landmarkList.getLandmark(i).getY() + ", "
                                + landmarkList.getLandmark(i).getZ() + ")\n";

//            // Left eyebrow. 10
//            46, 53, 53, 52, 52, 65, 65, 55, 70, 63, 63, 105, 105, 66, 66, 107,
//            // Left eye. 16
//            33,   7,   7, 163, 163, 144, 144, 145, 145, 153, 153, 154, 154, 155, 155, 133,
//            33, 246, 246, 161, 161, 160, 160, 159, 159, 158, 158, 157, 157, 173, 173, 133,
            if((landmarkList.getLandmark(33).getY() > landmarkList.getLandmark(145).getY()) &&
                    (landmarkList.getLandmark(133).getY() > landmarkList.getLandmark(145).getY())) {
                return "smile";
            }

//            // Right eyebrow. 10
//            276, 283, 283, 282, 282, 295, 295, 285, 300, 293, 293, 334, 334, 296, 296, 336,
//            // Right eye. 16
//            263, 249, 249, 390, 390, 373, 373, 374, 374, 380, 380, 381, 381, 382, 382, 362,
//            263, 466, 466, 388, 388, 387, 387, 386, 386, 385, 385, 384, 384, 398, 398, 362,

//            // Lips. 40
//            61, 146, 146, 91, 91, 181, 181, 84, 84, 17, 17, 314, 314, 405, 405, 321, 321, 375, 375, 291,
//            61, 185, 185, 40, 40,  39,  39, 37, 37,  0,  0, 267, 267, 269, 269, 270, 270, 409, 409, 291,
//            78,  95,  95, 88, 88, 178, 178, 87, 87, 14, 14, 317, 317, 402, 402, 318, 318, 324, 324, 308,
//            78, 191, 191, 80, 80,  81,  81, 82, 82, 13, 13, 312, 312, 311, 311, 310, 310, 415, 415, 308,

//            // Face oval.
//            10, 338, 338, 297, 297, 332, 332, 284, 284, 251, 251, 389, 389, 356, 356,
//            454, 454, 323, 323, 361, 361, 288, 288, 397, 397, 365, 365, 379, 379, 378,
//            378, 400, 400, 377, 377, 152, 152, 148, 148, 176, 176, 149, 149, 150, 150,
//            136, 136, 172, 172, 58, 58, 132, 132, 93, 93, 234, 234, 127, 127, 162, 162,
//            21, 21, 54, 54, 103, 103, 67, 67, 109, 109, 10
        }
        return "";
    }
}
