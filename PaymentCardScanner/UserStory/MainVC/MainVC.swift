//
//  MainVC.swift
//  PaymentCardScanner
//
//  Created by Anurag Ajwani on 12/06/2020.
//  Copyright © 2020 Anurag Ajwani. All rights reserved.
//

import UIKit

final class MainVC: UIViewController {

    private let contentView: MainVCView = MainVCView()
    
    override func loadView() {
        view = contentView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.delegate = self
    }
    
}

// MARK: - MainVCViewDelegate
extension MainVC: MainVCViewDelegate {
    
    func didTapActionButton() {
        
        let paymentCardExtractionVC = PaymentCardExtractionVC(resultsHandler: { paymentCardNumber in
            self.contentView.updateLabelText(paymentCardNumber)
            self.presentedViewController?.dismiss(animated: true, completion: nil)
        })
        paymentCardExtractionVC.modalPresentationStyle = .fullScreen
        present(paymentCardExtractionVC, animated: true, completion: nil)
    }
    
}
