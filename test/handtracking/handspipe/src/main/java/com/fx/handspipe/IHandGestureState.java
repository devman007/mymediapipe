package com.fx.handspipe;

public interface IHandGestureState {
    public static final int HAND_UNKNOWN   = -1;
    public static final int HAND_FIST      = 0;
    public static final int HAND_THUMB     = 1;
    public static final int HAND_INDEX     = 2;
    public static final int HAND_MIDDLE    = 3;
    public static final int HAND_RING      = 4;
    public static final int HAND_PINKY     = 5;
    public static final int HAND_FINGER1   = 6;
    public static final int HAND_FINGER2   = 7;
    public static final int HAND_FINGER3   = 8;
    public static final int HAND_FINGER4   = 9;
    public static final int HAND_FINGER5   = 10;
    public static final int HAND_FINGER6   = 11;
    public static final int HAND_OK        = 12;
    public static final int HAND_YEAH      = 13;
    public static final int HAND_WONDERFUL = 14;
    public static final int HAND_SPIDERMAN = 15;

    void onGestureStateListener(int type, String name);
}
