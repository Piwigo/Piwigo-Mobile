//
//  LoginViewController+iPad.swift
//  piwigo
//
//  Created by Olaf on 31.03.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.4 by Eddy Lelièvre-Berna on 26/02/2022.
//

extension LoginViewController {

    func setupAutoLayout4iPad() {
        let side = 40
        let textFieldHeight: CGFloat = 64
        let textFieldWidth = 500

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

        // ==> Portrait
        var portrait: [AnyHashable] = []
        var metrics = [
            "side": NSNumber(value: side),
            "width": NSNumber(value: textFieldWidth),
            "logoWidth": NSNumber(value: Float(textFieldHeight * 4.02)),
            "height": NSNumber(value: Float(textFieldHeight))
        ]

        // Vertically
        portrait.append(NSLayoutConstraint.constraintView(fromTop: loginButton, amount: (CGFloat(fmax(Float(UIScreen.main.bounds.size.height), Float(UIScreen.main.bounds.size.width)) / 2.0) + textFieldHeight + 2 * 10.0)))

        portrait.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "V:|-(>=30,<=100)-[logo(height)]-(>=20)-[url(==logo)]-15-[server(==logo)]-15-[user(==logo)]-15-[password(==logo)]-15-[login(==logo)]-15-[notSecure]-(>=30)-[by1][by2]-3-[usu]-20-|",
                options: [],
                metrics: metrics,
                views: views))

        // Horizontally
        portrait.append(NSLayoutConstraint.constraintCenterVerticalView(piwigoLogo))
        portrait.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[logo(logoWidth)]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        portrait.append(NSLayoutConstraint.constraintCenterVerticalView(piwigoButton))
        portrait.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[url(width)]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        portrait.append(NSLayoutConstraint.constraintCenterVerticalView(serverTextField))
        portrait.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[server(width)]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        portrait.append(NSLayoutConstraint.constraintCenterVerticalView(userTextField))
        portrait.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[user(width)]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        portrait.append(NSLayoutConstraint.constraintCenterVerticalView(passwordTextField))
        portrait.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[password(width)]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        portrait.append(NSLayoutConstraint.constraintCenterVerticalView(loginButton))
        portrait.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[login(width)]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        portrait.append(NSLayoutConstraint.constraintCenterVerticalView(websiteNotSecure))
        portrait.append(NSLayoutConstraint.constraintCenterVerticalView(byLabel1))
        portrait.append(NSLayoutConstraint.constraintCenterVerticalView(byLabel2))
        portrait.append(NSLayoutConstraint.constraintCenterVerticalView(versionLabel))

        portraitConstraints = portrait


        // ==> Landscape
        let logoHeight = textFieldHeight + 36.0
        let logoWidth = CGFloat(floorf(Float(logoHeight * 4.02)))
        let landscapeSide = CGFloat(floorf(Float(CGFloat(fmax(Float(UIScreen.main.bounds.size.width), Float(UIScreen.main.bounds.size.height))) - logoWidth - CGFloat(side) - CGFloat(textFieldWidth))) / 2.0)
        metrics = [
            "side": NSNumber(value: Float(landscapeSide)),
            "gap": NSNumber(value: side),
            "width": NSNumber(value: textFieldWidth),
            "logoWidth": NSNumber(value: Float(logoWidth)),
            "logoHeight": NSNumber(value: Float(logoHeight)),
            "height": NSNumber(value: Float(textFieldHeight))
        ]

        var landscape: [AnyHashable] = []

        // Vertically
        landscape.append(NSLayoutConstraint.constraintView(fromTop: loginButton, amount: (CGFloat(fmin(Float(UIScreen.main.bounds.size.height), Float(UIScreen.main.bounds.size.width)) / 2.0) + textFieldHeight + 2 * 10.0)))

        landscape.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "V:[server(height)]-15-[user(height)]-15-[password(height)]-15-[login(height)]-15-[notSecure]",
                options: [],
                metrics: metrics,
                views: views))

        landscape.append(NSLayoutConstraint.constraintView(piwigoLogo, toHeight: logoHeight))
        landscape.append(NSLayoutConstraint.constraintView(piwigoLogo, toWidth: logoWidth))

        if let byLabel1 = byLabel1 {
            landscape.append(
                NSLayoutConstraint(
                    item: byLabel1,
                    attribute: .top,
                    relatedBy: .equal,
                    toItem: loginButton,
                    attribute: .top,
                    multiplier: 1.0,
                    constant: 0))
        }

        landscape.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "V:[by1][by2]-3-[usu]",
                options: [],
                metrics: metrics,
                views: views))

        // Horizontally
        landscape.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[logo]-gap-[server(width)]-(>=side)-|",
                options: .alignAllTop,
                metrics: metrics,
                views: views))

        landscape.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[logo]-gap-[user(==server)]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        landscape.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[logo]-gap-[password(==server)]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        landscape.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[logo]-gap-[login(==server)]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        landscape.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[logo]-gap-[notSecure(==server)]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        landscape.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[url(==logo)]-gap-[user]-(>=side)-|",
                options: .alignAllBottom,
                metrics: metrics,
                views: views))

        landscape.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[by1]-gap-[login]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        landscape.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[by2]-gap-[login]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        landscape.append(
            contentsOf: NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-(>=side)-[usu]-gap-[login]-(>=side)-|",
                options: [],
                metrics: metrics,
                views: views))

        landscapeConstraints = landscape
    }

    override func updateViewConstraints() {
        // Only for iPad
        if UIDevice.current.userInterfaceIdiom == .phone {
            super.updateViewConstraints()
            return
        }
        
        // Update constraints on iPad
        if let portraitConstraints = portraitConstraints as? [NSLayoutConstraint] {
            view.removeConstraints(portraitConstraints)
        }
        if let landscapeConstraints = landscapeConstraints as? [NSLayoutConstraint] {
            view.removeConstraints(landscapeConstraints)
        }
        if UIApplication.shared.statusBarOrientation.isLandscape {
            if let landscapeConstraints = landscapeConstraints as? [NSLayoutConstraint] {
                view.addConstraints(landscapeConstraints)
            }
        } else {
            if let portraitConstraints = portraitConstraints as? [NSLayoutConstraint] {
                view.addConstraints(portraitConstraints)
            }
        }
        super.updateViewConstraints()
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        // Only for iPad
        if UIDevice.current.userInterfaceIdiom == .phone {
            super.viewWillTransition(to: size, with: coordinator)
            return
        }

        // Update constraints on iPad
        coordinator.animate(alongsideTransition: { [self] context in
            if let portraitConstraints = portraitConstraints as? [NSLayoutConstraint] {
                view.removeConstraints(portraitConstraints)
            }
            if let landscapeConstraints = landscapeConstraints as? [NSLayoutConstraint] {
                view.removeConstraints(landscapeConstraints)
            }
            if UIApplication.shared.statusBarOrientation.isLandscape {
                if let landscapeConstraints = landscapeConstraints as? [NSLayoutConstraint] {
                    view.addConstraints(landscapeConstraints)
                }
            } else {
                if let portraitConstraints = portraitConstraints as? [NSLayoutConstraint] {
                    view.addConstraints(portraitConstraints)
                }
            }
        })
    }
}
