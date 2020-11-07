package com.example.faceeffect;

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

import com.google.mediapipe.components.CameraXPreviewHelper;
import com.google.mediapipe.components.ExternalTextureConverter;
import com.google.mediapipe.components.FrameProcessor;
import com.google.mediapipe.components.PermissionHelper;
import com.google.mediapipe.framework.Packet;
import com.google.mediapipe.framework.PacketGetter;
import com.google.mediapipe.glutil.EglManager;

import java.util.List;

public class MainActivity extends AppCompatActivity {
    private static final String TAG = "MainActivity";

    // 资源文件和流输出名
    // 面部识别
    private static final String IS_FACEPAINT_EFFECT_SELECTED_INPUT_STREAM_NAME = "is_facepaint_effect_selected";
    private static final String OUTPUT_FACE_GEOMETRY_STREAM_NAME = "multi_face_geometry";
    private static final String EFFECT_SWITCHING_HINT_TEXT = "Tap to switch between effects!";

    private static final int MATRIX_TRANSLATION_Z_INDEX = 14;

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

    private final Object isFacepaintEffectSelectedLock = new Object();
    private boolean isFacepaintEffectSelected;

    private View effectSwitchingHintView;
    private GestureDetector tapGestureDetector;

    // 加载动态库
    static {
        System.loadLibrary("mediapipe_jni");
        try {
            System.loadLibrary("opencv_java3");
        } catch (Exception e) {
            System.loadLibrary("opencv_java4");
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        effectSwitchingHintView = createEffectSwitchingHintView();
        effectSwitchingHintView.setVisibility(View.INVISIBLE);
        ViewGroup viewGroup = findViewById(R.id.preview_display_layout);
        viewGroup.addView(effectSwitchingHintView);

        // By default, render the glasses effect.
        isFacepaintEffectSelected = false;

        processor.addPacketCallback(
                OUTPUT_FACE_GEOMETRY_STREAM_NAME,
                (packet) -> {
                    effectSwitchingHintView.post(
                            new Runnable() {
                                @Override
                                public void run() {
                                    effectSwitchingHintView.setVisibility(View.VISIBLE);
                                }
                            });

                    Log.d(TAG, "Received a multi face geometry packet.");
                    List<FaceGeometry> multiFaceGeometry =
                            PacketGetter.getProtoVector(packet, FaceGeometry.parser());

                    StringBuilder approxDistanceAwayFromCameraLogMessage = new StringBuilder();
                    for (FaceGeometry faceGeometry : multiFaceGeometry) {
                        if (approxDistanceAwayFromCameraLogMessage.length() > 0) {
                            approxDistanceAwayFromCameraLogMessage.append(' ');
                        }
                        MatrixData poseTransformMatrix = faceGeometry.getPoseTransformMatrix();
                        approxDistanceAwayFromCameraLogMessage.append(
                                -poseTransformMatrix.getPackedData(MATRIX_TRANSLATION_Z_INDEX));
                    }

                    Log.d(TAG, "[TS:"
                                    + packet.getTimestamp()
                                    + "] size = "
                                    + multiFaceGeometry.size()
                                    + "; approx. distance away from camera in cm for faces = ["
                                    + approxDistanceAwayFromCameraLogMessage
                                    + "]");
                });

        // Alongside the input camera frame, we also send the `is_facepaint_effect_selected` boolean
        // packet to indicate which effect should be rendered on this frame.
        processor.setOnWillAddFrameListener(
                (timestamp) -> {
                    Packet isFacepaintEffectSelectedPacket = null;
                    try {
                        synchronized (isFacepaintEffectSelectedLock) {
                            isFacepaintEffectSelectedPacket =
                                    processor.getPacketCreator().createBool(isFacepaintEffectSelected);
                        }

                        processor
                                .getGraph()
                                .addPacketToInputStream(
                                        IS_FACEPAINT_EFFECT_SELECTED_INPUT_STREAM_NAME,
                                        isFacepaintEffectSelectedPacket,
                                        timestamp);
                    } catch (RuntimeException e) {
                        Log.e(
                                TAG,
                                "Exception while adding packet to input stream while switching effects: " + e);
                    } finally {
                        if (isFacepaintEffectSelectedPacket != null) {
                            isFacepaintEffectSelectedPacket.release();
                        }
                    }
                });

        // We use the tap gesture detector to switch between face effects. This allows users to try
        // multiple pre-bundled face effects without a need to recompile the app.
        tapGestureDetector = new GestureDetector(
                this,
                new GestureDetector.SimpleOnGestureListener() {
                    @Override
                    public void onLongPress(MotionEvent event) {
                        switchEffect();
                    }

                    @Override
                    public boolean onSingleTapUp(MotionEvent event) {
                        switchEffect();
                        return true;
                    }

                    private void switchEffect() {
                        synchronized (isFacepaintEffectSelectedLock) {
                            isFacepaintEffectSelected = !isFacepaintEffectSelected;
                        }
                    }
                });
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
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        PermissionHelper.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        return tapGestureDetector.onTouchEvent(event);

    }

    private View createEffectSwitchingHintView() {
        TextView effectSwitchingHintView = new TextView(getApplicationContext());
        effectSwitchingHintView.setLayoutParams(
                new RelativeLayout.LayoutParams(ViewGroup.LayoutParams.FILL_PARENT, ViewGroup.LayoutParams.FILL_PARENT));
        effectSwitchingHintView.setText(EFFECT_SWITCHING_HINT_TEXT);
        effectSwitchingHintView.setGravity(Gravity.CENTER_HORIZONTAL | Gravity.BOTTOM);
        effectSwitchingHintView.setPadding(0, 0, 0, 480);
        effectSwitchingHintView.setTextColor(Color.parseColor("#ffffff"));
        effectSwitchingHintView.setTextSize((float) 24);

        return effectSwitchingHintView;
    }
}
