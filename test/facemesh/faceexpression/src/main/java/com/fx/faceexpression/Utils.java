package com.fx.faceexpression;

import java.math.BigDecimal;

import static java.lang.Float.NaN;

public class Utils {
    private static final String TAG = "Utils";

    public Utils() {
    }

    /**
     * 求平均数
     * @param type - 类型标签
     * @param arr - 数值数值
     * @param num - 保留有效数
     * @return
     */
    private static double getAverage(String type, double[] arr, int num) {
        double avg = 0f, sum = 0f;
        int len = arr.length;
        for(int i = 0; i < len; i++) {
            sum += arr[i];
        }
        try {
            BigDecimal bigD = new BigDecimal(sum/len);
            avg = (double) (bigD.setScale(num, BigDecimal.ROUND_HALF_UP).doubleValue());
        } catch (NumberFormatException e) {

        }
//        Log.i(TAG, "faceEC average: "+type+", avg = "+avg);
        return avg;
    }

    /**
     * 四舍五入
     * @param val - 数值
     * @param num - 保留小数点后的有效数位
     * @return
     */
    private static double getRound(double val, int num) {
        double ret = 0f;
        if((num < 1) ||(val == 0f) ||(val == NaN)) {
            return val;
        }
        try {
            BigDecimal bigD = new BigDecimal(val);
            ret = (double) (bigD.setScale(num, BigDecimal.ROUND_HALF_UP).doubleValue());
        } catch (NumberFormatException e) {

        }

        return ret;
    }

    /**
     *
     *    要求的方程为: y=ax+b。
     *               N∑xy-∑x∑y
     *    其中：a = ----------------       //曲线斜率
     *               N∑(x^2)-(∑x)^2
     *
     *                  b=y-ax
     *               ∑y∑(x^2)-∑x∑xy
     *         b = ---------------        //曲线截距
     *               N∑(x^2)-(∑x)^2
     *    设：A=∑xy  B=∑x  C=∑y  D=∑(x^2)
     *    注：N为要拟合的点数量
     *
     * 参数说明：
     * @param pX - 传入要线性拟合的点数据X
     * @param pY - 传入要线性拟合的点数据Y
     * @param N  - 线性拟合的点的数量
     * @return   - 曲线斜率, 自左向右 >0(上扬), <0(下拉)
     */
    private static double getCurveFit(double pX[], double pY[], int N) {
        double ret = 0, b = 0, A = 0, B = 0, C = 0, D = 0;
//        WeightedObservedPoints points = new WeightedObservedPoints();
//        for(int i = 0; i < pX.length; i++) {
//            points.add(pX[i], pY[i]);
//        }
//        PolynomialCurveFitter fitter = PolynomialCurveFitter.create(1); //指定为1阶数
//        double[] result = fitter.fit(points.toList());
//        ret = result[1]*(-10);  //0 - 常数项，1 - 为一次项，拟合出曲线的斜率和实际眉毛的倾斜方向是相反
        for(int i = 0; i < N; i++){
            A += pX[i] * pY[i];
            B += pX[i];
            C += pY[i];
            D += pX[i] * pX[i];
        }
        ret = (N*A-B*C)/(N*D-B*B);
//        b = C/N-ret*B/N;
        return ret;
    }
}
