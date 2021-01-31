package com.example.upperbodyposetracking;

import java.util.Vector;

public class CalculateDistance {
    double x;
    double y;
    double z;

    public CalculateDistance(double x, double y, double z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    /**
     * 求三维坐标的两点间距离
     *  start - 起始点
     *  end  - 终点
     *  double 返回值 - 两点间距离
     */
    static double Distance(Vector3D start, Vector3D end) {
        double x1 = start.x;
        double y1 = start.y;
        double z1 = start.z;
        double x2 = end.x;
        double y2 = end.y;
        double z2 = end.z;

        return Distance(x1, y1, z1, x2, y2, z2);
    }

    static double Distance(double x1, double y1, double z1, double x2, double y2, double z2) {
        return Math.abs(Math.sqrt(Math.pow(x1 - x2, 2) + Math.pow(y1 - y2, 2) + Math.pow(z1 - z2, 2)));
    }
}
