//
//  PaymentCardExtractionViewModel.swift
//  PaymentCardScanner
//
//  Created by Serhii Liamtsev on 5/6/21.
//  Copyright © 2021 Anurag Ajwani. All rights reserved.
//

import AVFoundation
import Vision
import UIKit

protocol PaymentCardExtractionViewModelDelegate: AnyObject {
    
    func didFindCardNumber(_ number: String)
    func onCardCaptureRectangleUpdate(_ observation: VNRectangleObservation)
    func requestCardLayerRemoval()
}

final class PaymentCardExtractionViewModel: NSObject {
    
    weak var delegate: PaymentCardExtractionViewModelDelegate?
    
    private let requestHandler = VNSequenceRequestHandler()
    
    private var paymentCardRectangleObservation: VNRectangleObservation?
    private let cardNumberExtractionQueue: DispatchQueue = DispatchQueue(label: "my.card-number.processing.queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem, target: nil)
    
    private(set) var captureSession = AVCaptureSession()
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "my.image.handling.queue")
    private let videoSettings: [String: Any] = [
        (kCVPixelBufferPixelFormatTypeKey as String) : NSNumber(value: kCVPixelFormatType_32BGRA)
    ]
    
    // MARK: - Life cycle
    deinit {
        
    }
    
    override init() {
        
        super.init()
    }
    
    // MARK: - Public functions
    func changeCaptureSessionStatus(isRunning: Bool) {
        
        switch isRunning {
        case true:
            captureSession.startRunning()
        case false:
            captureSession.stopRunning()
        }
    }
    
    func setupCaptureSession() {
        
        addCameraInput()
        addVideoOutput()
    }
    
    // MARK: - Private functions
    private func addCameraInput() {
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            assertionFailure("Unable to get default video capture device")
            return
        }
        guard let cameraInput = try? AVCaptureDeviceInput(device: device) else {
            assertionFailure("Unable to get AVCaptureDeviceInput")
            return
        }
        captureSession.addInput(cameraInput)
    }
    
    private func addVideoOutput() {
        
        videoOutput.videoSettings = videoSettings
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        captureSession.addOutput(videoOutput)
        guard let connection = videoOutput.connection(with: AVMediaType.video),
              connection.isVideoOrientationSupported else {
            return
        }
        connection.videoOrientation = .portrait
    }
    
    private func detectPaymentCard(frame: CVImageBuffer) -> VNRectangleObservation? {
        
        let rectangleDetectionRequest = VNDetectRectanglesRequest()
        let paymentCardAspectRatio: Float = 85.60 / 53.98
        rectangleDetectionRequest.minimumAspectRatio = paymentCardAspectRatio * 0.95
        rectangleDetectionRequest.maximumAspectRatio = paymentCardAspectRatio * 1.10
        
        let textDetectionRequest = VNDetectTextRectanglesRequest()
        
        do {
            let requests: [VNRequest] = [rectangleDetectionRequest, textDetectionRequest]
            try requestHandler.perform(requests, on: frame)
            guard let rectangle = (rectangleDetectionRequest.results as? [VNRectangleObservation])?.first,
                  let text = (textDetectionRequest.results as? [VNTextObservation])?.first,
                  rectangle.boundingBox.contains(text.boundingBox) else {
                // no credit card rectangle detected
                return nil
            }
            
            return rectangle
            
        } catch {
            
            print("VNSequenceRequestHandler error - \(error.localizedDescription)")
            return nil
        }
        
    }
    
    private func trackPaymentCard(for observation: VNRectangleObservation, in frame: CVImageBuffer) -> VNRectangleObservation? {
        
        let request = VNTrackRectangleRequest(rectangleObservation: observation)
        request.trackingLevel = .fast
        
        do {
            
            try requestHandler.perform([request], on: frame)
            
            guard let trackedRectangle = (request.results as? [VNRectangleObservation])?.first else {
                return nil
            }
            return trackedRectangle
            
        } catch {
            
            print("VNSequenceRequestHandler error - \(error.localizedDescription)")
            return nil
        }
        
    }
    
    private func handleObservedPaymentCard(_ observation: VNRectangleObservation, in frame: CVImageBuffer) {
        
        guard let trackedPaymentCardRectangle = trackPaymentCard(for: observation, in: frame) else {
            
            paymentCardRectangleObservation = nil
            return
        }
        
        delegate?.onCardCaptureRectangleUpdate(trackedPaymentCardRectangle)
        
        cardNumberExtractionQueue.async {
            
            guard let extractedNumber = self.extractPaymentCardNumber(frame: frame, rectangle: observation) else {
                
                // print("Unable to recognize card number")
                return
            }
            
            self.delegate?.didFindCardNumber(extractedNumber)
            
        }
        
    }
    
    private func extractPaymentCardNumber(frame: CVImageBuffer, rectangle: VNRectangleObservation) -> String? {
        
        let cardPositionInImage = VNImageRectForNormalizedRect(rectangle.boundingBox, CVPixelBufferGetWidth(frame), CVPixelBufferGetHeight(frame))
        let ciImage = CIImage(cvImageBuffer: frame)
        let croppedImage = ciImage.cropped(to: cardPositionInImage)
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        
        let stillImageRequestHandler = VNImageRequestHandler(ciImage: croppedImage, options: [:])
        
        do {
            
            try stillImageRequestHandler.perform([request])
            
            guard let texts = request.results as? [VNRecognizedTextObservation], texts.count > 0 else {
                // no text detected
                // print("no text detected")
                return nil
            }
            
            let digitsRecognized = texts
                .flatMap{
                    $0.topCandidates(10).map{
                        $0.string
                    }
                }
                .map{
                    $0.trimmingCharacters(in: .whitespaces)
                }
                .filter{
                    CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: $0))
                }
            let _16digits = digitsRecognized.first(where: { $0.count == 16 })
            let has16Digits = _16digits != nil
            let _4digits = digitsRecognized.filter{ $0.count == 4 }
            let has4sections4digits = _4digits.count == 4
            
            let digits = _16digits ?? _4digits.joined()
            if !digits.isEmpty {
                print("Recognized text: \(digits)")
            }
            
            let digitsIsValid = (has16Digits || has4sections4digits) && self.checkDigits(digits)
            return digitsIsValid ? digits : nil
            
        } catch {
            
            print("VNImageRequestHandler error - \(error.localizedDescription)")
            return nil
        }
        
    }
    
    private func checkDigits(_ digits: String) -> Bool {
        
        guard digits.count == 16, CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: digits)) else {
            print("Not valid digits string - count or non-digit character")
            return false
        }
        var digits = digits
        let checksum = digits.removeLast()
        let sum = digits.reversed()
            .enumerated()
            .map{ (index, element) -> Int in
                if index % 2 == 0 {
                    guard let intElement = Int(String(element)) else {
                        return 0
                    }
                    let doubled = intElement * 2
                    guard let firstDigit = Int(String(String(doubled).first ?? Character(""))) else {
                        return 0
                    }
                    guard let lastDigit = Int(String(String(doubled).last ?? Character(""))) else {
                        return 0
                    }
                    return doubled > 9
                        ? firstDigit + lastDigit
                        : doubled
                } else {
                    return Int(String(element)) ?? 0
                }
            }
            .reduce(0){ $0 + $1 }
        let checkDigitCalc = (sum * 9) % 10
        return (Int(String(checksum)) ?? 0) == checkDigitCalc
    }
    
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension PaymentCardExtractionViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("unable to get image from sample buffer")
            return
        }
        
        delegate?.requestCardLayerRemoval()
        
        if let paymentCardRectangle = paymentCardRectangleObservation {
            handleObservedPaymentCard(paymentCardRectangle, in: frame)
            
        } else if let paymentCardRectangle = detectPaymentCard(frame: frame) {
            paymentCardRectangleObservation = paymentCardRectangle
        }
    }
    
}
