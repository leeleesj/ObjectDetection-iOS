//
//  ViewController.swift
//  ObjectDetection-iOS
//
//  Created by sangju.lee on 2/21/24.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet weak var previewView: UIView!
    
    @IBOutlet weak var inferenceLabel: UILabel!
    @IBOutlet weak var etimeLabel: UILabel!
    @IBOutlet weak var fpsLabel: UILabel!
    
    @IBOutlet weak var pickerModel: UIPickerView!
    @IBOutlet weak var lblModelFileName: UILabel!
    
    let MAX_ARRAY_NUM = 5
    let PICKER_VIEW_COLUMN = 1
    var modelFileName = ["YOLOv8m", "YOLOv8n", "YOLOv8s", "YOLOv8l", "YOLOv8x"]
    var selectedModel: String?
    
    let drawLayer = CALayer()

    var cameraDevice: CameraDevice?
    var performanceMeasure = PerfermanceMeasurer()

    let maf1 = MovingAverageFilter()
    let maf2 = MovingAverageFilter()
    let maf3 = MovingAverageFilter()
    
    var _model: VNCoreMLModel? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        checkCameraPermission()
        performanceMeasure.delegate = self
    }
    
    func checkCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
            if granted {
                print("granted")
                self.openCamera()
            } else {
                print("not granted")
            }
        })
    }

    func openCamera() {
        let previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill

        DispatchQueue.main.async {
            self.previewView.layer.addSublayer(previewLayer)
            previewLayer.frame = self.previewView.bounds
            self.previewView.layer.addSublayer(self.drawLayer)
            self.drawLayer.frame = self.previewView.bounds
        }

        cameraDevice = CameraDevice(preview: previewLayer, cameraBufferDataDelegate: self)

        DispatchQueue.global().async {
            do {
                try self.cameraDevice?.openCamera(cameraType: .builtInWideAngleCamera, position: .back)
            } catch {
                print("error while opening camera")
            }
        }
    }

    func drawBoundingBox(_ box: CGRect, _ label: String) {
        let layerWidth = drawLayer.bounds.width
        let layerHeight = drawLayer.bounds.height
        let boundingBox = CGRect(
            x: box.origin.x * layerWidth,
            y: (1.0 - box.origin.y - box.height) * layerHeight,
            width: box.width * layerWidth,
            height: box.height * layerHeight
        )
        let boundingBoxLayer = getBoundingBoxLayer(boundingBox, label)
        drawLayer.sublayers = nil
        drawLayer.addSublayer(boundingBoxLayer)
    }

    func getBoundingBoxLayer(_ rect: CGRect, _ label: String) -> CALayer {
        let boxLayer = CATextLayer()
        boxLayer.frame = rect
        boxLayer.borderWidth = 3.0
        boxLayer.borderColor = UIColor.red.cgColor
        boxLayer.fontSize = 16
        boxLayer.foregroundColor = UIColor.red.cgColor
        boxLayer.string = label
        return boxLayer
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("error while CMSampleBufferGetImageBuffer")
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer).oriented(.right)
        // start of measure
        self.performanceMeasure.startMeasurement()
        analyzeImage(image: ciImage)
    }
    
}

// MARK: MLModel prediction & post-processing
extension ViewController {
    func analyzeImage(image: CIImage) {
        do {
            if _model == nil {
                switch selectedModel {
                case "YOLOv8n":
                    _model = try VNCoreMLModel(for: yolov8n(configuration: MLModelConfiguration()).model)
                    print("model: YOLOv8n")
                case "YOLOv8s":
                    _model = try VNCoreMLModel(for: yolov8s(configuration: MLModelConfiguration()).model)
                    print("model: YOLOv8s")
                case "YOLOv8m":
                    _model = try VNCoreMLModel(for: yolov8m(configuration: MLModelConfiguration()).model)
                    print("model: YOLOv8m")
                case "YOLOv8l":
                    _model = try VNCoreMLModel(for: yolov8l(configuration: MLModelConfiguration()).model)
                    print("model: YOLOv8l")
                case "YOLOv8x":
                    _model = try VNCoreMLModel(for: yolov8x(configuration: MLModelConfiguration()).model)
                    print("model: YOLOv8x")
                default:
                    print("model did not load")
                    break
                }
            }
        } catch {
            print("cannot load mlmodel")
        }
        guard let model = _model else {
            print("there is no model")
            return
        }

        let handler = VNImageRequestHandler(ciImage: image, orientation: .up)
        let request = VNCoreMLRequest(model: model) { requested, error in
            guard let observations = requested.results as? [VNRecognizedObjectObservation] else {
                print("there is no observations")
                return
            }
            let _bestObservation = observations.max { lhs, rhs in
                lhs.confidence < rhs.confidence
            }
            guard let bestObservation = _bestObservation else {
                print("there is no bestObservation")
                return
            }
            self.performanceMeasure.labelMeasurement(with: "endInference")
            DispatchQueue.main.async {
                self.drawBoundingBox(bestObservation.boundingBox, bestObservation.labels.first?.identifier ?? "unknown")
                self.performanceMeasure.endMeasurement()
            }
        }
        do {
            try handler.perform([request])
        } catch {
            print("error while perform request")
        }
    }
}

extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return PICKER_VIEW_COLUMN
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return modelFileName.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return modelFileName[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedModel = modelFileName[row]
        lblModelFileName.text = selectedModel
    }
}

extension ViewController: PerformanceMeasurerDelegate {
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Double) {
        self.maf1.append(element: inferenceTime*1000.0)
        self.maf2.append(element: executionTime*1000.0)
        self.maf3.append(element: fps)
        
        self.inferenceLabel.text = "inference: \(self.maf1.averageValue) ms"
        self.etimeLabel.text = "execution: \(self.maf2.averageValue) ms"
        self.fpsLabel.text = "fps: \(self.maf3.averageValue)"
    }
}

class MovingAverageFilter {
    private var arr: [Double] = []
    private let maxCount = 10
    
    public func append(element: Double) {
        arr.append(element)
        if arr.count > maxCount {
            arr.removeFirst()
        }
    }
    
    public var averageValue: Double {
        guard !arr.isEmpty else { return 0 }
        let sum = arr.reduce(0) { $0 + $1 }
        let average = Double(sum) / Double(arr.count)
        return Double(String(format: "%.1f", average)) ?? 0
    }
}
