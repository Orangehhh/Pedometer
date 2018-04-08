//
//  ViewController.swift
//  stepCountByAccelerometer
//
//  Created by 刘皓 on 4/4/18.
//  Copyright © 2018 Hao. All rights reserved.
//

import UIKit
import CoreMotion
import Accelerate
import Charts

class ViewController: UIViewController {
    
    var timer: Timer!
    
    let motion = CMMotionManager()
    
    var isProcessing: Bool = false
    
    var status: Int = 0    // 0: still  1 : walk  2: run

    let sampleRate: Double = 60.0     //30Hz

    let numOfSampleInWindow: Int = 128
    
    let numOfStrideSample: Int = 32
    
    var windowSize: Double = 0.0
    
    var signalArr = [Double]()
    
    var fft_weights: FFTSetupD!
    
    var lastUpdateIndex: Int = 0
    
    var curIndex: Int = 0
    
    let walkfqlb:Double = 1.25
    
    let walkfqub:Double = 2.0
    
    let walkMaglb:Double = 20.0
    
    var totalStep: Int = 0
    
    var previousFrequency: Double = 0.0
    
    var currentFrequency: Double = 0.0
    
    var continuesCount: Int = 0
    
    @IBOutlet weak var startBtn: UIButton!
    
    @IBOutlet weak var outputLabel: UILabel!
    
    @IBOutlet weak var stepLabel: UILabel!
    
    @IBOutlet weak var lineChartView: LineChartView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.windowSize = Double(self.numOfSampleInWindow) / self.sampleRate
        self.fft_weights = vDSP_create_fftsetupD(vDSP_Length(log2(Float(numOfSampleInWindow))), FFTRadix(kFFTRadix2))
        self.lineChartView.data = nil
        self.outputLabel.text = nil
        self.stepLabel.text = nil
    }
    
    @IBAction func startBtn(_ sender: UIButton) {
        if !self.isProcessing {
            startPredict()
        }
        else {
            stopPredict()
        }
    }

    func startPredict() {

        // Make sure the accelerometer hardware is available.
        if (self.motion.isAccelerometerAvailable && self.motion.isGyroAvailable) {
            self.motion.accelerometerUpdateInterval = 1.0 / sampleRate
            self.motion.startAccelerometerUpdates()
            
            self.isProcessing = true
            startBtn.setTitle("Stop", for: UIControlState.normal)
            
            // Configure a timer to fetch the data.
            self.timer = Timer(fire: Date(), interval: (1.0 / sampleRate),
                               repeats: true, block: { (timer) in
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
                        for i in 0..<self.signalArr.count {
                            let dataPoint = ChartDataEntry(x: Double(i), y: fftMagnitudes[i])
                            dataEntries.append(dataPoint)
                        }
                        let set = LineChartDataSet(values: dataEntries, label: "hi")
                        let data = LineChartData()
                        data.addDataSet(set)
                        
                        self.lineChartView.data = data
                        
                        let maxVal: Double = fftMagnitudes.max()!
                        var IdxOfmaxVal: Int! = fftMagnitudes.index(of: maxVal)
                        if IdxOfmaxVal >= Int(self.numOfSampleInWindow / 2) {
                            IdxOfmaxVal = self.numOfSampleInWindow - IdxOfmaxVal
                        }
                        print(IdxOfmaxVal)
                        self.currentFrequency = 1.0 / (self.windowSize / Double(IdxOfmaxVal))
                        if (self.currentFrequency >= self.walkfqlb && self.currentFrequency <= self.walkfqub && maxVal >= self.walkMaglb) {
                            self.status = 1
                            if (self.continuesCount == 0) {
                                self.totalStep += Int(self.windowSize * self.currentFrequency)
                            }
                            else {
                                self.totalStep += Int((self.windowSize - 1) * (self.currentFrequency - self.previousFrequency) + self.previousFrequency)
                            }
                            self.continuesCount += 1
                            self.previousFrequency = self.currentFrequency
                        }
                        else {
                            self.status = 0
                            self.continuesCount = 0
                            self.previousFrequency = 0.0
                        }
                    }
                    self.stepLabel.text = "\(self.totalStep)"
                    if self.status == 0 {
                        self.outputLabel.text = "Still"
                    }
                    else if self.status == 1 {
                        self.outputLabel.text = "Walk"
                    }
                    else {
                        self.outputLabel.text = "Run"
                    }
                   
                }
            })
            RunLoop.current.add(self.timer!, forMode: .defaultRunLoopMode)
        }
        else {
            print("Accelerometer not support")
        }
    }
    
    func stopPredict() {
        self.motion.stopAccelerometerUpdates()
        self.lineChartView.data = nil
        self.outputLabel.text = nil
        self.stepLabel.text = nil
        self.isProcessing = false
        startBtn.setTitle("Start", for: UIControlState.normal)
        self.timer.invalidate()
    }
}

