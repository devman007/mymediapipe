package com.fx.faceexpression;

public interface IFaceExpressionState {
    public static final int FACE_EXPRESSION_UNKNOW     = 0;
    public static final int FACE_EXPRESSION_HAPPY      = 1;
    public static final int FACE_EXPRESSION_SURPRISE   = 2;
    public static final int FACE_EXPRESSION_CRY        = 3;
    public static final int FACE_EXPRESSION_NATURE     = 4;
    public static final int FACE_EXPRESSION_SAD        = 5;
    public static final int FACE_EXPRESSION_ANGRY      = 6;
    public static final int FACE_EXPRESSION_NERVOUS    = 7;
    public static final int FACE_EXPRESSION_HEADFALSE  = 8;

    void onExpressStateListener(int type, String name);
}
