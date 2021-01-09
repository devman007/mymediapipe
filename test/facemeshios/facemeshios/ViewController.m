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
#import <FaceMeshFramework/FaceExpression.h>

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
        [faceExpression initialize];
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
    NSString* text;
    switch (type) {
        case 1:
            text = @"高兴";
            break;
        case 2:
            text = @"惊讶";
            break;
        case 3:
        case 5:
            text = @"悲伤";
            break;
        case 4:
            text = @"自然";
            break;
        case 6:
            text = @"生气";
            break;
        case 8:
            text = @"头部偏离";
            break;
            
        default:
            break;
    }
    _expresLabel.text = text;
    NSLog(@"faceEC: ======%d====%@==========\n", type, text);
}

#pragma mark - FaceExpressionDelegate methods

- (void)faceExpression:(FaceExpression *)faceExpression Type:(int)type {
    NSLog(@"%s, %d, type(%d)\n", __FUNCTION__, __LINE__, type);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showCaption:type];
    });
}

// - (void)faceExpression:(FaceExpression *)faceExpression didOutputLandmarks:(NSArray<Landmark *> *)landmarks {
//     NSLog(@"Number of landmarks on hand: %d\n", landmarks.count);
// }

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
