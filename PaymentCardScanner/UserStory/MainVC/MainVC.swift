//
//  MainVC.swift
//  PaymentCardScanner
//
//  Created by Anurag Ajwani on 12/06/2020.
//  Copyright © 2020 Anurag Ajwani. All rights reserved.
//

import UIKit

final class MainVC: UIViewController {

    @IBOutlet private weak var resultsLabel: UILabel!

    @IBAction private func scanPaymentCard(_ sender: Any) {
        
        let paymentCardExtractionViewController = PaymentCardExtractionViewController(resultsHandler: { paymentCardNumber in
            self.resultsLabel.text = paymentCardNumber
            self.dismiss(animated: true, completion: nil)
        })
        paymentCardExtractionViewController.modalPresentationStyle = .fullScreen
        self.present(paymentCardExtractionViewController, animated: true, completion: nil)
    }
}

