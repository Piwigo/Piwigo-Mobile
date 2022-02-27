//
//  LoginViewController+iPhone.swift
//  piwigo
//
//  Created by Olaf on 31.03.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.4 by Eddy Lelièvre-Berna on 26/02/2022.
//

extension LoginViewController {

    func setupAutoLayout4iPhone() {
        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
        // Always display login view in portrait mode
        let screenWidth = Int(min(UIScreen.main.bounds.size.height, UIScreen.main.bounds.size.width))
        let screenHeight = Int(max(UIScreen.main.bounds.size.height, UIScreen.main.bounds.size.width))
        let textFieldHeight = CGFloat(48 + 8 * ((screenHeight - 480) / (812 - 480)))
        let margin = 36

        var views = [String : Any]()
        if let piwigoLogo = piwigoLogo, let piwigoButton = piwigoButton, let serverTextField = serverTextField, let userTextField = userTextField, let passwordTextField = passwordTextField, let loginButton = loginButton, let websiteNotSecure = websiteNotSecure, let byLabel1 = byLabel1, let byLabel2 = byLabel2, let versionLabel = versionLabel {
            views = [
                "logo": piwigoLogo,
                "url": piwigoButton,
                "server": serverTextField,
                "user": userTextField,
                "password": passwordTextField,
                "login": loginButton,
                "notSecure": websiteNotSecure,
                "by1": byLabel1,
                "by2": byLabel2,
                "usu": versionLabel
            ]
        }

        let logoWidth = textFieldHeight * 4.02
        let logoSide = CGFloat(floorf(Float(CGFloat(screenWidth) - logoWidth)) / 2.0)
        let metrics = [
            "height": NSNumber(value: Float(textFieldHeight)),
            "logoWidth": NSNumber(value: Float(logoWidth)),
            "logoSide": NSNumber(value: Float(logoSide)),
            "side": NSNumber(value: margin)
        ]

        // Vertically
        view.addConstraint(NSLayoutConstraint.constraintView(fromTop: loginButton, amount: (Double(screenHeight) / 2.0 + textFieldHeight + 2 * 10.0))!)

        if screenHeight > 600 {
            view.addConstraints(
                NSLayoutConstraint.constraints(
                    withVisualFormat: "V:|-(>=50,<=100)-[logo(height)]-(>=20)-[url(==logo)]-10-[server(==logo)]-10-[user(==logo)]-10-[password(==logo)]-10-[login(==logo)]-10-[notSecure]-(>=30)-[by1][by2]-3-[usu]-20-|",
                    options: [],
                    metrics: metrics,
                    views: views))
        } else {
            view.addConstraints(
                NSLayoutConstraint.constraints(
                    withVisualFormat: "V:|-(>=30,<=50)-[logo(height)]-(>=20)-[url(==logo)]-10-[server(==logo)]-10-[user(==logo)]-10-[password(==logo)]-10-[login(==logo)]-10-[notSecure]-(>=30)-[by1][by2]-3-[usu]-20-|",
                    options: [],
                    metrics: metrics,
                    views: views))
        }

        // Piwigo logo
        view.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(piwigoLogo)!)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(>=logoSide)-[logo(logoWidth)]-(>=logoSide)-|", options: [], metrics: metrics, views: views))

        // URL button
        view.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(piwigoButton)!)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-side-[url]-side-|", options: [], metrics: metrics, views: views))

        // Server
        view.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(serverTextField)!)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-side-[server]-side-|", options: [], metrics: metrics, views: views))

        // Username
        view.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(userTextField)!)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-side-[user]-side-|", options: [], metrics: metrics, views: views))

        // Password
        view.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(passwordTextField)!)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-side-[password]-side-|", options: [], metrics: metrics, views: views))

        // Login button
        view.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(loginButton)!)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-side-[login]-side-|", options: [], metrics: metrics, views: views))

        // Information
        view.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(websiteNotSecure)!)
        view.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(byLabel1)!)
        view.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(byLabel2)!)
        view.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(versionLabel)!)
    }
}
