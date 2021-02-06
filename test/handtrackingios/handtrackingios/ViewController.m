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

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, HandTrackerDelegate> {
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
@property(nonatomic, assign)UILabel            *handPoseLabel;

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
    
    self.handPoseLabel = [[UILabel alloc] init];
    CGFloat width = self.view.frame.size.width;
    CGFloat height= self.view.frame.size.height;
    CGFloat x     = (width - 200)/2;
    CGFloat y     = 30;
    self.handPoseLabel.frame = CGRectMake(x, y, 200, 30);
    self.handPoseLabel.textAlignment = NSTextAlignmentCenter;
    self.handPoseLabel.textColor = [UIColor greenColor];
    self.handPoseLabel.numberOfLines = 1;
    self.handPoseLabel.font = [UIFont systemFontOfSize:30.f];
    self.handPoseLabel.font = [UIFont boldSystemFontOfSize:25.f];
    self.handPoseLabel.font = [UIFont italicSystemFontOfSize:20.f];
    self.handPoseLabel.text = @"";
    [self.view addSubview:self.handPoseLabel];
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
//    videoPreviewLayer.frame = self.capVideoBACK.frame;
//    videoPreviewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)[UIApplication sharedApplication].statusBarOrientation;
//    [self.capVideoBACK.layer addSublayer:videoPreviewLayer];

    // Start the session running to start the flow of data
    [captureSession startRunning];
}

double getDistance(double a_x, double a_y, double b_x, double b_y) {
    double dist = pow(a_x - b_x, 2) + pow(a_y - b_y, 2);
    return sqrt(dist);
}

bool IsThumbConnectFinger_1(Landmark* point1, Landmark* point2) {
    double distance = getDistance(point1.x, point1.y, point2.x, point2.y);
    return distance < 0.1;
}

#pragma mark - HandTrackerDelegate
- (void)handTracker: (HandTracker*)handTracker didOutputLandmarks: (NSArray<Landmark *> *)landmarks {
    NSLog(@"landmarks");
//    const auto& landmarks = packet.Get<::mediapipe::NormalizedLandmarkList>();
    NSLog(@"Number of landmarks on hand: %d", landmarks.count);
//    for (int i = 0; i < landmarks.landmark_size(); ++i) {
//      NSLog(@"\tLandmark[%d]: (%f, %f, %f)", i, landmarks.landmark(i).x(),
//            landmarks.landmark(i).y(), landmarks.landmark(i).z());
//    }
    
    bool IsThumb = false;
    bool IsFinger_1 = false;
    bool IsFinger_2 = false;
    bool IsFinger_3 = false;
    bool IsFinger_4 = false;

    if ([landmarks objectAtIndex:2].x < [landmarks objectAtIndex:9].x) {
        if ([landmarks objectAtIndex:3].x < [landmarks objectAtIndex:2].x && [landmarks objectAtIndex:4].x < [landmarks objectAtIndex:2].x) {
            IsThumb = true;
        }
    }
    if ([landmarks objectAtIndex:2].x > [landmarks objectAtIndex:9].x) {
        if ([landmarks objectAtIndex:3].x > [landmarks objectAtIndex:2].x && [landmarks objectAtIndex:4].x > [landmarks objectAtIndex:2].x) {
            IsThumb = true;
        }
    }

    if ([landmarks objectAtIndex:7].y < [landmarks objectAtIndex:6].y && [landmarks objectAtIndex:7].y > [landmarks objectAtIndex:8].y) {
        IsFinger_1 = true;
    }
    if ([landmarks objectAtIndex:11].y < [landmarks objectAtIndex:10].y && [landmarks objectAtIndex:11].y > [landmarks objectAtIndex:12].y) {
        IsFinger_2 = true;
    }
    if ([landmarks objectAtIndex:15].y < [landmarks objectAtIndex:14].y && [landmarks objectAtIndex:15].y > [landmarks objectAtIndex:16].y) {
        IsFinger_3 = true;
    }
    if ([landmarks objectAtIndex:19].y < [landmarks objectAtIndex:18].y && [landmarks objectAtIndex:19].y > [landmarks objectAtIndex:20].y) {
        IsFinger_4 = true;
    }

    if (IsThumb && IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4) {
        NSString* str = @"handTracker -- Five\n";
        NSLog(str);
//        return str;
    } else if (!IsThumb && IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4) {
        NSString* str = @"handTracker -- Four\n";
        NSLog(str);
//        return str;
    } else if (IsThumb && IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
        NSString* str = @"handTracker -- Three\n";
        NSLog(str);
//        return str;
    } else if (IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
        NSString* str = @"handTracker -- Two\n";
        NSLog(str);
//        return str;
//    } else if ((!IsThumb && IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) ||
//                (!IsThumb && !IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) ||
//                (!IsThumb && !IsFinger_1 && !IsFinger_2 && IsFinger_3 && !IsFinger_4) ||
//                (!IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4)
//    ) {
//        NSString* str = @"handTracker -- One\n";
//        NSLog(str);
//        return str;
    } else if (!IsThumb && IsFinger_1 && IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
        NSString* str = @"handTracker -- Yeah\n";
        NSLog(str);
//        return str;
    } else if (!IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
        NSString* str = @"handTracker -- Fist\n";
        NSLog(str);
//        return str;
    } else if (IsThumb && !IsFinger_1 && !IsFinger_2 && !IsFinger_3 && !IsFinger_4) {
        NSString* str = @"handTracker -- Wonderful\n";
        NSLog(str);
//        return str;
    } else if (!IsFinger_1 && IsFinger_2 && IsFinger_3 && IsFinger_4 && IsThumbConnectFinger_1([landmarks objectAtIndex:4], [landmarks objectAtIndex:8])) {
        NSString* str = @"handTracker -- OK\n";
        NSLog(str);
//        return str;
    } else {
//        return @"";
    }
}

- (void)handTracker: (HandTracker*)handTracker didOutputPixelBuffer: (CVPixelBufferRef)pixelBuffer {
//    CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBuffer options:nil];
//    CIImage *scaledImage = [ciimage imageByApplyingTransform:(CGAffineTransformMakeScale(0.5, 0.5))];
//    CIContext *context = [CIContext contextWithOptions:nil];
//    CGImageRef cgimage = [context createCGImage:scaledImage fromRect:scaledImage.extent];
//    UIImage *image = [UIImage imageWithCGImage:cgimage];
    
    UIImage *image = [self getUIImageFromCVPixelBuffer:pixelBuffer];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.capVideoBACK.image = image;
    });
}

- (void)handTracker: (HandTracker*)handTracker Type:(int)type Name:(NSString*)name {
    NSLog(@"handTracker type = %d, name = %@\n", type, name);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.handPoseLabel.text = name;
    });
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *) connection {

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    NSLog(@"captureOutput pixelBuffer = 0x%x", pixelBuffer);
    if((pixelBuffer != nil) &&(handTracker != nil) &&(handTracker.delegate != 0)) {
        [handTracker processVideoFrame:pixelBuffer];
    }
    
    /*We display the result on the image view (We need to change the orientation of the image so that the video is displayed correctly)*/
//    UIImage *image = [self getUIImageFromCVPixelBuffer:pixelBuffer uiOrientation:UIImageOrientationUp];
//    UIImage *image = [self pixelBufferToImage:pixelBuffer];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.capVideoBACK.image = image;
//    });
//    CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBuffer options:nil];
//    CIImage *scaledImage = [ciimage imageByApplyingTransform:(CGAffineTransformMakeScale(0.5, 0.5))];
//    CIContext *context = [CIContext contextWithOptions:nil];
//    CGImageRef cgimage = [context createCGImage:scaledImage fromRect:scaledImage.extent];
//    UIImage *image = [UIImage imageWithCGImage:cgimage];
    
//    UIImage *image = [self getUIImageFromCVPixelBuffer:sampleBuffer];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.capVideoBACK.image = image;
//    });
}

- (UIImage *)getUIImageFromCMSampleBuffer:(CMSampleBufferRef)sampleBuffer {
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
    image = [UIImage imageWithCGImage:quartzImage scale:1.0 orientation:UIImageOrientationRight];
    CGImageRelease(quartzImage);
    
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
