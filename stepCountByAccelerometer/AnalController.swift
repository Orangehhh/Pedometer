//
//  ViewController.swift
//  stepCountByAccelerometer
//
//  Created by Hao Liu on 4/4/18.
//  Copyright © 2018 Hao. All rights reserved.
//

import UIKit
import CoreMotion
import Accelerate
import Charts

class AnalController: UIViewController {
    
    var timer: Timer!
    
    let motion = CMMotionManager()
    
    var isProcessing: Bool = false
    
    var status: Int = 0    // 0: still  1 : walk  2: run
    
    let sampleRate: Double = 50     // sample frequency  Hz
    
    let numOfSampleInWindow: Int = 128
    
    let numOfStrideSample: Int = 30
    
    var windowSize: Double = 0.0
    
    var signalArr = [Double]()
    
    var fft_weights: FFTSetupD!
    
    var lastUpdateIndex: Int = 0
    
    var curIndex: Int = 0
    
    let walkfqlb: Double = 1.25
    
    let walkfqub: Double = 2.33
    
    let walkMaglb: Double = 10.0
    
    var totalWalkStep: Int = 0
    
    var previousFrequency: Double = 0.0
    
    var currentFrequency: Double = 0.0
    
    var continuesWalkCount: Int = 0
    
    let runfqlb: Double = 2.33
    
    let runfqub: Double = 3.5
    
    let runMaglb: Double = 1000.0
    
    var totalRunStep: Int = 0
    
    var continuesRunCount: Int = 0
    
    @IBOutlet weak var lineChartView: LineChartView!

    func setChartView(){
        lineChartView.chartDescription?.text = "ChartView"
        
        
        
        //设置双击坐标轴是否能缩放
        lineChartView.scaleXEnabled = true
        lineChartView.scaleYEnabled = true
        
        //设置X轴坐标
        lineChartView.xAxis.granularity = 1.0
        lineChartView.xAxis.labelPosition = .bottom
        lineChartView.xAxis.drawGridLinesEnabled = false
        lineChartView.xAxis.axisLineColor = UIColor.black
        lineChartView.xAxis.labelTextColor = UIColor.black
        
        lineChartView.leftAxis.drawGridLinesEnabled = false
        lineChartView.leftAxis.axisLineColor = UIColor.black
        lineChartView.leftAxis.labelTextColor = UIColor.black
        
        lineChartView.drawGridBackgroundEnabled = true
        lineChartView.drawBordersEnabled = true
        lineChartView.gridBackgroundColor = UIColor.white
        
        lineChartView.tintColor = UIColor.brown
        
        //添加显示动画
        lineChartView.animate(xAxisDuration: 1)
    }
    
    let dtformatter = DateFormatter()
    
    var seconds = 0
    
    var x1: Double = 0.0
    var y1: Double = 0.0
    var x2: Double = 0.0
    var y2: Double = 0.0
    var x3: Double = 0.0
    var y3: Double = 0.0
    var point: Double = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reset()
        
        setChartView()
        self.windowSize = Double(self.numOfSampleInWindow) / self.sampleRate
        self.fft_weights = vDSP_create_fftsetupD(vDSP_Length(log2(Float(numOfSampleInWindow))), FFTRadix(kFFTRadix2))
        startPredict()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func reset() {
        if self.motion.isAccelerometerActive {
            self.motion.stopAccelerometerUpdates()
        }
        if (timer != nil && self.timer.isValid) {
            self.timer.invalidate()
        }
        self.signalArr = [Double]()
        self.lineChartView.data = nil
        self.seconds = 0

        self.isProcessing = false
        self.previousFrequency = 0.0
        self.lastUpdateIndex = 0
        self.curIndex = 0
        self.totalWalkStep = 0
        self.totalRunStep = 0
        self.continuesRunCount = 0
        self.continuesWalkCount = 0
        self.status = 0
    }
    
    func startPredict() {
        
        // Make sure the accelerometer hardware is available.
        if (self.motion.isAccelerometerAvailable) {
            self.motion.accelerometerUpdateInterval = 1.0 / sampleRate
            self.motion.startAccelerometerUpdates()
            
            self.isProcessing = true

            self.motion.startAccelerometerUpdates(to: OperationQueue.current!) {
                (accelerometerData, error) in
                if let data = self.motion.accelerometerData {
                    
                    let x = data.acceleration.x
                    let y = data.acceleration.y
                    let z = data.acceleration.z
                    
                    let magnitude = sqrt(x * x + y * y + z * z)
                    
                    self.signalArr.append(magnitude)
                    self.curIndex += 1
                    if self.signalArr.count > self.numOfSampleInWindow {
                        self.signalArr.removeFirst()
                    }
                    
                    if self.signalArr.count == self.numOfSampleInWindow
                        && self.curIndex - self.lastUpdateIndex >= self.numOfStrideSample {
                        self.lastUpdateIndex = self.curIndex
                        var fftMagnitudes = [Double](repeating:0.0, count:self.signalArr.count)
                        var zeroArray = [Double](repeating:0.0, count:self.signalArr.count)
                        var dupSignalArr = [Double](repeating:0.0, count:self.signalArr.count)
                        let sumArr = self.signalArr.reduce(0, +)
                        for i in 0..<dupSignalArr.count {
                            dupSignalArr[i] = self.signalArr[i] - sumArr / Double(self.signalArr.count)
                        }
                        var splitComplexInput = DSPDoubleSplitComplex(realp: &dupSignalArr, imagp: &zeroArray)
                        
                        vDSP_fft_zipD(self.fft_weights, &splitComplexInput, 1, vDSP_Length(log2(Float(self.numOfSampleInWindow))), FFTDirection(FFT_FORWARD));
                        
                        vDSP_zvmagsD(&splitComplexInput, 1, &fftMagnitudes, 1, vDSP_Length(self.signalArr.count));
                        
                        //                        dump(fftMagnitudes)
                        var dataEntries: [ChartDataEntry] = []
                        for i in 1..<self.signalArr.count {
                            let dataPoint = ChartDataEntry(x: Double(i), y: (fftMagnitudes[i]))
                            dataEntries.append(dataPoint)
                        }
                        
                        //set line color
                        let set = LineChartDataSet(values: dataEntries, label: "FFT")
                        let data = LineChartData()
                        data.addDataSet(set)
                        
                        //外圆
//                        set.setCircleColor(UIColor.black)
                        //画外圆
                        set.drawCirclesEnabled = false
                        //内圆
//                        set.circleHoleColor(UIColor.white)
                        //画内圆
                        set.drawCircleHoleEnabled = false
                        
                        //线条显示样式
//                        set.lineDashLengths = [1,1,1,1]
//                        set.lineDashPhase = 2
                        set.colors = [UIColor.brown]

                        self.lineChartView.data = data
                        
                        let maxVal: Double = fftMagnitudes.max()!
                        var IdxOfmaxVal: Int! = fftMagnitudes.index(of: maxVal)
                        if IdxOfmaxVal >= Int(self.numOfSampleInWindow / 2) {
                            IdxOfmaxVal = self.numOfSampleInWindow - IdxOfmaxVal
                        }
                        if IdxOfmaxVal > 0 && IdxOfmaxVal < self.numOfSampleInWindow - 1 {
                            self.x1 = Double(IdxOfmaxVal - 1)
                            self.y1 = fftMagnitudes[IdxOfmaxVal - 1]
                            self.x2 = Double(IdxOfmaxVal)
                            self.y2 = fftMagnitudes[IdxOfmaxVal]
                            self.x3 = Double(IdxOfmaxVal + 1)
                            self.y3 = fftMagnitudes[IdxOfmaxVal + 1]
                            
                            let part1: Double = (self.y3 - self.y2) * self.x1 * self.x1
                            let part2: Double = (self.y2 - self.y1) * self.x3 * self.x3
                            let part3: Double = (self.y1 - self.y3) * self.x2 * self.x2
                            let part4: Double = self.x1 * (self.y3 - self.y2)
                            let part5: Double = self.x3 * (self.y2 - self.y1)
                            let part6: Double = self.x2 * (self.y1 - self.y3)
                            
                            self.point = (part1 + part2 + part3) / 2 / (part4 + part5 + part6)
                        }
                        else {
                            self.point = Double(IdxOfmaxVal)
                        }
                        //                        self.point = Double(IdxOfmaxVal)
                        print(self.point)
                        self.currentFrequency = 1.0 / (self.windowSize / Double(self.point))
                        if (self.currentFrequency >= self.walkfqlb && self.currentFrequency <= self.walkfqub && maxVal >= self.walkMaglb) {
                            self.status = 1
                            self.continuesRunCount = 0
                            if (self.continuesWalkCount == 0) {
                                self.totalWalkStep += Int(self.windowSize * self.currentFrequency)
                            }
                            else {
                                self.totalWalkStep += Int((self.windowSize - 1) * (self.currentFrequency - self.previousFrequency) + self.previousFrequency)
                            }
                            self.continuesWalkCount += 1
                            self.previousFrequency = self.currentFrequency
                        }
                        else if (self.currentFrequency > self.runfqlb && self.currentFrequency <= self.runfqub && maxVal >= self.runMaglb) {
                            self.status = 2
                            self.continuesWalkCount = 0
                            if (self.continuesRunCount == 0) {
                                self.totalRunStep += Int(self.windowSize * self.currentFrequency)
                            }
                            else {
                                self.totalRunStep += Int((self.windowSize - 1) * (self.currentFrequency - self.previousFrequency) + self.previousFrequency)
                            }
                            self.continuesRunCount += 1
                            self.previousFrequency = self.currentFrequency
                        }
                        else {
                            self.status = 0
                            self.continuesWalkCount = 0
                            self.continuesRunCount = 0
                            self.previousFrequency = 0.0
                        }
                    }
                }
            }
        }
        else {
            print("Accelerometer not support")
        }
    }
    
    
    
}

