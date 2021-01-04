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
//    FaceExpression            *faceExpression;
}

@property(nonatomic, assign)UIImageView        *livingVideo;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setupCaptureSession];
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
    videoPreviewLayer.frame = CGRectMake(0, 0, 320, 240);
//    videoPreviewer.contentMode = UIViewContentModeScaleToFill;
//    videoPreviewer.clipsToBounds = YES;
//    videoPreviewer.autoresizesSubviews = YES;
//    videoPreviewer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |UIViewAutoresizingFlexibleTopMargin |
//                                    UIViewAutoresizingFlexibleHeight |UIViewAutoresizingFlexibleWidth;
    //close original video preview
    videoPreviewLayer.frame = self.livingVideo.frame;
    videoPreviewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)[UIApplication sharedApplication].statusBarOrientation;
    [self.livingVideo.layer addSublayer:videoPreviewLayer];

    // Start the session running to start the flow of data
    [captureSession startRunning];
}

#pragma mark - FaceExpressionDelegate methods

- (void)faceExpression:(FaceExpression *)faceExpression Type:(int)type {

}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *) connection {

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection API_AVAILABLE(ios(6.0)) {
    
}

@end
