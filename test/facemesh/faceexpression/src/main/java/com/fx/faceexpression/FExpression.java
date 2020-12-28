package com.fx.faceexpression;

import android.app.Activity;
import android.content.Context;
import android.util.Log;
import android.view.SurfaceHolder;

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

public class FExpression {
    private static final String TAG = "FExpression";

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

    // Sends camera-preview frames into a MediaPipe graph for processing, and displays the processed
    // frames onto a {@link Surface}.
    protected static FrameProcessor processor;

    // Creates and manages an {@link EGLContext}.
    private EglManager eglManager;

    // Converts the GL_TEXTURE_EXTERNAL_OES texture from Android camera into a regular texture to be
    // consumed by {@link FrameProcessor} and the underlying MediaPipe graph.
    private ExternalTextureConverter converter;

    // face mesh
    private static final String BINARY_GRAPH_NAME = "face_mesh_mobile_gpu.binarypb";
    private static final String INPUT_VIDEO_STREAM_NAME = "input_video";
    private static final String OUTPUT_VIDEO_STREAM_NAME = "output_video";

    private static final String INPUT_NUM_FACES_SIDE_PACKET_NAME = "num_faces";
    private static final String OUTPUT_LANDMARKS_STREAM_NAME = "multi_face_landmarks";

    // Max number of faces to detect/process.
    private static final int NUM_FACES = 4;

    private static final boolean FLIP_FRAMES_VERTICALLY = true;
    private static final boolean USE_FRONT_CAMERA = true;

    private static IFaceExpressionState expressionState = null;

    public FExpression() {

    }

    public void setFaceExpressionStateListener(IFaceExpressionState stateListener) {
        expressionState = stateListener;
    }

    public void initialize(Activity activity) {
        AndroidAssetUtil.initializeNativeAssetManager(activity);
        eglManager = new EglManager(null);
        processor = new FrameProcessor(
                        activity,
                        eglManager.getNativeContext(),
                        BINARY_GRAPH_NAME,
                        INPUT_VIDEO_STREAM_NAME,
                        OUTPUT_VIDEO_STREAM_NAME);

        processor.getVideoSurfaceOutput().setFlipY(FLIP_FRAMES_VERTICALLY);

        PermissionHelper.checkAndRequestCameraPermissions(activity);

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
//                    runOnUiThread(new Runnable() {
//                        @Override
//                        public void run() {
//                            faceexpress.setText(faceExpressCalculator(multiFaceLandmarks));
                    faceExpressCalculator(multiFaceLandmarks);
//                        }
//                    });
                });
    }

    public void resume() {
        converter = new ExternalTextureConverter(eglManager.getContext());
        converter.setFlipY(FLIP_FRAMES_VERTICALLY);
        converter.setConsumer(processor);
    }

    public void pause() {
        converter.close();
    }

    public void surfaceCreate(SurfaceHolder holder) {
        processor.getVideoSurfaceOutput().setSurface(holder.getSurface());
    }

    public void surfaceDestory() {
        processor.getVideoSurfaceOutput().setSurface(null);
    }

    public int getFaceExpressionType() {
        int ret = 0;
        ret = processor.getFaceExpressionType();
        return ret;
    }

    private static final int POINT_NUM = 4;  //输入线性拟和点

    private static final int FACE_EXPRESSION_UNKNOWN    = 0;
    private static final int FACE_EXPRESSION_HAPPY      = 1;
    private static final int FACE_EXPRESSION_SURPRISE   = 2;
    private static final int FACE_EXPRESSION_CRY        = 3;
    private static final int FACE_EXPRESSION_NATURE     = 4;
    private static final int FACE_EXPRESSION_SAD        = 5;
    private static final int FACE_EXPRESSION_ANGRY      = 6;
    private static final int FACE_EXPRESSION_NERVOUS    = 7;
    private static final int FACE_EXPRESSION_HEADFALSE  = 8;

    private static final int AVG_CNT = 10;
    private static final int DETECT_TIMES = 2;

    static double brow_width_arr[] = new double[AVG_CNT];
    static double brow_height_arr[] = new double[AVG_CNT];
    static double brow_line_arr[] = new double[AVG_CNT];
    static double brow_mouth_arr[] = new double[AVG_CNT];
    static double brow_height_mouth_arr[] = new double[AVG_CNT];
    static double eye_height_arr[] = new double[AVG_CNT];
    static double eye_width_arr[] = new double[AVG_CNT];
    static double eye_height_mouth_arr[] = new double[AVG_CNT];
    static double mouth_width_arr[] = new double[AVG_CNT];
    static double mouth_height_arr[] = new double[AVG_CNT];
    static double mouth_pull_down_arr[] = new double[AVG_CNT];
    static int arr_cnt = 0;
    static int normal_times = 0, suprise_times = 0, sad_times = 0, happy_times = 0, angry_times = 0;
    static int total_log_cnt = 0;
    static String showString = "";
    private static String faceExpressCalculator(List<LandmarkProto.NormalizedLandmarkList> multiFaceLandmarks) {
        // 正常// 惊讶// 伤心// 开心// 生气// 微笑// 大笑// 紧张
        LandmarkProto.NormalizedLandmarkList landmarkList = multiFaceLandmarks.get(0);
        String faceLandmarksStr = "";
        faceLandmarksStr += "\t\tLandmark count: " + landmarkList.getLandmarkCount() + "\n";
        //脸宽
        double face_width = 0;
        double face_height = 0;
        double face_ratio = 0;
        //眉毛
        double brow_width = 0;
        double brow_hight = 0;
        double brow_line_left = 0;
        double brow_left_height = 0;
        double brow_right_height = 0;
        //眼睛
        double eye_width = 0;
        double eye_height = 0;
        double eye_left_height = 0;
        double eye_left_width = 0;
        double eye_right_height = 0;
        double eye_right_width = 0;
        //嘴巴
        double mouth_width = 0;
        double mouth_height = 0;

        //眼角嘴角距离
        double distance_eye_left_mouth = 0;
        double distance_eye_right_mouth = 0;
        double distance_eye_mouth = 0;

//        for (int i = 0; i < landmarkList.getLandmarkCount(); i++) {
//            faceLandmarksStr  += "\t\tLandmark ["
//                                + i + "], "
//                                + landmarkList.getLandmark(i).getX() + ", "
//                                + landmarkList.getLandmark(i).getY() + ", "
//                                + landmarkList.getLandmark(i).getZ() + ")\n";
//            Log.i(TAG, faceLandmarksStr);
//        }
        // 1、计算人脸识别框边长(注: 脸Y坐标 下 > 上, X坐标 右 > 左)
        face_width = landmarkList.getLandmark(361).getX() - landmarkList.getLandmark(132).getX();
        face_height = landmarkList.getLandmark(152).getY() - landmarkList.getLandmark(10).getY();
        //判断头部倾斜度
        face_ratio = (landmarkList.getLandmark(362).getY() - landmarkList.getLandmark(133).getY())/(landmarkList.getLandmark(362).getX() - landmarkList.getLandmark(133).getX());

        //2、眉毛宽度(注: 脸Y坐标 下 > 上, X坐标 右 > 左 眉毛变短程度: 皱变短(恐惧、愤怒、悲伤))
        brow_width = landmarkList.getLandmark(296).getX()-landmarkList.getLandmark(53).getX() +
                landmarkList.getLandmark(334).getX()-landmarkList.getLandmark(52).getX() +
                landmarkList.getLandmark(293).getX()-landmarkList.getLandmark(65).getX() +
                landmarkList.getLandmark(300).getX()-landmarkList.getLandmark(55).getX() +
                landmarkList.getLandmark(285).getX()-landmarkList.getLandmark(70).getX() +
                landmarkList.getLandmark(295).getX()-landmarkList.getLandmark(63).getX() +
                landmarkList.getLandmark(282).getX()-landmarkList.getLandmark(105).getX() +
                landmarkList.getLandmark(283).getX()-landmarkList.getLandmark(66).getX();

        //2.1、眉毛高度之和
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
        brow_hight = brow_left_height + brow_right_height;
        //2.2、眉毛高度与识别框高度之比: 眉毛抬高(惊奇、恐惧、悲伤), 眉毛压低(厌恶, 愤怒) - Solution 1(7-1)
        double brow_hight_rate = brow_hight/16;
        double brow_width_rate = brow_width/8;
//        // 分析挑眉程度和皱眉程度, 左眉拟合曲线(53-52-65-55-70-63-105-66) - 暂时未使用
        double brow_line_points_x[] = new double[POINT_NUM];
        brow_line_points_x[0] = (landmarkList.getLandmark(52).getX());
        brow_line_points_x[1] = (landmarkList.getLandmark(70).getX());
        brow_line_points_x[2] = (landmarkList.getLandmark(105).getX());
        brow_line_points_x[3] = (landmarkList.getLandmark(107).getX());
        double brow_line_points_y[] = new double[POINT_NUM];
        brow_line_points_y[0] = (landmarkList.getLandmark(52).getY());
        brow_line_points_y[1] = (landmarkList.getLandmark(70).getY());
        brow_line_points_y[2] = (landmarkList.getLandmark(105).getY());
        brow_line_points_y[3] = (landmarkList.getLandmark(107).getY());

        //2.3、眉毛变化程度: 变弯(高兴、惊奇) - 上扬  - 下拉 - Solution 1(7-2) - 临时关闭(未使用)
//        brow_line_left = (landmarkList.getLandmark(105).getY() - landmarkList.getLandmark(52).getY())/(landmarkList.getLandmark(105).getX() - landmarkList.getLandmark(52).getX());
        brow_line_left = (-10) * (processor.getCurveFit(brow_line_points_x, brow_line_points_y, POINT_NUM)); //调函数拟合直线
        double brow_line_rate = brow_line_left;  // + brow_line_right;
//        brow_left_up = landmarkList.getLandmark(70).getY()-landmarkList.getLandmark(10).getY()/* + landmarkList.getLandmark(66).getY()-landmarkList.getLandmark(10).getY()*/;
//        brow_right_up = landmarkList.getLandmark(300).getY()-landmarkList.getLandmark(10).getY()/* + landmarkList.getLandmark(283).getY()-landmarkList.getLandmark(10).getY()*/;

        //3、眼睛高度 (注: 眼睛Y坐标 下 > 上, X坐标 右 > 左)
        eye_left_height = landmarkList.getLandmark(145).getY() - landmarkList.getLandmark(159).getY();   //中心 以后尝试修改为 Y(145) - Y(159) -> Y(23) - Y(27)
        eye_left_width = landmarkList.getLandmark(133).getX() - landmarkList.getLandmark(33).getX();
        eye_right_height = landmarkList.getLandmark(374).getY() - landmarkList.getLandmark(386).getY();  // 中心 以后尝试修改为 Y(374) - Y(386) -> Y(253) - Y(257)
        eye_right_width = landmarkList.getLandmark(263).getX() - landmarkList.getLandmark(362).getX();

        //3.1、眼睛睁开程度: 上下眼睑拉大距离(惊奇、恐惧) - Solution 1(7-4)
        eye_height = (eye_left_height + eye_right_height)/2;
        // 两眼角距离
        eye_width = (eye_left_width + eye_right_width)/2;

        //4、嘴巴宽高(两嘴角间距离- 用于计算嘴巴的宽度 注: 嘴巴Y坐标 上 > 下, X坐标 右 > 左 嘴巴睁开程度- 用于计算嘴巴的高度: 上下嘴唇拉大距离(惊奇、恐惧、愤怒、高兴))
        mouth_width = landmarkList.getLandmark(308).getX() - landmarkList.getLandmark(78).getX();
        mouth_height = landmarkList.getLandmark(17).getY() - landmarkList.getLandmark(0).getY();  // 中心

        //4.1、嘴角下拉(厌恶、愤怒、悲伤),    > 1 上扬， < 1 下拉 - Solution 1(7-7)
        double mouth_line_rate = ((landmarkList.getLandmark(78).getY() + landmarkList.getLandmark(308).getY()))/(landmarkList.getLandmark(14).getY() + landmarkList.getLandmark(0).getY());
//        Log.i(TAG, "faceEC: mouth_line_rate = "+mouth_line_rate);
        //对嘴角进行一阶拟合，曲线斜率
        double lips_line_points_x[] = new double[POINT_NUM];
        lips_line_points_x[0] = (landmarkList.getLandmark(318).getX());
        lips_line_points_x[1] = (landmarkList.getLandmark(324).getX());
        lips_line_points_x[2] = (landmarkList.getLandmark(308).getX());
        lips_line_points_x[3] = (landmarkList.getLandmark(291).getX());
        double lips_line_points_y[] = new double[POINT_NUM];
        lips_line_points_y[0] = (landmarkList.getLandmark(318).getY());
        lips_line_points_y[1] = (landmarkList.getLandmark(324).getY());
        lips_line_points_y[2] = (landmarkList.getLandmark(308).getY());
        lips_line_points_y[3] = (landmarkList.getLandmark(291).getY());
        double mouth_pull_down = (-10) * (processor.getCurveFit(lips_line_points_x, lips_line_points_y, POINT_NUM));
//        Log.i(TAG, "faceEC: mouth_pull_down = "+mouth_pull_down);

        //5、两侧眼角到同侧嘴角距离
        distance_eye_left_mouth = landmarkList.getLandmark(78).getY() - landmarkList.getLandmark(133).getY();
        distance_eye_right_mouth = landmarkList.getLandmark(308).getY() - landmarkList.getLandmark(362).getY();
        distance_eye_mouth = distance_eye_left_mouth + distance_eye_right_mouth;

        //6、归一化
        double MM = 0, NN = 0, PP = 0, QQ = 0;
        double dis_eye_mouth_rate = (2 * mouth_width)/distance_eye_mouth;             // 嘴角 / 眼角嘴角距离, 高兴(0.85),愤怒/生气(0.7),惊讶(0.6),大哭(0.75)
        double distance_brow = landmarkList.getLandmark(296).getX() - landmarkList.getLandmark(66).getX();
        double dis_brow_mouth_rate = mouth_width/distance_brow;                       // 嘴角 / 两眉间距
        double dis_eye_height_mouth_rate = mouth_width/eye_height;                    // 嘴角 / 上下眼睑距离
        double dis_brow_height_mouth_rate = (2 * mouth_width)/(landmarkList.getLandmark(145).getY() - landmarkList.getLandmark(70).getY());
        // 眉毛上扬与识别框宽度之比
//        double brow_up_rate = (brow_left_up + brow_right_up)/(2*face_width);
//        // 眼睛睁开距离与识别框高度之比
//        double eye_height_rate = eye_height/face_width;
//        double eye_width_rate = eye_width/face_width;
//        // 张开嘴巴距离与识别框高度之比
//        double mouth_width_rate = mouth_width/face_width;
//        double mouth_height_rate = mouth_height/face_width;
//        Log.i(TAG, "faceEC: 眼角嘴 = "+dis_eye_mouth_rate+", \t眉角嘴 = "+dis_brow_mouth_rate+", \t眼高嘴 = "+dis_eye_height_mouth_rate+", \t眉高嘴 = "+dis_brow_height_mouth_rate);

        //7、 求连续多次的平均值
        if(arr_cnt < AVG_CNT) {
            brow_mouth_arr[arr_cnt] = dis_brow_mouth_rate;
            brow_height_mouth_arr[arr_cnt] = dis_brow_height_mouth_rate;
            eye_height_mouth_arr[arr_cnt] = dis_eye_height_mouth_rate;
            brow_width_arr[arr_cnt] = brow_width_rate;
            brow_height_arr[arr_cnt] = brow_hight_rate;
            brow_line_arr[arr_cnt] = brow_line_rate;
            eye_height_arr[arr_cnt] = eye_height;
            eye_width_arr[arr_cnt] = eye_width;
            mouth_width_arr[arr_cnt] = mouth_width;
            mouth_height_arr[arr_cnt] = mouth_height;
            mouth_pull_down_arr[arr_cnt] = mouth_pull_down;
        }
        double brow_mouth_avg = 0, brow_height_mouth_avg = 0;
        double brow_width_avg = 0, brow_height_avg = 0, brow_line_avg = 0;
        double eye_height_avg = 0, eye_width_avg = 0, eye_height_mouth_avg = 0;
        double mouth_width_avg = 0, mouth_height_avg = 0, mouth_pull_down_avg = 0;
        arr_cnt++;
        if(arr_cnt >= AVG_CNT) {
            brow_mouth_avg = processor.getAverage(brow_mouth_arr, 4);
            brow_height_mouth_avg = processor.getAverage(brow_height_mouth_arr, 4);
            brow_width_avg = processor.getAverage(brow_width_arr, 4);
            brow_height_avg = processor.getAverage(brow_height_arr, 4);
            brow_line_avg = processor.getAverage(brow_line_arr, 4);
            eye_height_avg = processor.getAverage(eye_height_arr, 4);
            eye_width_avg = processor.getAverage(eye_width_arr, 4);
            eye_height_mouth_avg = processor.getAverage(eye_height_mouth_arr, 4);
            mouth_width_avg = processor.getAverage(mouth_width_arr, 4);
            mouth_height_avg = processor.getAverage(mouth_height_arr, 4);
            mouth_pull_down_avg = processor.getAverage(mouth_pull_down_arr, 4);
            arr_cnt = 0;
        }

        //8、表情算法
        processor.setFaceExpressionFace(face_width, face_height, face_ratio);
        processor.setFaceExpressionBrow(brow_width_avg, brow_height_avg, brow_line_avg);
        processor.setFaceExpressionEye(eye_width_avg, eye_height_avg, dis_eye_mouth_rate);
        processor.setFaceExpressionMouth(mouth_width_avg , mouth_height_avg, mouth_pull_down_avg, brow_height_mouth_avg);

        //9、抛出表情结果
        total_log_cnt++;
        if(total_log_cnt >= AVG_CNT) {
            int ret = processor.getFaceExpressionType();
            expressionState.onExpressState(ret, "");
            switch (ret) {
                case FACE_EXPRESSION_HAPPY:
//                    setExpression_happy();
                    break;
                case FACE_EXPRESSION_SURPRISE:
//                    setExpression_surprise();
                    break;
                case FACE_EXPRESSION_CRY:
                case FACE_EXPRESSION_SAD:
//                    setExpression_sad();
                    break;
                case FACE_EXPRESSION_NATURE:
//                    setExpression_normal();
                    break;
                case FACE_EXPRESSION_ANGRY:
//                    setExpression_angry();
                    break;
                case FACE_EXPRESSION_HEADFALSE:
//                    Log.i(TAG, "faceEC: ============头部太偏=============");
                    showString = "头部太偏";
                    break;
                default:
                    break;
            }
            total_log_cnt = 0;
        }
        return showString;
    }
}
