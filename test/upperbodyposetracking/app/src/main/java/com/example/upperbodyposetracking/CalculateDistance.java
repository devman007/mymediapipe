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

    static double Distance(Vector3D startPos, Vector3D endPos) {
        double sqrt = Math.sqrt(Math.pow(startPos.x - endPos.x, 2) + Math.pow(startPos.y - endPos.y, 2) + Math.pow(startPos.z - endPos.z, 2));
        return Math.abs(sqrt);
    }
}
