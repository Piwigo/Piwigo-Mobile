//
//  HelpViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/11/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

class HelpViewController: UIViewController {
    
    @IBOutlet weak var container: UIView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var closeButton: UIButton!
    
    @objc var onlyWhatsNew = false
    private var pages = [UIViewController]()
    private var pageCount: Int = 3    // Update this value after deleting/creating Help##ViewControllers
    private var pageViewController: UIPageViewController?
    private var pendingIndex: Int?
    private var pageDisplayed: Int = 0

    /// Page view sizes of:
    ///     375 x 667 pixels on iPhone SE (2nd generation)
    ///     1024 x 1366 pixels on iPad 12.9" (4th generation)
    /// => adopt images of:
    ///     1020 max width i.e. 340 @1x, 680 @ 2x and 1020 @3x
    ///     1365 max height i.e. 455 @1x, 910 @2x and 1365 @3x

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialise all pages
        let didWatchHelpViews = Model.sharedInstance()?.didWatchHelpViews ?? 0
        for i in 0 ..< pageCount {
            // Loop over the storyboards
            let pageIDstr = String(format: "help%02ld", i+1)
            let pageID: UInt16 = UInt16(pow(2.0, Float(i)))
            let alreadyDidWatchPageID: Bool = (didWatchHelpViews & pageID) != 0
            let shouldShowPageID = onlyWhatsNew ? !alreadyDidWatchPageID : true
            if shouldShowPageID,
               let page = storyboard?.instantiateViewController(withIdentifier: pageIDstr) {
                pages.append(page)
            }
        }
        
        // Quit if  there is nothing to present
        if pages.count == 0 { return }

        // Initialise pageControl
        pageControl.currentPage = 0
        pageControl.numberOfPages = pages.count
        pageControl.hidesForSinglePage = true

        // Initialise pageViewController
        pageViewController = self.children[0] as? UIPageViewController
        pageViewController!.delegate = self
        pageViewController!.dataSource = self
        if #available(iOS 14.0, *) {
            pageControl.allowsContinuousInteraction = true
        }
        
        // Display first page
        pageDisplayed = 0
        pageViewController!.setViewControllers([pages[0]], direction: .forward, animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()
    }

    @IBAction func didSelectPage(_ sender: UIPageControl) {
        let page = sender.currentPage
        
        // Direction depends on requested page
        if page > pageDisplayed {
            pageViewController?.setViewControllers([pages[page]], direction: .forward, animated: true, completion: nil)
        } else if page < pageDisplayed{
            pageViewController?.setViewControllers([pages[page]], direction: .reverse, animated: true, completion: nil)
        }
        
        // Update displayed page
        pageDisplayed = page
    }
    
    @IBAction func dismissHelp(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension HelpViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let currentIndex = pages.firstIndex(of: viewController)!
        if currentIndex == pages.count - 1 {
            return nil
        }
        let nextIndex = abs((currentIndex + 1) % pages.count)
        return pages[nextIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        let currentIndex = pages.firstIndex(of: viewController)!
        if currentIndex == 0 {
            return nil
        }
        let previousIndex = abs((currentIndex - 1) % pages.count)
        return pages[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        pendingIndex = pages.firstIndex(of: pendingViewControllers.first!)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            if let pendingIndex = pendingIndex {
                pageControl.currentPage = pendingIndex
                pageDisplayed = pendingIndex
            }
        }
    }
}
