//
//  FaceExpresser.h
//  Mediapipe
//
//  Created by 岳传真 on 2021/1/8.
//

#ifndef FaceExpresser_h
#define FaceExpresser_h

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "CommonViewController.h"

typedef void (^FaceExpresserType) (int type);

#define FACE_EXPRESSION_UNKNOW      0
#define FACE_EXPRESSION_HAPPY       1
#define FACE_EXPRESSION_SURPRISE    2
#define FACE_EXPRESSION_CRY         3
#define FACE_EXPRESSION_NATURE      4
#define FACE_EXPRESSION_SAD         5
#define FACE_EXPRESSION_ANGRY       6
#define FACE_EXPRESSION_NERVOUS     7
#define FACE_EXPRESSION_HEADFALSE   8

@class FaceExpresser;

@protocol FaceExpressDelegate <NSObject>
- (void)faceExpresser:(int)type;
@end

@interface FaceExpresser : CommonViewController

@property (nonatomic, weak)id <FaceExpressDelegate> delegate;

//block模式，临时禁用
@property (nonatomic, copy)FaceExpresserType expressType;

- (void)setRender:(UIView*)preview;

- (void)startMediagraph;

@end

#endif /* FaceExpresser_h */
