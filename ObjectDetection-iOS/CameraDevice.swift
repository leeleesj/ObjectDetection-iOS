//
//  CameraDevice.swift
//  ObjectDetection-iOS
//
//  Created by sangju.lee on 2/22/24.
//

import Foundation
import AVFoundation

internal enum CameraException: Error {
    case openFailed
    case setConfigurationFailed
}

internal class CameraDevice: NSObject {
    private var captureDevice: AVCaptureDevice?
    private var captureSession = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    private var videoPreviewThreadLabel: String = "com.modelTest.camera.videoQueue"
    
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var videoDataOutputDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    
    init(preview: AVCaptureVideoPreviewLayer,
         cameraBufferDataDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?) {
        videoPreviewLayer = preview
        videoDataOutputDelegate = cameraBufferDataDelegate
    }
    
    public func openCamera(cameraType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera,
                           position: AVCaptureDevice.Position = . back) throws {
        let ret = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        if ret != .authorized {
            print("Not Autorized for Video")
            return
        }
        
        guard let cameraDevice = AVCaptureDevice.default(cameraType, for: .video, position: position) else {
            print("cannot get camera(type: \(cameraType.rawValue), \(position.rawValue)")
            return
        }
        
        if let input = videoInput {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
            captureSession.removeInput(input)
        }
        
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: cameraDevice)
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                videoInput = videoDeviceInput
            } else {
                print("cannot add deviceInput to session")
            }
            
            self.captureDevice = cameraDevice
            
            let videoDeviceOutput = AVCaptureVideoDataOutput()
            videoDeviceOutput.setSampleBufferDelegate(videoDataOutputDelegate, queue:DispatchQueue(label: videoPreviewThreadLabel))
            videoDeviceOutput.automaticallyConfiguresOutputBufferDimensions = false
            videoDeviceOutput.alwaysDiscardsLateVideoFrames = true
            
            if captureSession.canAddOutput(videoDeviceOutput) {
                captureSession.addOutput(videoDeviceOutput)
            }
        } catch {
            print("cannot open camera. error: \(error.localizedDescription)")
            captureSession.commitConfiguration()
            throw CameraException.openFailed
        }
        
        captureSession.commitConfiguration()
        
        if let preview = self.videoPreviewLayer {
            preview.session = self.captureSession
        }
        
        self.captureSession.startRunning()
        
        try cameraDevice.lockForConfiguration()
        cameraDevice.videoZoomFactor = 2.0
        cameraDevice.unlockForConfiguration()
    }
    
    public func closeCamera() {
        if captureSession.isRunning == true {
            captureSession.stopRunning()
        }
        if let input = videoInput {
            captureSession.removeInput(input)
        }
        if let output = videoOutput {
            captureSession.removeOutput(output)
        }
        
        self.videoPreviewLayer = nil
        self.captureDevice = nil
    }
    
} // end class
