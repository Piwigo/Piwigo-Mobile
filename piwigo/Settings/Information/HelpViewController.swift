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

    var pages = [UIViewController]()
    var pageCount: Int = 3                    // Change this number after addding/removing pages
    var pageViewController: UIPageViewController?
    var pendingIndex: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialise pageControl
        pageControl.numberOfPages = pageCount

        // Initialise all pages
        for i in 0 ..< pageCount {
            // Loop over the storyboards
            let pageID = String(format: "help%02ld", i+1)
            if let page = storyboard?.instantiateViewController(withIdentifier: pageID) {
                pages.append(page)
            }
        }

        // Initialise pageViewController
        pageViewController = self.children[0] as? UIPageViewController
        pageViewController!.delegate = self
        pageViewController!.dataSource = self
        
        // Display first page
        pageViewController!.setViewControllers([pages[0]], direction: .forward, animated: true, completion: nil)
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
            }
        }
    }
}
