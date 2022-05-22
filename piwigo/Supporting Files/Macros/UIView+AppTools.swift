//
//  UIView+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    
    // MARK: - Shake UIView
    func shakeHorizontally(completion: @escaping () -> Void) {
        // Move digits to the left and right several times
        UIView.animate(withDuration: 0.1, delay: 0, options:[.curveLinear], animations: {
            self.transform = CGAffineTransform(translationX: 50, y: 0)
        }, completion: { _ in
            UIView.animate(withDuration: 0.15, delay: 0, options:[.curveLinear], animations: {
                self.transform = CGAffineTransform(translationX: -50, y: 0)
            }, completion: { _ in
                UIView.animate(withDuration: 0.15, delay: 0, options:[.curveLinear], animations: {
                    self.transform = CGAffineTransform(translationX: 40, y: 0)
                }, completion: { _ in
                    UIView.animate(withDuration: 0.15, delay: 0, options:[.curveLinear], animations: {
                        self.transform = CGAffineTransform(translationX: -40, y: 0)
                    }, completion: { _ in
                        UIView.animate(withDuration: 0.15, delay: 0, options:[.curveLinear], animations: {
                            self.transform = CGAffineTransform(translationX: 30, y: 0)
                        }, completion: { _ in
                            UIView.animate(withDuration: 0.1, delay: 0, options:[.curveEaseOut], animations: {
                                self.transform = CGAffineTransform(translationX: 0, y: 0)
                            }, completion: {_ in
                                completion()
                            })
                        })
                    })
                })
            })
        })
    }
}
