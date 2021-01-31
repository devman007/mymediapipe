//
// Created by 岳传真 on 2021/1/22.
//

#ifndef UPPERBODYPOSETRACKING_POINT3D_H
#define UPPERBODYPOSETRACKING_POINT3D_H

//一个三维点坐标的类Point3D，要求如下：
//（1）包含三个int类型数据成员my_x, my_y, my_z；
//（2）默认构造函数，默认三维点的坐标值为0, 0, 0；
//（3）SetPoint函数，设置坐标值；
//（4）用成员函数重载”+”运算符，实现两个Point3D类对象的加法运算；
//（4）用友元函数重载前置“++”运算符以实现Point3D类对象的z值加1；
//（5）重载运算符”<<”，实现点类对象的输出，坐标值x,y,z间以”,”分隔。
//（6）在main( ) 函数中测试类Point3D“+”和前置“++”的功能，并输出结果。

//class Point3D {
//public:
//    Point3D(double x, double y, double z);
//    void SetPoint(double x, double y, double z);
//    Point3D operator + (const Point3D & point) const;
//    friend Point3D operator ++ (const Point3D & point);
//
//private:
//    double x, y, z;
//
//};

#endif //UPPERBODYPOSETRACKING_POINT3D_H
