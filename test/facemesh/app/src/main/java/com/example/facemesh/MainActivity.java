package com.example.facemesh;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import android.os.Bundle;
import android.util.Log;
import android.util.Size;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.fx.faceexpression.FExpression;
import com.fx.faceexpression.IFaceExpressionState;

public class MainActivity extends AppCompatActivity {
    private static final String TAG = "MainActivity";

    // {@link SurfaceView} that displays the camera-preview frames processed by a MediaPipe graph.
    private SurfaceView previewDisplayView;

    private static TextView faceexpress;
    private String showString = "";
    private FExpression fExpression = null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        faceexpress = (TextView)findViewById(R.id.faceexpress);
        fExpression = new FExpression(this);
        previewDisplayView = fExpression.getSurfaceView();

        ViewGroup viewGroup = findViewById(R.id.preview_display_layout);
        viewGroup.addView(previewDisplayView);

        fExpression.setFaceExpressionStateListener(new IFaceExpressionState() {
            @Override
            public void onExpressStateListener(int type, String name) {
                Log.i(TAG, "faceEC: type = "+type);
                switch (type) {
                    case FACE_EXPRESSION_HAPPY:
                        setExpression_happy();
                        break;
                    case FACE_EXPRESSION_SURPRISE:
                        setExpression_surprise();;
                        break;
                    case FACE_EXPRESSION_CRY:
                    case FACE_EXPRESSION_SAD:
                        setExpression_sad();
                        break;
                    case FACE_EXPRESSION_NATURE:
                        setExpression_normal();
                        break;
                    case FACE_EXPRESSION_ANGRY:
                        setExpression_angry();
                        break;
                    case FACE_EXPRESSION_HEADFALSE:
                        setExpression_headfalse();
                        break;
                    default:
                        break;
                }
                faceexpress.setText(showString);
            }
        });
        fExpression.startCamera();
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
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        return super.onTouchEvent(event);

    }

    private void setExpression_headfalse() {
        Log.i(TAG, "faceEC: ============头部太偏=============");
        showString = "头部太偏";
    }

    private void setExpression_happy() {
        Log.i(TAG, "faceEC: =====================高兴=================");
        showString = "高兴";
    }

    private void setExpression_normal() {
        Log.i(TAG, "faceEC: =====================自然=================");
        showString = "自然";
    }

    private void setExpression_sad() {
        Log.i(TAG, "faceEC: =====================悲伤=================");
        showString = "悲伤";
    }

    private void setExpression_angry() {
        Log.i(TAG, "faceEC: =====================愤怒=================");
        showString = "愤怒";
    }

    private void setExpression_surprise() {
        Log.i(TAG, "faceEC: =====================惊讶=================");
        showString = "惊讶";
    }
}
