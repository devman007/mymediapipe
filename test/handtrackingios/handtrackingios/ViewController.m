//
//  ViewController.m
//  handtrackingios
//
//  Created by 岳传真 on 2020/12/3.
//  Copyright © 2020 com.lyg.mediapipe. All rights reserved.
//

#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <HandTrackingFramework/HandTracker.h>

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, TrackerDelegate> {
    HandTracker               *handTracker;
    AVCaptureSession          *captureSession;
    AVCaptureDevice           *captureDevice;
    AVCaptureDeviceInput      *captureDeviceInput;
    AVCaptureVideoDataOutput  *videoDataOutput;
    AVCaptureConnection       *videoConnection;

    dispatch_queue_t          sessionQueue;
    dispatch_queue_t          videoDataOutputQueue;
    NSDictionary              *videoCompressionSettings;
    
    AVCaptureVideoPreviewLayer  *videoPreviewLayer;
}
@property(nonatomic, assign)UIImageView        *capVideoBACK;

@end

@implementation ViewController

- (id)init {
    self = [super init];
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setupCaptureSession];
    
    handTracker = [[HandTracker alloc] init];
    if(handTracker != nil) {
        [handTracker startGraph];
        handTracker.delegate = self;
    }
}

- (void)viewDidUnload {

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
    videoDataOutput.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
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
    videoPreviewLayer.frame = self.capVideoBACK.frame;
    videoPreviewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)[UIApplication sharedApplication].statusBarOrientation;
    [self.capVideoBACK.layer addSublayer:videoPreviewLayer];

    // Start the session running to start the flow of data
    [captureSession startRunning];
}

#pragma mark - TrackerDelegate
- (void)handTracker: (HandTracker*)handTracker didOutputLandmarks: (NSArray<Landmark *> *)landmarks {
    NSLog(@"landmarks");
}

- (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer {
    CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBuffer options:nil];
    CIImage *scaledImage = [ciimage imageByApplyingTransform:(CGAffineTransformMakeScale(0.5, 0.5))];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgimage = [context createCGImage:scaledImage fromRect:scaledImage.extent];
    UIImage *image = [UIImage imageWithCGImage:cgimage];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.capVideoBACK.image = image;
    });
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *) connection {

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    NSLog(@"captureOutput pixelBuffer = 0x%x", pixelBuffer);
    if(pixelBuffer != nil) {
        [handTracker processVideoFrame:pixelBuffer];
    }
    
    /*We display the result on the image view (We need to change the orientation of the image so that the video is displayed correctly)*/
//    UIImage *image = [self getUIImageFromCVPixelBuffer:pixelBuffer uiOrientation:UIImageOrientationUp];
//    UIImage *image = [self pixelBufferToImage:pixelBuffer];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.capVideoBACK.image = image;
//    });
    CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBuffer options:nil];
    CIImage *scaledImage = [ciimage imageByApplyingTransform:(CGAffineTransformMakeScale(0.5, 0.5))];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgimage = [context createCGImage:scaledImage fromRect:scaledImage.extent];
    UIImage *image = [UIImage imageWithCGImage:cgimage];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.capVideoBACK.image = image;
    });
}

- (UIImage *)getUIImageFromCVPixelBuffer:(CMSampleBufferRef)sampleBuffer {
    CGImageRef newImage = nil;
    @autoreleasepool{
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);   /*Lock the image buffer*/
        uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer); /*Get information about the image*/
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        size_t buffersize = CVPixelBufferGetDataSize(imageBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);

        CVPixelBufferUnlockBaseAddress(imageBuffer, 0); /*We unlock the  image buffer*/

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); /*Create a CGImageRef from the CVImageBufferRef*/
        CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        newImage = CGBitmapContextCreateImage(newContext);

        CGContextRelease(newContext);   /*We release some components*/
        CGColorSpaceRelease(colorSpace);
    }
    
    UIImage* image = [UIImage imageWithCGImage:newImage scale:1.0 orientation:UIImageOrientationRight];
    return image;
}

- (UIImage *)getUIImageFromCVPixelBuffer:(CVPixelBufferRef)cvPixelBuffer uiOrientation:(UIImageOrientation)uiOrientation {
    UIImage *image;
    @autoreleasepool{
        CGImageRef quartzImage = [self getCGImageFromCVPixelBuffer:cvPixelBuffer];
        image = [UIImage imageWithCGImage:quartzImage scale:1.0 orientation:uiOrientation];
        CGImageRelease(quartzImage);
    }
    return (image);
}

- (CGImageRef)getCGImageFromCVPixelBuffer:(CVPixelBufferRef)cvPixelBuffer {
    CGImageRef quartzImage;
    @autoreleasepool {
        CVImageBufferRef imageBuffer = cvPixelBuffer;
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                     bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);//kCGBitmapByteOrderDefault | kCGImageAlphaNoneSkipLast
        quartzImage = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    }
    return quartzImage;
}

-(UIImage*)pixelBufferToImage:(CVPixelBufferRef) pixelBuffer{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);// 锁定pixel buffer的基地址
    void * baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);// 得到pixel buffer的基地址
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    size_t bufferSize = CVPixelBufferGetDataSize(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);// 得到pixel buffer的行字节数
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();// 创建一个依赖于设备的RGB颜色空间
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);

    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow, rgbColorSpace,
                                       kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrderDefault,
                                       provider, NULL, true, kCGRenderingIntentDefault);//这个是建立一个CGImageRef对象的函数

    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);  //类似这些CG...Ref 在使用完以后都是需要release的，不然内存会有问题
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(rgbColorSpace);
    NSData* imgData = UIImageJPEGRepresentation(image, 1.0);//1代表图片是否压缩
    image = [UIImage imageWithData:imgData];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);   // 解锁pixel buffer

    return image;
}

- (CMSampleBufferRef)CMSampleBufferCreateCopyWithDeep:(CMSampleBufferRef)sampleBuffer{
    
    CFRetain(sampleBuffer);
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    //CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    
    CMItemCount timingCount;
    CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, nil, &timingCount);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * timingCount);
    CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, timingCount, pInfo, &timingCount);
    
    CMItemCount sampleCount = CMSampleBufferGetNumSamples(sampleBuffer);
    
    CMItemCount sizeArrayEntries;
    CMSampleBufferGetSampleSizeArray(sampleBuffer, 0, nil, &sizeArrayEntries);
    size_t *sizeArrayOut = malloc(sizeof(size_t) * sizeArrayEntries);
    CMSampleBufferGetSampleSizeArray(sampleBuffer, sizeArrayEntries, sizeArrayOut, &sizeArrayEntries);
 
    CMSampleBufferRef sout = nil;
 
    if(dataBuffer){
         
        CMSampleBufferCreate(kCFAllocatorDefault, dataBuffer, YES, nil,nil, formatDescription, sampleCount, timingCount, pInfo, sizeArrayEntries, sizeArrayOut, &sout);
    }else{
        
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CVImageBufferRef cvimgRef = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(cvimgRef,0);
        
        uint8_t *buf=(uint8_t *)CVPixelBufferGetBaseAddress(cvimgRef);
        size_t size = CVPixelBufferGetDataSize(cvimgRef);
        void * data = nil;
        if(buf){
            data = malloc(size);
            memcpy(data, buf, size);
        }
        
        size_t width = CVPixelBufferGetWidth(cvimgRef);
        size_t height = CVPixelBufferGetHeight(cvimgRef);
        OSType pixFmt = CVPixelBufferGetPixelFormatType(cvimgRef);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(cvimgRef);
        
        
        CVPixelBufferRef pixelBufRef = NULL;
        CMSampleTimingInfo timimgInfo = kCMTimingInfoInvalid;
        CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timimgInfo);
        
        OSStatus result = 0;
        CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height, pixFmt, data, bytesPerRow, NULL, NULL, NULL, &pixelBufRef);
        
        CMVideoFormatDescriptionRef videoInfo = NULL;
        
        result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBufRef, &videoInfo);
        
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBufRef, true, NULL, NULL, videoInfo, &timimgInfo, &sout);
        
        CMItemCount sizeArrayEntries;
        CMSampleBufferGetSampleSizeArray(sout, 0, nil, &sizeArrayEntries);
        size_t *sizeArrayOut = malloc(sizeof(size_t) * sizeArrayEntries);
        CMSampleBufferGetSampleSizeArray(sout, sizeArrayEntries, sizeArrayOut, &sizeArrayEntries);
        
        free(sizeArrayOut);
        
        if(!CMSampleBufferIsValid(sout)){
            NSLog(@"");
        }
    }
    
 
    free(pInfo);
    free(sizeArrayOut);
    CFRelease(sampleBuffer);
    
    return sout;
    
}

@end
