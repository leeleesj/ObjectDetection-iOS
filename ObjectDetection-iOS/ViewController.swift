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
    
    let drawLayer = CALayer()

    var cameraDevice: CameraDevice?

    var _model: VNCoreMLModel? = nil

    var startTime: CFTimeInterval = 0
    var totalInferenceTime: CFTimeInterval = 0
    var frameCount: Int = 0
    var lastTimestamp: CFTimeInterval = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        checkCameraPermission()
        // Record start time
        startTime = CACurrentMediaTime()
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

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("error while CMSampleBufferGetImageBuffer")
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer).oriented(.right)

        analyzeImage(image: ciImage)
        updateFPS()
    }

    func analyzeImage(image: CIImage) {
        // Record start time for inference time calculation
        let startTime = CACurrentMediaTime()
        
        do {
            if _model == nil {
                _model = try VNCoreMLModel(for: YOLOv3Tiny(configuration: MLModelConfiguration()).model)
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
            
            DispatchQueue.main.async {
                self.drawBoundingBox(bestObservation.boundingBox, bestObservation.labels.first?.identifier ?? "unknown")
                
                // Calculate inference time
                let inferenceTime = CACurrentMediaTime() - startTime
                self.inferenceLabel.text = "inference: \(String(format: "%.2f", inferenceTime * 1000)) ms"
                
                // Calculate total inference time
                self.totalInferenceTime += inferenceTime
            }
        }
        do {
            try handler.perform([request])
        } catch {
            print("error while perform request")
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
    
    func updateFPS() {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        let elapsedTime = currentTime - lastTimestamp
        
        if elapsedTime > 1 {
            let fps = Double(frameCount) / elapsedTime
            DispatchQueue.main.async {
                self.fpsLabel.text = "FPS: \(String(format: "%.2f", fps))"
            }
            
            // Reset frame count and timestamp
            frameCount = 0
            lastTimestamp = currentTime
        }
    }
}

