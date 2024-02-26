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

    let drawLayer = CALayer()

    var cameraDevice: CameraDevice?

    var _model: VNCoreMLModel? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        checkCameraPermission()
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
    }

    func analyzeImage(image: CIImage) {
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

            print("bestObservation box : \(String(describing: bestObservation.boundingBox))")
            DispatchQueue.main.async {
                self.drawBoundingBox(bestObservation.boundingBox, bestObservation.labels.first?.identifier ?? "unknown")
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
}

