//
//  piwigoScreenshots.swift
//  piwigoScreenshots
//
//  Created by Eddy Lelièvre-Berna on 25/08/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

import XCTest

class piwigoScreenshots: XCTestCase {
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
        
        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        XCUIDevice.shared.orientation = UIDeviceOrientation.portrait
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: - Prepare Screenshots
    @MainActor
    func testScreenshots() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let app = XCUIApplication()
        let deviceType = UIDevice().modelName
        sleep(3);
        
        // MARK: Screenshot #1
        // Swipe left to reveal album actions when displaying albums with description
        //        var index = 1
        //        if deviceType.hasPrefix("iPad") {
        //            index = 7
        //        }
        //        let collectionCell = app.collectionViews.children(matching: .cell).element(boundBy: index)
        //        let tableQuery = collectionCell.children(matching: .other).element.tables.element(boundBy: 0)
        //        sleep(4);
        //        tableQuery.swipeLeft()
        //        snapshot("Image01")
        
        // Open Discover menu when not displaying albums with description
        if ["iPhone SE (1st generation)", "iPhone SE (3rd generation)"].contains(deviceType) == false {
            app.navigationBars["AlbumImagesNav"].buttons["discover"].tap()
            sleep(2);
            snapshot("Image01")
            app.collectionViews.buttons["Tagged"].tap()
            sleep(2)
            if deviceType.contains("iPhone") {
                app.navigationBars["piwigo.TagSelectorView"].buttons["cancelButton"].tap()
            } else {
                app.collectionViews.children(matching: .cell).element(boundBy: 0).tap()
                sleep(1)                        // Leave time for animation
            }
        } else {
            snapshot("Image01")
        }
        
        // MARK: Screenshot #2
        // Image collection with album at top
        app.collectionViews.children(matching: .cell).element(boundBy: 2).tap()
        sleep(2);
        var swipeCount = 0
        if deviceType.hasPrefix("iPhone") {
            // With album description
            //            app.collectionViews.children(matching: .cell).element(boundBy: 2).swipeUp()
            //            sleep(2);
            
            // Without album description
            switch deviceType {
            case "iPhone SE (1st generation)":                          // 4-inch
                swipeCount = 2
            case "iPhone SE (3rd generation)":                          // 4.7-inch
                swipeCount = 2
            case "iPhone 8 Plus":                                       // 5.5-inch
                swipeCount = 2
            case "iPhone 16e":                                          // 6.1-inch
                swipeCount = 2
            case "iPhone 16 Pro":                                       // 6.3-inch
                swipeCount = 2
            case "iPhone 14 Plus":                                      // 6.5-inch
                swipeCount = 2
            case "iPhone 16 Pro Max":                                   // 6.7-inch
                swipeCount = 2
            default:
                swipeCount = 0
                break
            }
        }
        for _ in 0..<swipeCount {
            app.collectionViews.firstMatch.swipeUp(velocity: 200)
            sleep(1)
        }
        snapshot("Image02")
        
        // MARK: Screenshot #3
        // Fullscreen Image with Action menu
        // https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
        app.collectionViews.cells["Clos de Vougeot"].tap()
        sleep(3)
        var image = app.scrollViews.scrollViews.images.firstMatch
        if #available(iOS 18.0, *) {
            image = app.scrollViews.scrollViews.images.firstMatch
        } else {
            image = app.scrollViews.images.firstMatch
        }
        switch deviceType {
        case "iPhone SE (1st generation)":                          // 4-inch
            image.pinch(withScale: 1.1, velocity: 2.0)
            sleep(1)
            image.tap()
        case "iPhone SE (3rd generation)":                          // 4.7-inch
            image.pinch(withScale: 1.6, velocity: 2.0)
            sleep(1)
            image.tap()
        case "iPhone 8 Plus":                                       // 5.5-inch
            image.pinch(withScale: 1.18, velocity: 2.0)
            sleep(1)
            image.tap()
        case "iPhone 16e":                                          // 6.1-inch
            image.pinch(withScale: 1.69, velocity: 1)
            sleep(1)
            image.tap()
        case "iPhone 13 Pro":                                       // Wiki
            image.pinch(withScale: 1.69, velocity: 2.0)
            sleep(1)
            image.tap()
        case "iPhone 16 Pro":                                       // 6.3-inch
            image.pinch(withScale: 1.69, velocity: 2.0)
            sleep(1)
            image.tap()
        case "iPhone 14 Plus":                                      // 6.5-inch
            image.pinch(withScale: 1.75, velocity: 2.0)
            sleep(1)
            image.tap()
        case "iPhone 16 Pro Max":                                   // 6.7-inch
            image.pinch(withScale: 1.75, velocity: 2.0)
            sleep(1)
            image.tap()
        case "iPad Pro 9.7-inch (Wi-Fi + Cellular)":                // 9.7-inch
            break
        case "iPad Pro 10.5 inch (Wi-Fi)":                          // 10.5-inch
            break
        case "iPad Pro 11-inch (M4) (Wi-Fi + Cellular)":            // 11-inch
            image.pinch(withScale: 1.15, velocity: 2.0)
            sleep(1)
            image.tap()
        case "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)":         // 12.9-inch
            break
        case "iPad Pro 13-inch (M4) (Wi-Fi + Cellular)":            // 13-inch
            break
        default:
            break
        }
        sleep(2)                        // Leave time for animation
        app.buttons["actions"].tap()
        snapshot("Image03")
        
        // Dismiss "Action" menu
        app.collectionViews.buttons["Edit Parameters"].tap()
        sleep(1)                        // Leave time for animation
        app.buttons["Cancel"].tap()
        sleep(1)                        // Leave time for animation
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)                        // Leave time for animation

        // MARK: Screenshot #5
        // Modify Parameters view with Action menu
        app.collectionViews.cells["Hotel de Coimbra"].tap()
        sleep(2)
        if #available(iOS 18.0, *) {
            image = app.scrollViews.scrollViews.images.firstMatch
        } else {
            image = app.scrollViews.images.firstMatch
        }
        switch deviceType {
        case "iPad Pro 9.7-inch (Wi-Fi + Cellular)":                // 9.7-inch
            break
        case "iPad Pro 10.5 inch (Wi-Fi)":                          // 10.5-inch
            break
        case "iPad Pro 11-inch (M4) (Wi-Fi + Cellular)":            // 11-inch
            image.pinch(withScale: 1.15, velocity: 2.0)
            sleep(1)
            image.tap()
        case "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)":         // 12.9-inch
            break
        case "iPad Pro 13-inch (M4) (Wi-Fi + Cellular)":            // 13-inch
            break
        default:
            break
        }
        sleep(1)                        // Leave time for animation
        app.buttons["actions"].tap()
        app.collectionViews.buttons["Edit Parameters"].tap()
        sleep(2)                        // Leave time for animation
        snapshot("Image05")

        // Dismiss "Properties" view
        app.buttons["Cancel"].tap()
        sleep(2)                        // Leave time for animation
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)                        // Leave time for animation

        // Scroll quickly to the bottom
        switch deviceType {
        case "iPhone SE (1st generation)":                          // 4-inch
            swipeCount = 4
        case "iPhone SE (3rd generation)":                          // 4.7-inch
            swipeCount = 5
        case "iPhone 8 Plus",                                       // 5.5-inch
             "iPhone 16e",                                          // 6.1-inch
             "iPhone 16 Pro",                                       // 6.1-inch
             "iPhone 14 Plus",                                      // 6.5-inch
             "iPhone 16 Pro Max":                                   // 6.7-inch
            swipeCount = 5
        case "iPad Pro 9.7-inch (Wi-Fi + Cellular)":                // 9.7-inch
            swipeCount = 4
        case "iPad Pro 10.5 inch (Wi-Fi)":                          // 10.5-inch
            swipeCount = 5
        case "iPad Pro 11-inch (M4) (Wi-Fi + Cellular)":            // 11-inch
            swipeCount = 5
        case "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)":         // 12.9-inch
            swipeCount = 5
        case "iPad Pro 13-inch (M4) (Wi-Fi + Cellular)":            // 13-inch
            swipeCount = 5
        default:
            break
        }
        for _ in 0..<swipeCount {
            app.collectionViews.firstMatch.swipeUp()
        }
        
        // Scroll up a bit
        switch deviceType {
        case "iPhone SE (1st generation)":                          // 4-inch
            swipeCount = 4
        case "iPhone SE (3rd generation)":                          // 4.7-inch
            swipeCount = 4
        case "iPhone 8 Plus":                                       // 5.5-inch
            swipeCount = 4
        case "iPhone 16e":                                          // 6.1-inch
            swipeCount = 4
        case "iPhone 16 Pro":                                       // 6.3-inch
            swipeCount = 4
        case "iPhone 14 Plus":                                      // 6.5-inch
            swipeCount = 4
        case "iPhone 16 Pro Max":                                   // 6.7-inch
            swipeCount = 4
        case "iPad Pro 9.7-inch (Wi-Fi + Cellular)":                // 9.7-inch
            swipeCount = 3
        case "iPad Pro 10.5-inch (Wi-Fi)":                          // 10.5-inch
            swipeCount = 3
        case "iPad Pro 11-inch (M4) (Wi-Fi + Cellular)":            // 11-inch
            swipeCount = 3
        case "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)":         // 12.9-inch
            swipeCount = 3
        case "iPad Pro 13-inch (M4) (Wi-Fi + Cellular)":            // 13-inch
            swipeCount = 3
        default:
            swipeCount = 0
        }
        for _ in 0..<swipeCount {
            app.collectionViews.firstMatch.swipeDown(velocity: 200)
            sleep(1)
        }
        
        // MARK: Screenshot #4
        // Select images with the aim to modify properties
        app.navigationBars.buttons["select"].tap()
        sleep(1)
        app.buttons["Select"].tap()
        sleep(1)
        switch deviceType {
        case "iPhone SE (1st generation)":                          // 4-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 8).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 9).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
        case "iPhone SE (3rd generation)":                          // 4.7-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 4).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 5).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 8).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 9).tap()
        case "iPhone 8 Plus":                                       // 5.5-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 8).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 9).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
        case "iPhone 16e":                                          // 6.1-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 8).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 9).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
        case "iPhone 16 Pro":                                       // 6.3-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 8).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 9).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
        case "iPhone 14 Plus":                                      // 6.5-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 8).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 9).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
        case "iPhone 16 Pro Max":                                   // 6.7-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 8).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 9).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
        case "iPad Pro 9.7-inch (Wi-Fi + Cellular)":                // 9.7-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 11).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 14).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 15).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 16).tap()
        case "iPad Pro 10.5 inch (Wi-Fi)":                          // 10.5-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 11).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 14).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 15).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 16).tap()
        case "iPad Pro 11-inch (M4) (Wi-Fi + Cellular)":            // 11-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 11).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 14).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 15).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 16).tap()
        case "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)":         // 12.9-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 14).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 15).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 16).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 17).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 18).tap()
        case "iPad Pro 13-inch (M4) (Wi-Fi + Cellular)":            // 13-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 14).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 15).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 16).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 17).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 18).tap()
        default:
            break
        }
        app.navigationBars.buttons["actions"].tap()
        snapshot("Image04")
        
        // Deselect images
        app.collectionViews.buttons["editProperties"].tap()
        sleep(1)                        // Leave time for animation
        app.navigationBars["editParams"].buttons["Cancel"].tap()
        sleep(1)                        // Leave time for animation

        // MARK: Screenshot #6
        // Show Add buttons
        swipeCount = Int(Double(swipeCount / 2).rounded(.awayFromZero))
        for _ in 0..<swipeCount {
            app.collectionViews.firstMatch.swipeUp()
        }
        app.buttons["add"].tap()
        sleep(2)                        // Leave time for animation
        snapshot("Image06")
        
        // MARK: Screenshot #7
        // Show recent images to upload
        app.buttons["addImages"].tap()
        sleep(1)                        // Leave time for animation
        app.tables.children(matching: .cell).matching(identifier: "Recent").element.tap()
        sleep(1)                        // Leave time for animation
        let images = app.collectionViews.matching(identifier: "CameraRoll").children(matching: .cell)
        images.element(boundBy: 0).children(matching: .other).element.tap()
        images.element(boundBy: 1).children(matching: .other).element.tap()
        images.element(boundBy: 2).children(matching: .other).element.tap()
        images.element(boundBy: 3).children(matching: .other).element.tap()
        images.element(boundBy: 4).children(matching: .other).element.tap()
        images.element(boundBy: 5).children(matching: .other).element.tap()
        images.element(boundBy: 6).children(matching: .other).element.tap()
        images.element(boundBy: 8).children(matching: .other).element.tap()
        let moreButton = app.navigationBars["LocalImagesNav"].buttons["Action"]
        moreButton.tap()
        app.collectionViews.buttons["groupByWeek"].tap()
        sleep(1)                        // Leave time for animation
        moreButton.tap()
        sleep(1)                        // Leave time for animation
        snapshot("Image07")
        
        // MARK: Screenshot #8
        // Show upload parameters
        app.collectionViews.buttons["groupByWeek"].tap()
        sleep(1)                        // Leave time for animation
        if deviceType.contains("iPhone") {
            app.toolbars.buttons["Upload"].tap()
        } else {
            app.navigationBars["LocalImagesNav"].buttons["Upload"].tap()
        }
        sleep(1)
        snapshot("Image08")
        
        // MARK: Screenshot #9
        // Show upload settings
        app.navigationBars["UploadSwitchView"]/*@START_MENU_TOKEN@*/.buttons["settings"]/*[[".segmentedControls.buttons[\"settings\"]",".buttons[\"settings\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        sleep(1)
        snapshot("Image09")
        
        // Dismiss upload views
        app.navigationBars["UploadSwitchView"].buttons["Cancel"].tap()
        let localimagesnavNavigationBar = app.navigationBars["LocalImagesNav"]
        localimagesnavNavigationBar.buttons.element(boundBy: 0).tap()
        sleep(1)                        // Leave time for animation
        localimagesnavNavigationBar.buttons.element(boundBy: 0).tap()
        app.navigationBars["LocalAlbumsNav"].buttons["Cancel"].tap()
        app.buttons["rootAlbum"].tap()
        sleep(1)                        // Leave time for animation
        
        // MARK: Screenshot #10
        // Show app settings
        app.buttons["settings"].tap()
        sleep(1)                        // Leave time for animation
        switch deviceType {
        case "iPhone SE (1st generation)",                          // 4-inch
            "iPhone SE (3rd generation)",                          // 4.7-inch
            "iPhone 8 Plus",                                       // 5.5-inch
            "iPhone 16e",                                          // 6.1-inch
            "iPhone 16 Pro",                                       // 6.1-inch
            "iPhone 14 Plus",                                      // 6.5-inch
            "iPhone 16 Pro Max":                                   // 6.7-inch
            swipeCount = 2
        case "iPad Pro 9.7-inch (Wi-Fi + Cellular)":                // 9.7-inch
            swipeCount = 2
        case "iPad Pro 10.5 inch (Wi-Fi)":                          // 10.5-inch
            swipeCount = 2
        case "iPad Pro 11-inch (M4) (Wi-Fi + Cellular)":            // 11-inch
            swipeCount = 2
        case "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)":         // 12.9-inch
            swipeCount = 2
        case "iPad Pro 13-inch (M4) (Wi-Fi + Cellular)":            // 13-inch
            swipeCount = 2
        default:
            break
        }
        for _ in 0..<swipeCount {
            app.tables["settings"].firstMatch.swipeUp(velocity: 150)
            sleep(1)                        // Leave time for animation
        }
        snapshot("Image10")
    }
}
