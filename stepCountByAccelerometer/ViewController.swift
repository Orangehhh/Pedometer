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

class ViewController: UIViewController {
    
    var timer: Timer!
    
    let motion = CMMotionManager()
    
    var isProcessing: Bool = false      
    
    var status: Int = 0    // 0: still  1 : walk  2: run

    let sampleRate: Double = 50     // sample frequency  Hz

    let numOfSampleInWindow: Int = 128
    
    let numOfStrideSample: Int = 25
    
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
    
    let dtformatter = DateFormatter()
    
    var seconds = 0
    
    var x1: Double = 0.0
    var y1: Double = 0.0
    var x2: Double = 0.0
    var y2: Double = 0.0
    var x3: Double = 0.0
    var y3: Double = 0.0
    var point: Double = 0.0
    
    @IBOutlet weak var startBtn: UIButton!
    
    @IBOutlet weak var resetBtn: UIBarButtonItem!
    
    @IBOutlet weak var timeLabel: UILabel!
    
    @IBOutlet weak var outputLabel: UILabel!
    
    @IBOutlet weak var walkStepLabel: UILabel!
    
    @IBOutlet weak var runStepLabel: UILabel!
    
    @IBOutlet weak var lineChartView: LineChartView!
    
    @IBOutlet weak var navBar: UINavigationBar!
    
    @IBOutlet weak var frequencyLabel: UILabel!
    
    @IBAction func tapReset(_ sender: UITapGestureRecognizer) {
        reset()
    }
    
    func reset() {
//        print("reset")
        if self.motion.isAccelerometerActive {
            self.motion.stopAccelerometerUpdates()
        }
        if (timer != nil && self.timer.isValid) {
            self.timer.invalidate()
        }
        self.signalArr = [Double]()
        self.lineChartView.data = nil
        self.seconds = 0
        self.timeLabel.text = timeString(time: TimeInterval(self.seconds))
        self.outputLabel.text = ""
        self.walkStepLabel.text = "0"
        self.runStepLabel.text = "0"
        self.isProcessing = false
        self.previousFrequency = 0.0
        self.lastUpdateIndex = 0
        self.curIndex = 0
        self.totalWalkStep = 0
        self.totalRunStep = 0
        self.continuesRunCount = 0
        self.continuesWalkCount = 0
        self.status = 0
        startBtn.setTitle("Start", for: UIControlState.normal)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addNavBarTitle()
        customBtn()
        self.windowSize = Double(self.numOfSampleInWindow) / self.sampleRate
        self.fft_weights = vDSP_create_fftsetupD(vDSP_Length(log2(Float(numOfSampleInWindow))), FFTRadix(kFFTRadix2))
        reset()
    }
    
    @IBAction func startBtn(_ sender: UIButton) {
        if !self.isProcessing {
            runTimer()
            startPredict()
        }
        else {
            timer.invalidate()
            stopPredict()
        }
    }
    
    func startPredict() {

        // Make sure the accelerometer hardware is available.
        if (self.motion.isAccelerometerAvailable) {
            self.motion.accelerometerUpdateInterval = 1.0 / sampleRate
            self.motion.startAccelerometerUpdates()
            
            self.isProcessing = true
            startBtn.setTitle("Stop", for: UIControlState.normal)
            
            // Configure a timer to fetch the data.
//            self.timer = Timer(fire: Date(), interval: (1.0 / sampleRate),
//                               repeats: true, block: { (timer) in
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
                        let set = LineChartDataSet(values: dataEntries, label: "FFT")
                        let data = LineChartData()
                        data.addDataSet(set)
                        
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
                        self.frequencyLabel.text = "\(self.currentFrequency) \n   \(self.point)  \n \(IdxOfmaxVal)"
//                        print(self.totalWalkStep)
                    }
                    self.walkStepLabel.text = "\(self.totalWalkStep)"
                    self.runStepLabel.text = "\(self.totalRunStep)"
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
            }
//            RunLoop.current.add(self.timer!, forMode: .defaultRunLoopMode)
        }
        else {
            print("Accelerometer not support")
        }
    }
    
    func stopPredict() {
        self.motion.stopAccelerometerUpdates()
        self.lineChartView.data = nil
        self.outputLabel.text = ""
        self.walkStepLabel.text = "\(self.totalWalkStep)"
        self.runStepLabel.text = "\(self.totalRunStep)"
        self.isProcessing = false
        startBtn.setTitle("Start", for: UIControlState.normal)
        self.timer.invalidate()
    }
    
    func getDate() -> (String) {
        let currentTime = NSDate()
        dtformatter.dateFormat = "LLLL dd"
        return dtformatter.string(from: currentTime as Date)
    }
    
    func addNavBarTitle() {
        self.navBar.topItem?.title = "\(getDate())"
    }
    
    func customBtn() {
        startBtn.frame = CGRect(x: 160, y: 100, width: 100, height: 100)
        startBtn.layer.cornerRadius = 0.5 * startBtn.bounds.size.width
        startBtn.clipsToBounds = true
        startBtn.setImage(UIImage(named:"thumbsUp.png"), for: UIControlState.normal)
    }
    
    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.updateTimer), userInfo: nil, repeats: true)
    }
    
    @objc func updateTimer() {
        self.seconds += 1
        self.timeLabel.text = timeString(time: TimeInterval(self.seconds))
    }
    
    func timeString(time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
}

