//
//  PaymentCardExtractionVC.swift
//  PaymentCardScanner
//
//  Created by Anurag Ajwani on 12/06/2020.
//  Copyright © 2020 Anurag Ajwani. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

final class PaymentCardExtractionVC: UIViewController {
    
    private var rectangleDrawing: CAShapeLayer?
    
    private lazy var viewModel: PaymentCardExtractionViewModel = PaymentCardExtractionViewModel()
    
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview = AVCaptureVideoPreviewLayer(session: self.viewModel.captureSession)
        preview.videoGravity = .resizeAspect
        return preview
    }()
    
    // MARK: - Instance dependencies
    
    private let resultsHandler: (String) -> ()
    
    // MARK: - Initializers
    deinit {
        viewModel.delegate = nil
    }
    
    init(resultsHandler: @escaping (String) -> ()) {
        self.resultsHandler = resultsHandler
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = UIView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layer.addSublayer(previewLayer)
        viewModel.delegate = self
        viewModel.setupCaptureSession()
        viewModel.changeCaptureSessionStatus(isRunning: true)
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }
    
    private func createRectangleDrawing(_ rectangleObservation: VNRectangleObservation) -> CAShapeLayer {
        
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -previewLayer.frame.height)
        let scale = CGAffineTransform.identity.scaledBy(x: previewLayer.frame.width, y: previewLayer.frame.height)
        let rectangleOnScreen = rectangleObservation.boundingBox.applying(scale).applying(transform)
        let boundingBoxPath = CGPath(rect: rectangleOnScreen, transform: nil)
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = boundingBoxPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.green.cgColor
        shapeLayer.lineWidth = 5
        shapeLayer.borderWidth = 5
        return shapeLayer
    }
    
}

// MARK: - PaymentCardExtractionViewModelDelegate
extension PaymentCardExtractionVC: PaymentCardExtractionViewModelDelegate {
    
    func didFindCardNumber(_ number: String) {
        
        DispatchQueue.main.async {
            print("Card number: \(number)")
            self.resultsHandler(number)
        }
    }
    
    func onCardCaptureRectangleUpdate(_ observation: VNRectangleObservation) {
        
        DispatchQueue.main.async {
            
            let layer = self.createRectangleDrawing(observation)
            self.rectangleDrawing?.removeFromSuperlayer()
            self.rectangleDrawing = layer
            if let safeLayer = self.rectangleDrawing {
                self.view.layer.addSublayer(safeLayer)
            }
        }
    }
    
    func requestCardLayerRemoval() {
        
        DispatchQueue.main.async {
            // removes old rectangle drawings
            self.rectangleDrawing?.removeFromSuperlayer()
        }
    }
    
}
