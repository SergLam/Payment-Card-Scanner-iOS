//
//  MainVCView.swift
//  PaymentCardScanner
//
//  Created by Serhii Liamtsev on 5/6/21.
//  Copyright © 2021 Anurag Ajwani. All rights reserved.
//

import UIKit

protocol MainVCViewDelegate: AnyObject {
    
    func didTapActionButton()
}

final class MainVCView: UIView {
    
    weak var delegate: MainVCViewDelegate?
    
    private let containerView: UIStackView = UIStackView()
    
    private let actionButton: UIButton = UIButton()
    private let resultsLabel: UILabel = UILabel()
    
    // MARK: - Life cycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialSetup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        initialSetup()
    }
    
    // MARK: - Public functions
    func updateLabelText(_ text: String?) {
        
        resultsLabel.text = text
    }
    
    // MARK: - Private functions
    private func initialSetup() {
        
        setupLayout()
        actionButton.addTarget(self, action: #selector(didTapActionButton), for: .touchUpInside)
    }
    
    private func setupLayout() {
        
        addSubview(containerView)
        containerView.axis = .vertical
        containerView.alignment = .center
        containerView.spacing = 20.0
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        let containerViewConstraints: [NSLayoutConstraint] = [
        
            containerView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            containerView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10),
            containerView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10)
        ]
        NSLayoutConstraint.activate(containerViewConstraints)
        
        containerView.addArrangedSubview(resultsLabel)
        resultsLabel.textAlignment = .center
        resultsLabel.text = "No results, tap on scan payment card to get started"
        
        containerView.addArrangedSubview(actionButton)
        actionButton.setTitle("Scan Payment Card", for: .normal)
        actionButton.setTitleColor(UIColor.systemBlue, for: .normal)
        
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        let actionButtonConstraints: [NSLayoutConstraint] = [
        
            actionButton.widthAnchor.constraint(equalTo: self.widthAnchor, multiplier: 0.7)
        ]
        NSLayoutConstraint.activate(actionButtonConstraints)
    }
    
    // MARK: - Actions
    @objc
    private func didTapActionButton() {
        
        delegate?.didTapActionButton()
    }
    
}
