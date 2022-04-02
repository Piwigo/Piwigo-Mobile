//
//  AppLockViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit
import UIKit

enum AppLockAction {
    case enterPasscode
    case verifyPasscode
    case modifyPasscode
    case unlockApp
}

class AppLockViewController: UIViewController {

    @IBOutlet weak var blurEffectView: UIVisualEffectView!
    @IBOutlet weak var vibrancyEffectView: UIVisualEffectView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var titleLabelHorOffset: NSLayoutConstraint!
    @IBOutlet weak var titleLabelVertOffset: NSLayoutConstraint!
    @IBOutlet weak var digitStack: UIStackView!
    @IBOutlet weak var digit1: UIButton!
    @IBOutlet weak var digit2: UIButton!
    @IBOutlet weak var digit3: UIButton!
    @IBOutlet weak var digit4: UIButton!
    @IBOutlet weak var digit5: UIButton!
    @IBOutlet weak var digit6: UIButton!
    @IBOutlet weak var mainStack: UIStackView!
    @IBOutlet weak var mainStackHorOffset: NSLayoutConstraint!
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
    @IBOutlet weak var button0width: NSLayoutConstraint!
    @IBOutlet weak var buttonBackSpace: UIButton!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var infoLabelMaxWidth: NSLayoutConstraint!
    @IBOutlet weak var infoLabelVertOffset: NSLayoutConstraint!
    
    private var passcode = String()
    private var passcodeToVerify = String()
    private var wantedAction = AppLockAction.enterPasscode
    
    func config(password: String = "", forAction action:AppLockAction) {
        wantedAction = action
        switch action {
        case .enterPasscode, .modifyPasscode:
            passcode = ""
        case .verifyPasscode:
            passcodeToVerify = password
        case .unlockApp:
            passcodeToVerify = AppVars.shared.appLockKey.decrypted()
        }
    }

    private var _diameter: CGFloat = 60.0
    var diameter: CGFloat {
        get {
            return _diameter
        }
        set(value){
            _diameter = value
            
            // Stack spaces
            let spacing = value / 5
            mainStack.spacing = spacing
            stackRow1.spacing = spacing
            stackRow2.spacing = spacing
            stackRow3.spacing = spacing
            stackRow4.spacing = spacing
            
            // Buttons
            let radius = value / 2
            button0.layer.cornerRadius = radius
            button1.layer.cornerRadius = radius
            button2.layer.cornerRadius = radius
            button3.layer.cornerRadius = radius
            button4.layer.cornerRadius = radius
            button5.layer.cornerRadius = radius
            button6.layer.cornerRadius = radius
            button7.layer.cornerRadius = radius
            button8.layer.cornerRadius = radius
            button9.layer.cornerRadius = radius
            buttonBackSpace.layer.cornerRadius = radius

            // Set buttons size and distribution
            button0width.constant = diameter
        }
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settingsHeader_privacy", comment: "Privacy")
    }

    @objc func applyColorPalette() {
        // Navigation bar (if any)
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
                
        // Initialise colours
        var labelsColor = UIColor.piwigoColorText()
        var digitBorderColor = UIColor.clear.cgColor
        var buttonTitleColor = UIColor.piwigoColorRightLabel()
        var buttonBckgColor = UIColor.piwigoColorCellBackground()
        var buttonBorderColor = UIColor.clear.cgColor
        if wantedAction == .unlockApp {
            if UIAccessibility.isReduceTransparencyEnabled {
                // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is enabled
                /// —> No blur effect, fixed colour background
                view.backgroundColor = UIColor.piwigoColorBrown()
                blurEffectView.effect = .none
                vibrancyEffectView.effect = .none
                labelsColor = .white
                buttonBckgColor = .clear
                buttonTitleColor = .init(white: 0.8, alpha: 1.0)
                buttonBorderColor = buttonTitleColor.cgColor
            }
            else {
                // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is disabled
                /// —> Blur and vibrancy effects
                view.backgroundColor = .clear
                var blurEffect = UIBlurEffect(style: .dark)
                if AppVars.shared.isDarkPaletteActive {
                    blurEffect = UIBlurEffect(style: .light)
                }
                blurEffectView.effect = blurEffect
                vibrancyEffectView.effect = UIVibrancyEffect(blurEffect: blurEffect)
                labelsColor = .white
                buttonBckgColor = .clear
                buttonTitleColor = UIColor.piwigoColorNumkey()
                buttonBorderColor = buttonTitleColor.cgColor
                digitBorderColor = buttonTitleColor.cgColor
            }
        } else {    // Enter or Verify passcode
            view.backgroundColor = .piwigoColorBackground()
            blurEffectView.effect = .none
            vibrancyEffectView.effect = .none
        }

        // Background, title and info
        titleLabel.textColor = labelsColor
        titleLabel.tintColor = labelsColor
        infoLabel.textColor = labelsColor
        infoLabel.tintColor = labelsColor

        // App Lock digits
        digit1.layer.borderColor = digitBorderColor
        digit2.layer.borderColor = digitBorderColor
        digit3.layer.borderColor = digitBorderColor
        digit4.layer.borderColor = digitBorderColor
        digit5.layer.borderColor = digitBorderColor
        digit6.layer.borderColor = digitBorderColor
        updateDigits()

        button0.layer.borderColor = buttonBorderColor
        button0.backgroundColor = buttonBckgColor
        button0.setTitleColor(buttonTitleColor, for: .normal)

        button1.layer.borderColor = buttonBorderColor
        button1.setTitleColor(buttonTitleColor, for: .normal)
        button1.backgroundColor = buttonBckgColor

        button2.layer.borderColor = buttonBorderColor
        button2.backgroundColor = buttonBckgColor
        button2.setTitleColor(buttonTitleColor, for: .normal)

        button3.layer.borderColor = buttonBorderColor
        button3.backgroundColor = buttonBckgColor
        button3.setTitleColor(buttonTitleColor, for: .normal)

        button4.layer.borderColor = buttonBorderColor
        button4.backgroundColor = buttonBckgColor
        button4.setTitleColor(buttonTitleColor, for: .normal)

        button5.layer.borderColor = buttonBorderColor
        button5.backgroundColor = buttonBckgColor
        button5.setTitleColor(buttonTitleColor, for: .normal)

        button6.layer.borderColor = buttonBorderColor
        button6.backgroundColor = buttonBckgColor
        button6.setTitleColor(buttonTitleColor, for: .normal)

        button7.layer.borderColor = buttonBorderColor
        button7.backgroundColor = buttonBckgColor
        button7.setTitleColor(buttonTitleColor, for: .normal)

        button8.layer.borderColor = buttonBorderColor
        button8.backgroundColor = buttonBckgColor
        button8.setTitleColor(buttonTitleColor, for: .normal)

        button9.layer.borderColor = buttonBorderColor
        button9.backgroundColor = buttonBckgColor
        button9.setTitleColor(buttonTitleColor, for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Title and Info labels
        switch wantedAction {
        case .enterPasscode, .unlockApp:
            titleLabel.text = NSLocalizedString("settings_appLockEnter", comment: "Enter Passcode")
        case .verifyPasscode:
            titleLabel.text = NSLocalizedString("settings_appLockVerify", comment: "Verify Passcode")
        case .modifyPasscode:
            titleLabel.text = NSLocalizedString("settings_appLockModify", comment: "Modify Passcode")
        }
        infoLabel.text = NSLocalizedString("settings_appLockInfo", comment: "With App Lock, ...")

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
        if let nav = navigationController {
            // Remove the height of the navigation bar
            safeAreaHeight -= nav.navigationBar.bounds.height
        }

        // Get device orientation
        var orientation = UIInterfaceOrientation.portrait
        if #available(iOS 13.0, *) {
            orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
        } else {
            orientation = UIApplication.shared.statusBarOrientation
        }

        // Initialise constants
        let margin: CGFloat =  16
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let attributes = [NSAttributedString.Key.font: infoLabel.font!]

        // Constraints depend on orientation
        if orientation.isPortrait || UIDevice.current.userInterfaceIdiom == .pad {
            // iPhone in portrait mode ▸ All centered horizontally
            titleLabelHorOffset.constant = CGFloat.zero
            mainStackHorOffset.constant = CGFloat.zero
            
            // Calculate the required height of the App Lock info
            /// The minimum width of a screen is of 320 points.
            /// See https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/adaptivity-and-layout/
            let maxWidth: CGFloat = min(safeAreaWidth, 320) - 2*margin
            let widthConstraint: CGSize = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
            let height = infoLabel.text?.boundingRect(with: widthConstraint, options: .usesLineFragmentOrigin,
                                                      attributes: attributes, context: context).height ?? CGFloat(60)

            // Calculate diameter of buttons and update UI elements
            /// See AppLockViewController.nb file
            let dWidth: CGFloat = 5 * (safeAreaWidth - 2*margin)/17
            let dHeight: CGFloat = 5 * (safeAreaHeight - 23.5 - 16 - 10 - height - 4*margin)/23
            diameter = min(min(dWidth, dHeight), 80)

            // Set vertical constraints
            let mainStackHeight: CGFloat = 23*diameter/5
            safeAreaHeight -= mainStackHeight
            let topElementsHeight: CGFloat = 24+10+16
            titleLabelVertOffset.constant = (safeAreaHeight/2 - topElementsHeight)/2
            infoLabelMaxWidth.constant = maxWidth
            infoLabelVertOffset.constant = (safeAreaHeight/2 - height) / 2
        }
        else {
            // iPhone in landscape mode ▸ Labels and numpad side by side
            let horOffset = min(safeAreaWidth/4.0, 300.0)
            if orientation == .landscapeLeft {
                titleLabelHorOffset.constant = horOffset
                mainStackHorOffset.constant = horOffset
            } else {
                titleLabelHorOffset.constant = -horOffset
                mainStackHorOffset.constant = -horOffset
            }

            // Calculate diameter of buttons and update UI elements
            /// See AppLockViewController.nb file
            let dWidth: CGFloat = 5 * (safeAreaWidth - 4*margin)/34
            let dHeight: CGFloat = 5 * (safeAreaHeight - 2*margin)/23
            diameter = min(min(dWidth, dHeight), 80)

            // Fix size and vertical positions of labels
            titleLabelVertOffset.constant = safeAreaHeight/2 - CGFloat(100)
            let maxWidth: CGFloat = min(safeAreaWidth/2, 320) - 2*margin
            infoLabelMaxWidth.constant = maxWidth
            infoLabelVertOffset.constant = safeAreaHeight/2 - CGFloat(100)
        }
    }
    
    
    // MARK: - Numpad management
    @IBAction func touchDown(_ sender: UIButton) {
        // Apply darker backgroud colour while pressing key (reveals the glowing number).
        if wantedAction != .unlockApp {
            sender.backgroundColor = UIColor.piwigoColorRightLabel()
        }
    }

    @IBAction func touchUpInside(_ sender: UIButton) {
        // Re-apply normal background colour when the key is released
        if wantedAction != .unlockApp {
            sender.backgroundColor = UIColor.piwigoColorCellBackground()
        }

        // No more than 6 digits
        if passcode.count == 6 { return }
        
        // Retrieve pressed key
        guard let buttonTitle = sender.currentTitle else { return }
        if "0123456789".contains(buttonTitle) == false { return }

        // Add typed digit to passcode
        passcode.append(buttonTitle)
        // Update digits
        updateDigits()
        
        // Passcode complete?
        if passcode.count < 6 { return }
        
        // Manage provided passcode
        switch wantedAction {
        case .enterPasscode, .modifyPasscode:    // Just finshed entering passcode —> verify passcode
            let appLockSB = UIStoryboard(name: "AppLockViewController", bundle: nil)
            guard let appLockVC = appLockSB.instantiateViewController(withIdentifier: "AppLockViewController") as? AppLockViewController else { return }
            appLockVC.config(password: passcode, forAction: .verifyPasscode)
            navigationController?.pushViewController(appLockVC, animated: true)
            
        case .verifyPasscode:   // Passcode re-entered
            // Do passcodes match?
            if passcode != passcodeToVerify {
                // Passcode not verified!
                shakeDigitRow()
                return
            }
            
            // Store passcode
            AppVars.shared.appLockKey = passcode.encrypted()
            
            // Return to the Settings view
            if let settingsVC = navigationController?.children.first {
                navigationController?.popToViewController(settingsVC, animated: true)
                return
            } else {
                // Return to the root album
                self.dismiss(animated: true)
            }
            
        case .unlockApp:
            // Do passcodes match?
            if passcode != passcodeToVerify {
                // Passcode not verified!
                shakeDigitRow()
                return
            }
            
            // Unlock the app
            if #available(iOS 13.0, *) {
                let sceneDelegate = UIApplication.shared.connectedScenes
                    .filter({$0.activationState == .foregroundActive}).first?.delegate as? SceneDelegate
                sceneDelegate?.unlockAppAndResume()
            } else {
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.unlockAppAndResume()
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
        
        // Digit background colour
        var digitKnownColor = UIColor.piwigoColorOrange()
        var digitUnknowColor = UIColor.piwigoColorCellBackground()
        if wantedAction == .unlockApp {
            if UIAccessibility.isReduceTransparencyEnabled {
                // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is enabled
                digitUnknowColor = .init(white: 0.8, alpha: 1.0)
            } else {
                // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is disabled
                digitKnownColor = UIColor.piwigoColorNumkey()
                digitUnknowColor = .clear
            }
        }
        digit1.backgroundColor = nberOfDigits > 0 ? digitKnownColor : digitUnknowColor
        digit2.backgroundColor = nberOfDigits > 1 ? digitKnownColor : digitUnknowColor
        digit3.backgroundColor = nberOfDigits > 2 ? digitKnownColor : digitUnknowColor
        digit4.backgroundColor = nberOfDigits > 3 ? digitKnownColor : digitUnknowColor
        digit5.backgroundColor = nberOfDigits > 4 ? digitKnownColor : digitUnknowColor
        digit6.backgroundColor = nberOfDigits > 5 ? digitKnownColor : digitUnknowColor
        
        // Back space title colour
        if nberOfDigits == 0 {
            buttonBackSpace.setTitleColor(.clear, for: .normal)
        } else {
            var digitTitleColor = UIColor.piwigoColorRightLabel()
            if wantedAction == .unlockApp, !UIAccessibility.isReduceTransparencyEnabled {
                // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is disabled
                digitTitleColor = UIColor.piwigoColorNumkey()
            }
            buttonBackSpace.setTitleColor(digitTitleColor, for: .normal)
        }
    }
    
    private func shakeDigitRow() {
        // Move digits to the left and right several times
        self.digitStack.shakeHorizontally {
            // Re-verify passcode
            self.passcode = ""
            UIView.animate(withDuration: 1) {
                self.updateDigits()
            }
        }
        
        // If the device supports Core Haptics, exploit them.
        if #available(iOS 13.0, *) {
            HapticUtilities.shared.playHapticsFile(named: "VerificationFailed")
        }
    }
}
