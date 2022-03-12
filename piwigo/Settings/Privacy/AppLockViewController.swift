//
//  AppLockViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

enum AppLockAction {
    case enterPassword
    case verifyPassword
}

protocol AppLockDelegate: NSObjectProtocol {
    func didSetAppLock(toState isLocked: Bool)
}

class AppLockViewController: UIViewController {

    weak var delegate: AppLockDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var titleLabelHorSpace: NSLayoutConstraint!
    @IBOutlet weak var digitStackVertSpace: NSLayoutConstraint!
    @IBOutlet weak var digit1: UIButton!
    @IBOutlet weak var digit2: UIButton!
    @IBOutlet weak var digit3: UIButton!
    @IBOutlet weak var digit4: UIButton!
    @IBOutlet weak var digit5: UIButton!
    @IBOutlet weak var digit6: UIButton!
    @IBOutlet weak var mainStack: UIStackView!
    @IBOutlet weak var mainStackHorSpace: NSLayoutConstraint!
    @IBOutlet weak var stackRow1: UIStackView!
    @IBOutlet weak var stackRow2: UIStackView!
    @IBOutlet weak var stackRow3: UIStackView!
    @IBOutlet weak var stackRow4: UIStackView!
    @IBOutlet weak var button1: UIButton!
    @IBOutlet weak var button2: UIButton!
    @IBOutlet weak var button3: UIButton!
    @IBOutlet weak var button4: UIButton!
    @IBOutlet weak var button5: UIButton!
    @IBOutlet weak var button6: UIButton!
    @IBOutlet weak var button7: UIButton!
    @IBOutlet weak var button8: UIButton!
    @IBOutlet weak var button9: UIButton!
    @IBOutlet weak var button0: UIButton!
    @IBOutlet weak var buttonBackSpace: UIButton!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var infoLabelMaxWidth: NSLayoutConstraint!
    @IBOutlet weak var infoLabelVertSpace: NSLayoutConstraint!
    
    private var passcode = String()
    private var passcodeToVerify = String()
    private var wantedAction = AppLockAction.enterPassword  // Action to perform after category selection
    
    func config(password: String = "", forAction action:AppLockAction) {
        wantedAction = action
        switch action {
        case .enterPassword:
            passcode = password
        case .verifyPassword:
            passcodeToVerify = password
        }
    }

    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settingsHeader_privacy", comment: "Privacy")
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = .piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = .piwigoColorBackground()

        if #available(iOS 15.0, *) {
            /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
            /// which by default produces a transparent background, to all navigation bars.
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithOpaqueBackground()
            barAppearance.backgroundColor = .piwigoColorBackground()
            navigationController?.navigationBar.standardAppearance = barAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }
                
        // App Lock title
        titleLabel.textColor = UIColor.piwigoColorText()
        
        // App Lock digits
        updateDigits()

        // App Lock numpad
        button1.setTitleColor(UIColor.piwigoColorRightLabel(), for: .normal)
        button1.backgroundColor = UIColor.piwigoColorCellBackground()
        button2.setTitleColor(UIColor.piwigoColorRightLabel(), for: .normal)
        button2.backgroundColor = UIColor.piwigoColorCellBackground()
        button3.setTitleColor(UIColor.piwigoColorRightLabel(), for: .normal)
        button3.backgroundColor = UIColor.piwigoColorCellBackground()
        button4.setTitleColor(UIColor.piwigoColorRightLabel(), for: .normal)
        button4.backgroundColor = UIColor.piwigoColorCellBackground()
        button5.setTitleColor(UIColor.piwigoColorRightLabel(), for: .normal)
        button5.backgroundColor = UIColor.piwigoColorCellBackground()
        button6.setTitleColor(UIColor.piwigoColorRightLabel(), for: .normal)
        button6.backgroundColor = UIColor.piwigoColorCellBackground()
        button7.setTitleColor(UIColor.piwigoColorRightLabel(), for: .normal)
        button7.backgroundColor = UIColor.piwigoColorCellBackground()
        button8.setTitleColor(UIColor.piwigoColorRightLabel(), for: .normal)
        button8.backgroundColor = UIColor.piwigoColorCellBackground()
        button9.setTitleColor(UIColor.piwigoColorRightLabel(), for: .normal)
        button9.backgroundColor = UIColor.piwigoColorCellBackground()
        button0.setTitleColor(UIColor.piwigoColorRightLabel(), for: .normal)
        button0.backgroundColor = UIColor.piwigoColorCellBackground()

        // App Lock info
        infoLabel.textColor = UIColor.piwigoColorText()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Title and Info labels
        switch wantedAction {
        case .enterPassword:
            titleLabel.text = NSLocalizedString("settings_appLockEnter", comment: "Enter Passcode")
            infoLabel.text = NSLocalizedString("settings_appLockInfo", comment: "With App Lock, ...")
        case .verifyPassword:
            titleLabel.text = NSLocalizedString("settings_appLockVerify", comment: "Verify Passcode")
            infoLabel.text = NSLocalizedString("settings_appLockInfo", comment: "With App Lock, ...")
        }

        // Set constraints, colors, fonts, etc.
        configConstraints()
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Update the constraints on orientation change
        coordinator.animate(alongsideTransition: { _ in
            self.configConstraints()
        })
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }
    
    private func configConstraints() {
        // Get the safe area width and height
        var safeAreaWidth = view.bounds.size.width
        var safeAreaHeight = view.bounds.size.height
        if #available(iOS 11.0, *) {
            if let root = UIApplication.shared.keyWindow?.rootViewController {
                safeAreaWidth -= root.view.safeAreaInsets.left + root.view.safeAreaInsets.right
                safeAreaHeight -= root.view.safeAreaInsets.top + root.view.safeAreaInsets.bottom
            }
        }
        
        // Calculate the required height of the App Lock info
        /// The minimum width of a screen is of 320 pixels.
        /// See https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/adaptivity-and-layout/
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let margin: CGFloat =  15.0, minWidth: CGFloat = 320.0 - 2 * margin
        let maxWidth = CGFloat(fmax(safeAreaWidth - 2.0*margin, minWidth))
        let widthConstraint: CGSize = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
        let attributes = [NSAttributedString.Key.font: infoLabel.font!]
        let height = infoLabel.text?.boundingRect(with: widthConstraint, options: .usesLineFragmentOrigin,
                                                  attributes: attributes, context: context).height ?? CGFloat(60)

        // App Lock numpad spacing
        var spacing = CGFloat.zero
        switch min(safeAreaWidth, safeAreaHeight) {
        case 0...319:
            spacing = 10
        case 320...389:
            spacing = 20
        default:
            spacing = 30
        }
        mainStack.spacing = spacing
        stackRow1.spacing = spacing
        stackRow2.spacing = spacing
        stackRow3.spacing = spacing
        stackRow4.spacing = spacing

        // App Lock vertical spacing
        var orientation = UIInterfaceOrientation.portrait
        if #available(iOS 13.0, *) {
            orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
        } else {
            orientation = UIApplication.shared.statusBarOrientation
        }
        if orientation.isPortrait || UIDevice.current.userInterfaceIdiom == .pad {
            // iPhone in portrait mode
            safeAreaHeight -= 4*60 + 3*spacing
            let availableTopSpace = safeAreaHeight/2 - 24 - 10
            digitStackVertSpace.constant = availableTopSpace / 2
            let availableBotSpace = safeAreaHeight/2 - height
            infoLabelVertSpace.constant = availableBotSpace / 2
            infoLabelMaxWidth.constant = min(safeAreaWidth - 2*20, 300)
        }
        else {
            // iPhone in landscape mode, iPad in any orientation
            infoLabelMaxWidth.constant = min(safeAreaWidth/2 - 2*20, 300)
            let horMidPosition = safeAreaWidth/4
            titleLabelHorSpace.constant = horMidPosition
            mainStackHorSpace.constant = horMidPosition
        }
    }
    
    
    // MARK: - Numpad management
    @IBAction func touchedKey(_ sender: UIButton) {
        if passcode.count == 6 { return }
        guard let buttonTitle = sender.currentTitle else { return }
        if "0123456789".contains(buttonTitle) {
            // Add typed digit to passcode
            passcode.append(buttonTitle)
            // Update digits
            updateDigits()
        }
        
        // Passcode provided?
        if passcode.count == 6 {
            switch wantedAction {
            case .enterPassword:    // Just finshed entering passcode —> verify passcode
                let appLockSB = UIStoryboard(name: "AppLockViewController", bundle: nil)
                guard let appLockVC = appLockSB.instantiateViewController(withIdentifier: "AppLockViewController") as? AppLockViewController else { return }
                appLockVC.config(password: passcode, forAction: .verifyPassword)
                appLockVC.delegate = self.delegate
                navigationController?.pushViewController(appLockVC, animated: true)
                
            case .verifyPassword:   // Passcode re-entered —> match?
                if passcode == passcodeToVerify {
                    // Activate the app lock
                    AppVars.shared.isAppLockActive = true
                    delegate?.didSetAppLock(toState: true)
                    // Return to the Settings view
                    if let settingsVC = navigationController?.children.first {
                        navigationController?.popToViewController(settingsVC, animated: true)
                        return
                    }
                } else {

                }
            }
        }
    }
    
    @IBAction func touchedBackSpace(_ sender: Any) {
        // NOP if no digit
        if passcode.isEmpty { return }
        
        // Remove last digit
        passcode.removeLast()
        // Update digits
        updateDigits()
    }
    
    private func updateDigits() {
        let nberOfDigits = passcode.count
        digit1.backgroundColor = nberOfDigits > 0 ? UIColor.piwigoColorOrange() : UIColor.piwigoColorCellBackground()
        digit2.backgroundColor = nberOfDigits > 1 ? UIColor.piwigoColorOrange() : UIColor.piwigoColorCellBackground()
        digit3.backgroundColor = nberOfDigits > 2 ? UIColor.piwigoColorOrange() : UIColor.piwigoColorCellBackground()
        digit4.backgroundColor = nberOfDigits > 3 ? UIColor.piwigoColorOrange() : UIColor.piwigoColorCellBackground()
        digit5.backgroundColor = nberOfDigits > 4 ? UIColor.piwigoColorOrange() : UIColor.piwigoColorCellBackground()
        digit6.backgroundColor = nberOfDigits > 5 ? UIColor.piwigoColorOrange() : UIColor.piwigoColorCellBackground()
        if nberOfDigits == 0 {
            buttonBackSpace.setTitleColor(UIColor.piwigoColorRightLabel().withAlphaComponent(0.0), for: .normal)
        } else {
            buttonBackSpace.setTitleColor(UIColor.piwigoColorRightLabel(), for: .normal)
        }
    }
}
