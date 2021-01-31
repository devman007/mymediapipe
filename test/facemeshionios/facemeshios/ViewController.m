//
//  ViewController.m
//  facemeshios
//
//  Created by 岳传真 on 2021/1/4.
//  Copyright © 2021 com.lyg.mediapipe. All rights reserved.
//

#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <FaceMeshionFramework/FaceExpression.h>

#include "Point3D.h"

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, FaceExpressionDelegate> {
    AVCaptureSession          *captureSession;
    AVCaptureDevice           *captureDevice;
    AVCaptureDeviceInput      *captureDeviceInput;
    AVCaptureVideoDataOutput  *videoDataOutput;
    AVCaptureConnection       *videoConnection;

    dispatch_queue_t          sessionQueue;
    dispatch_queue_t          videoDataOutputQueue;
    NSDictionary              *videoCompressionSettings;

    AVCaptureVideoPreviewLayer  *videoPreviewLayer;
    FaceExpression            *faceExpression;
}

@property(nonatomic, assign)IBOutlet UIImageView        *livingVideo;
@property(nonatomic, assign)IBOutlet UILabel            *expresLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setupCaptureSession];
    
    _expresLabel.textAlignment = NSTextAlignmentCenter;
    _expresLabel.textColor = [UIColor greenColor];
    _expresLabel.numberOfLines = 1;
    _expresLabel.font = [UIFont systemFontOfSize:30.f];
    _expresLabel.font = [UIFont boldSystemFontOfSize:25.f];
    _expresLabel.font = [UIFont italicSystemFontOfSize:20.f];
    _expresLabel.text = @"";
    
    faceExpression = [[FaceExpression alloc] init];
    if(faceExpression != nil) {
        [faceExpression startGraph];
        faceExpression.delegate = self;
    }
}

- (void)setupCaptureSession {
    NSError *error = nil;
    
    // Create the session
    captureSession = [[AVCaptureSession alloc] init];

    captureSession.sessionPreset = AVCaptureSessionPresetMedium;

    sessionQueue = dispatch_queue_create( "com.apple.sample.capturepipeline.session", DISPATCH_QUEUE_SERIAL );
    videoDataOutputQueue = dispatch_queue_create( "com.apple.sample.capturepipeline.video", DISPATCH_QUEUE_SERIAL );
    dispatch_set_target_queue( videoDataOutputQueue, dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ) );

    // Find a suitable AVCaptureDevice
    captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSArray *allDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    if (allDevices.count >= 1) {
        AVCaptureDevice *device = nil;
        for (AVCaptureDevice *theDevice in allDevices) {
            if (theDevice.position == AVCaptureDevicePositionFront) {
                captureDevice = theDevice;
            }
        }
    }
    CMTime frameDuration = CMTimeMake( 1, 30);
    if ( [captureDevice lockForConfiguration:&error] ) {
        captureDevice.activeVideoMaxFrameDuration = frameDuration;
        captureDevice.activeVideoMinFrameDuration = frameDuration;
        [captureDevice unlockForConfiguration];
    } else {
        NSLog( @"videoDevice lockForConfiguration returned error %@", error );
    }
//    [captureDevice lockForConfiguration:&error];
//    captureDevice.focusMode = AVCaptureFocusModeAutoFocus;
//    captureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
////    [captureDevice setActiveVideoMinFrameDuration:frameDuration];
//    [captureDevice unlockForConfiguration];
    
    // Create a device input with the device and add it to the session.
//    captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:nil];
    captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if ( [captureSession canAddInput:captureDeviceInput] ) {
        [captureSession addInput:captureDeviceInput];
    }
//    [captureDeviceInput release];
    
    // Create a VideoDataOutput and add it to the session
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
//    videoDataOutput.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
    [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    if ( [captureSession canAddOutput:videoDataOutput] ) {
        [captureSession addOutput:videoDataOutput];
    }
//    dispatch_release(videoDataOutputQueue);
    
    videoConnection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    captureSession.sessionPreset =  AVCaptureSessionPreset640x480;
    
//    videoCompressionSettings = [[videoDataOutput setSampleBufferDelegate:queue:videoDataOutputQueue:AVStreamingKeyDeliveryPersistentContentKeyType] copy];
//    // If you wish to cap the frame rate to a known value, such as 15 fps, set minFrameDuration.
    videoDataOutput.minFrameDuration = CMTimeMake(1, 15);
    videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject:
                                            [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                            forKey:(id)kCVPixelBufferPixelFormatTypeKey];
//    [videoDataOutput release];

    videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
//    videoPreviewLayer.frame = CGRectMake(0, 0, 320, 240);
//    videoPreviewer.contentMode = UIViewContentModeScaleToFill;
//    videoPreviewer.clipsToBounds = YES;
//    videoPreviewer.autoresizesSubviews = YES;
//    videoPreviewer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |UIViewAutoresizingFlexibleTopMargin |
//                                    UIViewAutoresizingFlexibleHeight |UIViewAutoresizingFlexibleWidth;
//    //close original video preview
//    videoPreviewLayer.frame = self.livingVideo.frame;
//    videoPreviewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)[UIApplication sharedApplication].statusBarOrientation;
//    [self.livingVideo.layer addSublayer:videoPreviewLayer];

    // Start the session running to start the flow of data
    [captureSession startRunning];
}

- (UIImage *)getUIImageFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    UIImage* image;
    CGImageRef quartzImage = nil;
    @autoreleasepool{
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);   /*Lock the image buffer*/
        uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer); /*Get information about the image*/
        size_t width = CVPixelBufferGetWidth(pixelBuffer);
        size_t height = CVPixelBufferGetHeight(pixelBuffer);
        size_t buffersize = CVPixelBufferGetDataSize(pixelBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); /*Create a CGImageRef from the CVImageBufferRef*/
        CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                        bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        quartzImage = CGBitmapContextCreateImage(newContext);

        CGContextRelease(newContext);   /*We release some components*/
        CGColorSpaceRelease(colorSpace);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0); /*We unlock the  image buffer*/
    }
    image = [UIImage imageWithCGImage:quartzImage scale:1.0 orientation:UIImageOrientationLeftMirrored];//镜像
    CGImageRelease(quartzImage);
    
    return image;
}

- (void)showCaption:(int)type {
    dispatch_async(dispatch_get_main_queue(), ^{
    NSString* text;
    switch (type) {
        case FACE_EXPRESSION_HAPPY:
            text = @"高兴";
            break;
        case FACE_EXPRESSION_SURPRISE:
            text = @"惊讶";
            break;
        case FACE_EXPRESSION_CRY:
        case FACE_EXPRESSION_SAD:
            text = @"悲伤";
            break;
        case FACE_EXPRESSION_NATURE:
            text = @"自然";
            break;
        case FACE_EXPRESSION_ANGRY:
            text = @"生气";
            break;
        case FACE_EXPRESSION_HEADFALSE:
            text = @"头部偏离";
            break;
            
        default:
            break;
    }
    _expresLabel.text = text;
    NSLog(@"faceEC: ======%d====%@==========\n", type, text);
    });
}

#pragma mark - FaceExpressionDelegate methods

- (void)faceExpression:(FaceExpression *)faceExpression Type:(int)type {
    NSLog(@"%s, %d, type(%d)\n", __FUNCTION__, __LINE__, type);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showCaption:type];
    });
}

double getCurveFit(double pX[], double pY[], int num) {
  double K = 0, A = 0, B = 0, C = 0, D = 0;
  for(int i = 0; i < num; i++){
      A += pX[i] * pY[i];
      B += pX[i];
      C += pY[i];
      D += pX[i] * pX[i];
  }
  K = (num*A-B*C)/(num*D-B*B);
  return K;
}

double getAverage(double arr[], int num) {
    double avg = 0, sum = 0;
    int len = num;
    for(int i = 0; i < len; i++) {
        sum += arr[i];
    }
    avg = sum/len;

    return avg;
}

typedef struct Vecter3D {
    double x;
    double y;
    double z;
} Vecter3D;

/**
 * 求三维坐标的两点间距离
 *  start - 起始点
 *  end  - 终点
 *  double 返回值
 */
double getDistance3D(Vecter3D start, Vecter3D end) {
    double ret = fabs(sqrt(pow(start.x - end.x, 2) + pow(start.y - end.y, 2) + pow(start.z - end.z, 2)));
    return ret;
}

#define AVG_CNT         10
#define POINT_NUM       4  //输入线性拟和点

static int arr_cnt = 0;
static int total_log_cnt = 0;
static double face_width_arr[AVG_CNT];
static double face_height_arr[AVG_CNT];
static double face_ratio_arr[AVG_CNT];
static double brow_width_arr[AVG_CNT];
static double brow_height_arr[AVG_CNT];
static double brow_line_arr[AVG_CNT];
static double brow_mouth_arr[AVG_CNT];
static double brow_height_mouth_arr[AVG_CNT];
static double eye_height_arr[AVG_CNT];
static double eye_width_arr[AVG_CNT];
static double eye_height_mouth_arr[AVG_CNT];
static double mouth_width_arr[AVG_CNT];
static double mouth_height_arr[AVG_CNT];
static double mouth_pull_down_arr[AVG_CNT];
static double dis_eye_mouth_arr[AVG_CNT];

- (void)faceExpression: (FaceExpression*)faceExpression didOutputLandmarks: (NSArray<Landmark *> *)landmarks {
//     NSLog(@"Number of landmarks on hand: %d\n", landmarks.count);
//    double face_width = fabs(landmarks[132].x - landmarks[361].x);
    double face_width = [faceExpression getDistancd3DwithX1:landmarks[132].x Y1:landmarks[132].y Z1:landmarks[132].z X2:landmarks[361].x Y2:landmarks[361].y Z2:landmarks[361].z];
//    double face_height = fabs(landmarks[10].y - landmarks[152].y);
    double face_height = [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z X2:landmarks[152].x Y2:landmarks[152].y Z2:landmarks[152].z];
    double face_ratio = fabs((landmarks[133].y - landmarks[362].y)/(landmarks[133].x - landmarks[362].x));
    
    //2、眉毛宽度(注: 脸Y坐标 下 > 上, X坐标 右 > 左 眉毛变短程度: 皱变短(恐惧、愤怒、悲伤))
//    double brow_width = fabs(landmarks[53].x-landmarks[296].x +
//                         landmarks[52].x-landmarks[334].x +
//                         landmarks[65].x-landmarks[293].x +
//                         landmarks[55].x-landmarks[300].x +
//                         landmarks[70].x-landmarks[285].x +
//                         landmarks[63].x-landmarks[295].x +
//                         landmarks[105].x-landmarks[282].x +
//                         landmarks[66].x-landmarks[283].x);
    double brow_width = [faceExpression getDistancd3DwithX1:landmarks[53].x Y1:landmarks[53].y Z1:landmarks[53].z
                            X2:landmarks[296].x Y2:landmarks[296].y Z2:landmarks[296].z] +
                        [faceExpression getDistancd3DwithX1:landmarks[52].x Y1:landmarks[52].y Z1:landmarks[52].z
                            X2:landmarks[334].x Y2:landmarks[334].y Z2:landmarks[334].z] +
                        [faceExpression getDistancd3DwithX1:landmarks[65].x Y1:landmarks[65].y Z1:landmarks[65].z
                            X2:landmarks[293].x Y2:landmarks[293].y Z2:landmarks[293].z] +
                        [faceExpression getDistancd3DwithX1:landmarks[55].x Y1:landmarks[55].y Z1:landmarks[55].z         X2:landmarks[300].x Y2:landmarks[300].y Z2:landmarks[300].z] +
                        [faceExpression getDistancd3DwithX1:landmarks[70].x Y1:landmarks[70].y Z1:landmarks[70].z X2:landmarks[285].x Y2:landmarks[285].y Z2:landmarks[285].z] +
                        [faceExpression getDistancd3DwithX1:landmarks[63].x Y1:landmarks[63].y Z1:landmarks[63].z X2:landmarks[295].x Y2:landmarks[295].y Z2:landmarks[295].z] +
                        [faceExpression getDistancd3DwithX1:landmarks[105].x Y1:landmarks[105].y Z1:landmarks[105].z X2:landmarks[282].x Y2:landmarks[282].y Z2:landmarks[282].z] +
                        [faceExpression getDistancd3DwithX1:landmarks[66].x Y1:landmarks[66].y Z1:landmarks[66].z X2:landmarks[283].x Y2:landmarks[283].y Z2:landmarks[283].z];

    //2.1、眉毛高度之和
//    double brow_left_height = fabs(landmarks[10].y - landmarks[53].y +
//                                landmarks[10].y - landmarks[52].y +
//                                landmarks[10].y - landmarks[65].y +
//                                landmarks[10].y - landmarks[55].y +
//                                landmarks[10].y - landmarks[70].y +
//                                landmarks[10].y - landmarks[63].y +
//                                landmarks[10].y - landmarks[105].y +
//                                landmarks[10].y - landmarks[66].y);
    double brow_left_height = [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[53].x Y2:landmarks[53].y Z2:landmarks[53].z] +
                            [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[52].x Y2:landmarks[52].y Z2:landmarks[52].z] +
                            [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[65].x Y2:landmarks[65].y Z2:landmarks[65].z] +
                            [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[55].x Y2:landmarks[55].y Z2:landmarks[55].z] +
                            [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[70].x Y2:landmarks[70].y Z2:landmarks[70].z] +
                            [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[63].x Y2:landmarks[63].y Z2:landmarks[63].z] +
                            [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[105].x Y2:landmarks[105].y Z2:landmarks[105].z] +
                            [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[66].x Y2:landmarks[66].y Z2:landmarks[66].z];
//    double brow_right_height = fabs(landmarks[10].y - landmarks[283].y +
//                                landmarks[10].y - landmarks[282].y +
//                                landmarks[10].y - landmarks[295].y +
//                                landmarks[10].y - landmarks[285].y +
//                                landmarks[10].y - landmarks[300].y +
//                                landmarks[10].y - landmarks[293].y +
//                                landmarks[10].y - landmarks[334].y +
//                                landmarks[10].y - landmarks[296].y);
    double brow_right_height =  [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[283].x Y2:landmarks[283].y Z2:landmarks[283].z] +
                                [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[282].z Y2:landmarks[282].y Z2:landmarks[282].z] +
                                [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[295].x Y2:landmarks[295].y Z2:landmarks[295].z] +
                                [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[285].x Y2:landmarks[285].y Z2:landmarks[285].z] +
                                [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[300].x Y2:landmarks[300].y Z2:landmarks[300].z] +
                                [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[293].x Y2:landmarks[293].y Z2:landmarks[293].z] +
                                [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[334].x Y2:landmarks[334].y Z2:landmarks[334].z] +
                                [faceExpression getDistancd3DwithX1:landmarks[10].x Y1:landmarks[10].y Z1:landmarks[10].z
                                     X2:landmarks[296].x Y2:landmarks[296].y Z2:landmarks[296].z];
    double brow_hight = brow_left_height + brow_right_height;
    //2.2、眉毛高度与识别框高度之比: 眉毛抬高(惊奇、恐惧、悲伤), 眉毛压低(厌恶, 愤怒)
    double brow_hight_rate = brow_hight/16;
    double brow_width_rate = brow_width/8;
    double brow_h_w = brow_hight_rate/brow_width_rate;
    //左眉拟合曲线(53-52-65-55-70-63-105-66)
    double brow_line_points_x[POINT_NUM];
    brow_line_points_x[0] = landmarks[55].x;
    brow_line_points_x[1] = landmarks[70].x;
    brow_line_points_x[2] = landmarks[105].x;
    brow_line_points_x[3] = landmarks[107].x;
    double brow_line_points_y[POINT_NUM];
    brow_line_points_y[0] = landmarks[55].y;
    brow_line_points_y[1] = landmarks[70].y;
    brow_line_points_y[2] = landmarks[105].y;
    brow_line_points_y[3] = landmarks[107].y;

    //2.3、眉毛变化程度: 变弯(高兴、惊奇) - 上扬  - 下拉
    double brow_line_left = (-10) * (getCurveFit(brow_line_points_x, brow_line_points_y, POINT_NUM)); //调函数拟合直线
    double brow_line_rate = brow_line_left;
    
    //3、眼睛高度 (注: 眼睛Y坐标 下 > 上, X坐标 右 > 左)
    double eye_left_height = [faceExpression getDistancd3DwithX1:landmarks[145].x Y1:landmarks[145].y Z1:landmarks[145].z X2:landmarks[159].x Y2:landmarks[159].y Z2:landmarks[159].z];//fabs(landmarks[145].y - landmarks[159].y);   //中心 以后尝试修改为 Y(145) - Y(159) -> Y(23) - Y(27)
    double eye_left_width = [faceExpression getDistancd3DwithX1:landmarks[133].x Y1:landmarks[133].y Z1:landmarks[133].z X2:landmarks[33].x Y2:landmarks[33].y Z2:landmarks[33].z];//fabs(landmarks[133].x - landmarks[33].x);

    double eye_right_height = [faceExpression getDistancd3DwithX1:landmarks[253].x Y1:landmarks[253].y Z1:landmarks[253].z X2:landmarks[257].x Y2:landmarks[257].y Z2:landmarks[257].z];//fabs(landmarks[253].y - landmarks[257].y);  // 中心 以后尝试修改为 Y(374) - Y(386) -> Y(253) - Y(257)
    double eye_right_width = [faceExpression getDistancd3DwithX1:landmarks[263].x Y1:landmarks[263].y Z1:landmarks[263].z X2:landmarks[362].x Y2:landmarks[362].y Z2:landmarks[362].z];//fabs(landmarks[263].x - landmarks[362].x);

    //3.1、眼睛睁开程度: 上下眼睑拉大距离(惊奇、恐惧)
    double eye_height = (eye_left_height + eye_right_height)/2;
    double eye_width = (eye_left_width + eye_right_width)/2;
    double eye_h_w = eye_height/eye_width;
    
    double mouth_width = [faceExpression getDistancd3DwithX1:landmarks[308].x Y1:landmarks[308].y Z1:landmarks[308].z X2:landmarks[78].x Y2:landmarks[78].y Z2:landmarks[78].z];//fabs(landmarks[308].x - landmarks[78].x);
    double mouth_height = [faceExpression getDistancd3DwithX1:landmarks[17].x Y1:landmarks[17].y Z1:landmarks[17].z X2:landmarks[0].x Y2:landmarks[0].y Z2:landmarks[0].z];//fabs(landmarks[17].y - landmarks[0].y);  // 中心
    double mouth_h_w = mouth_height/mouth_width;
    
    //4.1、嘴角下拉(厌恶、愤怒、悲伤),    > 1 上扬， < 1 下拉
//    double mouth_pull_down = fabs((landmarks[14].y - landmarks[324].y)/(landmarks[14].y + landmarks[324].x));
    //对嘴角进行一阶拟合，曲线斜率
    double lips_line_points_x[POINT_NUM];
    lips_line_points_x[0] = landmarks[318].x;
    lips_line_points_x[1] = landmarks[324].x;
    lips_line_points_x[2] = landmarks[308].x;
    lips_line_points_x[3] = landmarks[291].x;
    double lips_line_points_y[POINT_NUM];
    lips_line_points_y[0] = landmarks[318].y;
    lips_line_points_y[1] = landmarks[324].y;
    lips_line_points_y[2] = landmarks[308].y;
    lips_line_points_y[3] = landmarks[291].y;
    double mouth_pull_down_rate = (-10) * (getCurveFit(lips_line_points_x, lips_line_points_y, POINT_NUM)); //调函数拟合直线
    
    //5、两侧眼角到同侧嘴角距离
    double distance_eye_left_mouth = [faceExpression getDistancd3DwithX1:landmarks[133].x Y1:landmarks[133].y Z1:landmarks[133].z X2:landmarks[78].x Y2:landmarks[78].y Z2:landmarks[78].z];//fabs(landmarks[133].y - landmarks[78].y);
    double distance_eye_right_mouth = [faceExpression getDistancd3DwithX1:landmarks[362].x Y1:landmarks[362].y Z1:landmarks[362].z X2:landmarks[308].x Y2:landmarks[308].y Z2:landmarks[308].z];//fabs(landmarks[362].y - landmarks[308].y);
    double distance_eye_mouth = distance_eye_left_mouth + distance_eye_right_mouth;

    //6、归一化
    double dis_eye_mouth_rate = (2 * mouth_width)/distance_eye_mouth;             // 嘴角 / 眼角嘴角距离, 高兴(0.85),愤怒/生气(0.7),惊讶(0.6),大哭(0.75)
    double distance_brow = [faceExpression getDistancd3DwithX1:landmarks[66].x Y1:landmarks[66].y Z1:landmarks[66].z X2:landmarks[296].x Y2:landmarks[296].y Z2:landmarks[296].z];//fabs(landmarks[66].x - landmarks[296].x);
    double dis_brow_mouth_rate = mouth_width/distance_brow;                       // 嘴角 / 两眉间距
    double dis_eye_height_mouth_rate = mouth_width/eye_height;                    // 嘴角 / 上下眼睑距离
//    double dis_brow_height_mouth_rate = (2 * mouth_width)/fabs((landmarks[70].y - landmarks[145].y));
    double dis_brow_height_mouth_rate = (2 * mouth_width)/[faceExpression getDistancd3DwithX1:landmarks[70].x Y1:landmarks[70].y Z1:landmarks[70].z X2:landmarks[145].x Y2:landmarks[145].y Z2:landmarks[145].z];
    
    //7、 求连续多次的平均值
    if(arr_cnt < AVG_CNT) {
        face_width_arr[arr_cnt] = face_width;
        face_height_arr[arr_cnt] = face_height;
        face_ratio_arr[arr_cnt] = face_ratio;
        brow_mouth_arr[arr_cnt] = dis_brow_mouth_rate;
        brow_height_mouth_arr[arr_cnt] = dis_brow_height_mouth_rate;
        brow_width_arr[arr_cnt] = brow_width_rate;
        brow_height_arr[arr_cnt] = brow_hight_rate;
        brow_line_arr[arr_cnt] = brow_line_rate;
        eye_height_arr[arr_cnt] = eye_height;
        eye_width_arr[arr_cnt] = eye_width;
        eye_height_mouth_arr[arr_cnt] = dis_eye_height_mouth_rate;
        mouth_width_arr[arr_cnt] = mouth_width;
        mouth_height_arr[arr_cnt] = mouth_height;
        mouth_pull_down_arr[arr_cnt] = mouth_pull_down_rate;
        dis_eye_mouth_arr[arr_cnt] = dis_eye_mouth_rate;
    }
    arr_cnt++;
    double face_width_avg = 0, face_height_avg = 0, face_ratio_avg = 0;
    double brow_mouth_avg = 0, brow_height_mouth_avg = 0;
    double brow_width_avg = 0, brow_height_avg = 0, brow_line_avg = 0;
    double eye_height_avg = 0, eye_width_avg = 0, eye_height_mouth_avg = 0;
    double mouth_width_avg = 0, mouth_height_avg = 0, mouth_pull_down_avg = 0;
    double dis_eye_mouth_avg = 0;
    if(arr_cnt >= AVG_CNT) {
        arr_cnt = 0;
        face_width_avg = getAverage(face_width_arr, AVG_CNT);
        face_height_avg = getAverage(face_height_arr, AVG_CNT);
        face_ratio_avg = getAverage(face_ratio_arr, AVG_CNT);
        brow_mouth_avg = getAverage(brow_mouth_arr, AVG_CNT);
        brow_height_mouth_avg = getAverage(brow_height_mouth_arr, AVG_CNT);
        brow_width_avg = getAverage(brow_width_arr, AVG_CNT);
        brow_height_avg = getAverage(brow_height_arr, AVG_CNT);
        brow_line_avg = getAverage(brow_line_arr, AVG_CNT);
        eye_height_avg = getAverage(eye_height_arr, AVG_CNT);
        eye_width_avg = getAverage(eye_width_arr, AVG_CNT);
        eye_height_mouth_avg = getAverage(eye_height_mouth_arr, AVG_CNT);
        mouth_width_avg = getAverage(mouth_width_arr, AVG_CNT);
        mouth_height_avg = getAverage(mouth_height_arr, AVG_CNT);
        mouth_pull_down_avg = getAverage(mouth_pull_down_arr, AVG_CNT);
        dis_eye_mouth_avg = getAverage(dis_eye_mouth_arr, AVG_CNT);
    }
    if(arr_cnt == 0) {
        memset(face_width_arr, 0, sizeof(face_width_arr));
        memset(face_height_arr, 0, sizeof(face_height_arr));
        memset(face_ratio_arr, 0, sizeof(face_ratio_arr));
        memset(brow_mouth_arr, 0, sizeof(brow_mouth_arr));
        memset(brow_height_mouth_arr, 0, sizeof(brow_height_mouth_arr));
        memset(brow_width_arr, 0, sizeof(brow_width_arr));
        memset(brow_height_arr, 0, sizeof(brow_height_arr));
        memset(brow_line_arr, 0, sizeof(brow_line_arr));
        memset(eye_height_arr, 0, sizeof(eye_height_arr));
        memset(eye_width_arr, 0, sizeof(eye_width_arr));
        memset(eye_height_mouth_arr, 0, sizeof(eye_height_mouth_arr));
        memset(mouth_width_arr, 0, sizeof(mouth_width_arr));
        memset(mouth_height_arr, 0, sizeof(mouth_height_arr));
        memset(mouth_pull_down_arr, 0, sizeof(mouth_pull_down_arr));
        memset(dis_eye_mouth_arr, 0, sizeof(dis_eye_mouth_arr));
    }
    total_log_cnt++;
    if(total_log_cnt >= AVG_CNT) {
        total_log_cnt = 0;
//        NSLog(@"faceEC: face_ratio_avg = %f\f", face_ratio_avg);
        if(fabs(face_ratio_avg) <= 1.5) {    //判断头部倾斜度
            NSLog(@"faceEC: face_ratio = %f\n", face_ratio);
            [self showCaption:8];
            return;
        }
        eye_h_w = eye_height_avg/eye_width_avg;
        mouth_h_w = mouth_height_avg/mouth_width_avg;
        brow_h_w = brow_height_avg/brow_width_avg;
        double eye_mouth_rate = 0;
        if(dis_eye_mouth_avg <= 0.7) {
            eye_mouth_rate = dis_eye_mouth_avg * 0;
        } else if((dis_eye_mouth_avg > 0.7) &&(dis_eye_mouth_avg <= 0.75)) {
            eye_mouth_rate = (dis_eye_mouth_avg * 1.38);
        } else if((dis_eye_mouth_avg > 0.75) &&(dis_eye_mouth_avg <= 0.8)) {
            eye_mouth_rate = (dis_eye_mouth_avg * 2.58);
        } else if((dis_eye_mouth_avg > 0.8) &&(dis_eye_mouth_avg <= 0.9)) {
            eye_mouth_rate = (dis_eye_mouth_avg * 3.54);
        } else if((dis_eye_mouth_avg > 0.9) &&(dis_eye_mouth_avg <= 1.0)) {
            eye_mouth_rate = (dis_eye_mouth_avg * 4.22);
        } else if(dis_eye_mouth_avg > 1) {
            eye_mouth_rate = (dis_eye_mouth_avg * 5.0);
        }
        NSLog(@"faceEC: eye_h_w(%f), mouth_h_w(%f), brow_line(%f), mouth_pull(%f), dis_eye_mouth(%f)\n", eye_h_w, mouth_h_w, brow_line_avg, mouth_pull_down_avg, eye_mouth_rate);
//        NSLog(@"faceEC: face(%f) w = %f, h = %f\n", face_ratio, face_width, face_height);
//        NSLog(@"faceEC: brow(%f) w = %f, h = %f\n", brow_line_rate, brow_width_rate, brow_hight_rate);
//        NSLog(@"faceEC: eye(%f) w = %f, h = %f\n", eye_h_w, eye_width, eye_height);
//        NSLog(@"faceEC: mouth(%f) w = %f, h = %f\n", mouth_h_w, mouth_width, mouth_height);
//        NSLog(@"faceEC: face(%f) w = %f, h = %f\n", face_ratio_avg, face_width_avg, face_height_avg);
//        NSLog(@"faceEC: eye(%f) w = %f, h = %f, mouth(%f) w = %f, h = %f, down = %f\n", eye_h_w, eye_width_avg, eye_height_avg, mouth_h_w, mouth_width_avg, mouth_height_avg, mouth_pull_down_avg);
//        NSLog(@"faceEC: brow_line = %f\f", brow_line_avg);
//        NSLog(@"faceEC: eye_mouth_rate = %f / %f\n", dis_eye_mouth_rate, eye_mouth_rate);
        if(mouth_h_w > 0.35) {
            if((eye_h_w >= 0.36)) {
                [self showCaption:FACE_EXPRESSION_SURPRISE];
            } else {
                if(eye_h_w  < 0.3) {
                    [self showCaption:FACE_EXPRESSION_HAPPY];
                } else {
                    [self showCaption:FACE_EXPRESSION_SAD];
                }
            }
        } else {
            if(eye_h_w >= 0.35) {
                [self showCaption:FACE_EXPRESSION_ANGRY];
            } else {
                if(eye_mouth_rate < 3.85) {
                    [self showCaption:FACE_EXPRESSION_ANGRY];
                } else {
                    [self showCaption:FACE_EXPRESSION_NATURE];
                }
            }
        }
    }
 }

- (void)faceExpression:(FaceExpression *)faceExpression didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    UIImage *image = [self getUIImageFromCVPixelBuffer:pixelBuffer];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.livingVideo.image = image;
    });
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *) connection {

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if((faceExpression != nil) &&(pixelBuffer != nil) &&(faceExpression.delegate != nil)) {
        [faceExpression processVideoFrame:pixelBuffer];
    }

}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection API_AVAILABLE(ios(6.0)) {

}

@end
