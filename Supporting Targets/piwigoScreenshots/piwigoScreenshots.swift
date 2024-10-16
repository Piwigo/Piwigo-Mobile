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
        
        // Settings
        let withAlbumDescriptions = false
        
        // Screenshot #1:
        if withAlbumDescriptions {
            // Swipe left to reveal album actions when displaying albums with description
            var index = 1
            if deviceType.hasPrefix("iPad") {
                index = 7
            }
            let collectionCell = app.collectionViews.children(matching: .cell).element(boundBy: index)
            let tableQuery = collectionCell.children(matching: .other).element.tables.element(boundBy: 0)
            sleep(4);
            tableQuery.swipeLeft()
        }
        snapshot("Image01")
        
        // Screenshot #2: collection of images
        app.collectionViews.children(matching: .cell).element(boundBy: 2).tap()
        sleep(2);
        if deviceType.hasPrefix("iPhone") {
            if withAlbumDescriptions {
                app.collectionViews.children(matching: .cell).element(boundBy: 2).swipeUp()
                sleep(2);
            } else {
                switch deviceType {
                case "iPhone SE (1st generation)":                          // 4-inch
                    for _ in 1...2 {
                        app.collectionViews.firstMatch.swipeUp(velocity: 200)
                        sleep(1)
                    }
                case "iPhone SE (3rd generation)":                          // 4.7-inch
                    for _ in 1...2 {
                        app.collectionViews.firstMatch.swipeUp(velocity: 200)
                        sleep(1)
                    }
                case "iPhone 8 Plus":                                       // 5.5-inch
                    for _ in 1...2 {
                        app.collectionViews.firstMatch.swipeUp(velocity: 200)
                        sleep(1)
                    }
                case "iPhone 14":                                           // 5.8-inch
                    for _ in 1...2 {
                        app.collectionViews.firstMatch.swipeUp(velocity: 200)
                        sleep(1)
                    }
                case "iPhone 14 Pro":                                       // 6.1-inch
                    for _ in 1...2 {
                        app.collectionViews.firstMatch.swipeUp(velocity: 200)
                        sleep(1)
                    }
                case "iPhone 14 Plus":                                      // 6.5-inch
                    for _ in 1...2 {
                        app.collectionViews.firstMatch.swipeUp(velocity: 200)
                        sleep(1)
                    }
                case "iPhone 15 Pro Max":                                   // 6.7-inch
                    for _ in 1...2 {
                        app.collectionViews.firstMatch.swipeUp(velocity: 200)
                        sleep(1)
                    }
                default:
                    break
                }
            }
        }
        snapshot("Image02")

        /*
        // Screenshot #3: image previewed
        // https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
        app.collectionViews.cells["Clos de Vougeot"].tap()
        sleep(3)
        switch deviceType {
        case "iPhone SE (1st generation)":                          // 4-inch
            app.images.element(boundBy: 0).pinch(withScale: 1.1, velocity: 2.0)
            sleep(1)
            app.images.element(boundBy: 0).tap()
        case "iPhone SE (3rd generation)":                          // 4.7-inch
            app.images.element(boundBy: 0).pinch(withScale: 1.15, velocity: 2.0)
            sleep(1)
            app.images.element(boundBy: 0).tap()
        case "iPhone 8 Plus":                                       // 5.5-inch
            app.images.element(boundBy: 0).pinch(withScale: 1.18, velocity: 2.0)
            sleep(1)
            app.images.element(boundBy: 0).tap()
        case "iPhone 14":                                           // 5.8-inch
            app.images.element(boundBy: 0).pinch(withScale: 1.13, velocity: 2.0)
            sleep(1)
            app.images.element(boundBy: 0).tap()
        case "iPhone 13 Pro":                                       // Wiki
            app.images.element(boundBy: 0).pinch(withScale: 1.13, velocity: 2.0)
            sleep(1)
            app.images.element(boundBy: 0).tap()
        case "iPhone 14 Pro":                                       // 6.1-inch
            app.images.element(boundBy: 0).pinch(withScale: 1.13, velocity: 2.0)
            sleep(1)
            app.images.element(boundBy: 0).tap()
        case "iPhone 14 Plus":                                      // 6.5-inch
            app.images.element(boundBy: 0).pinch(withScale: 1.18, velocity: 2.0)
            sleep(1)
            app.images.element(boundBy: 0).tap()
        case "iPhone 15 Pro Max":                                   // 6.7-inch
            app.images.element(boundBy: 0).pinch(withScale: 1.18, velocity: 2.0)
            sleep(1)
            app.images.element(boundBy: 0).tap()
        case "iPad Pro 9.7-inch (Wi-Fi + Cellular)":                // 9.7-inch
            break
        case "iPad Pro 10.5 inch (Wi-Fi)":                          // 10.5-inch
            break
        case "iPad Pro 11-inch (4th generation) (Wi-Fi)":           // 11-inch
            app.images.element(boundBy: 0).pinch(withScale: 1.1, velocity: 2.0)
            sleep(1)
            app.images.element(boundBy: 0).tap()
        case "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)":         // 12.9-inch
            break
        case "iPad Pro 12.9-inch (6th generation) (Wi-Fi)":         // 12.9-inch
            break
        default:
            break
        }
        sleep(2)                        // Leave time for animation
        app.buttons["actions"].tap()
        snapshot("Image03")
        
        // Screenshot #4: collection with selected images
        app.collectionViews.buttons["Edit Parameters"].tap()
        sleep(1)                        // Leave time for animation
        app.buttons["Cancel"].tap()
        sleep(1)                        // Leave time for animation
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)                        // Leave time for animation
        switch deviceType {
        case "iPhone SE (1st generation)":                          // 4-inch
            for _ in 1...6 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPhone SE (3rd generation)":                          // 4.7-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPhone 8 Plus":                                       // 5.5-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPhone 14":                                           // 5.8-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPhone 14 Pro":                                       // 6.1-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPhone 14 Plus":                                      // 6.5-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPhone 15 Pro Max":                                   // 6.7-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPad Pro 9.7-inch (Wi-Fi + Cellular)":                // 9.7-inch
            for _ in 1...3 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPad Pro 10.5 inch (Wi-Fi)":                          // 10.5-inch
            for _ in 1...3 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPad Pro 11-inch (4th generation) (Wi-Fi)":           // 11-inch
            for _ in 1...3 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)":         // 12.9-inch
            for _ in 1...2 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPad Pro 12.9-inch (6th generation) (Wi-Fi)":         // 12.9-inch
            for _ in 1...2 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
            break
        default:
            break
        }
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
        case "iPhone 14":                                           // 5.8-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 8).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 9).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
        case "iPhone 14 Pro":                                       // 6.1-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 8).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 9).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
        case "iPhone 14 Plus":                                      // 6.5-inch
            app.collectionViews.children(matching: .cell).element(boundBy: 8).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 9).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 12).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 13).tap()
        case "iPhone 15 Pro Max":                                   // 6.7-inch
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
        case "iPad Pro 11-inch (4th generation) (Wi-Fi)":           // 11-inch
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
        case "iPad Pro 12.9-inch (6th generation) (Wi-Fi)":         // 12.9-inch
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
        
        // Screenshot #5: Edit parameters
        app.collectionViews.buttons["editProperties"].tap()
        sleep(1)                        // Leave time for animation
        app.navigationBars["editParams"].buttons["Cancel"].tap()
        sleep(1)                        // Leave time for animation
        switch deviceType {
        case "iPhone SE (1st generation)":                          // 4-inch
            for _ in 1...6 {
                app.collectionViews.firstMatch.swipeDown(velocity: 200)
                sleep(1)
            }
        case "iPhone SE (3rd generation)":                          // 4.7-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeDown(velocity: 200)
                sleep(1)
            }
        case "iPhone 8 Plus":                                       // 5.5-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeDown(velocity: 200)
                sleep(1)
            }
        case "iPhone 14":                                           // 5.8-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeDown(velocity: 200)
                sleep(1)
            }
        case "iPhone 14 Pro":                                       // 6.1-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeDown(velocity: 200)
                sleep(1)
            }
        case "iPhone 14 Plus":                                      // 6.5-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeDown(velocity: 200)
                sleep(1)
            }
        case "iPhone 15 Pro Max":                                   // 6.7-inch
            for _ in 1...7 {
                app.collectionViews.firstMatch.swipeDown(velocity: 200)
                sleep(1)
            }
        case "iPad Pro 9.7-inch (Wi-Fi + Cellular)":                // 9.7-inch
            break
        case "iPad Pro 10.5 inch (Wi-Fi)":                          // 10.5-inch
            break
        case "iPad Pro 11-inch (4th generation) (Wi-Fi)":           // 11-inch
            break
        case "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)":         // 12.9-inch
            break
        case "iPad Pro 12.9-inch (6th generation) (Wi-Fi)":         // 12.9-inch
            break
        default:
            break
        }
        app.collectionViews.cells["Hotel de Coimbra"].tap()
        sleep(2)
        switch deviceType {
        case "iPhone SE (1st generation)":                          // 4-inch
             "iPhone SE (3rd generation)",                          // 4.7-inch
             "iPhone 8 Plus",                                       // 5.5-inch
             "iPhone 14",                                           // 5.8-inch
             "iPhone 14 Pro",                                       // 6.1-inch
             "iPhone 14 Plus",                                      // 6.5-inch
             "iPhone 15 Pro Max":                                   // 6.7-inch
            break
        case "iPad Pro 9.7-inch (Wi-Fi + Cellular)":                // 9.7-inch
            break
        case "iPad Pro 10.5 inch (Wi-Fi)":                          // 10.5-inch
            break
        case "iPad Pro 11-inch (4th generation) (Wi-Fi)":           // 11-inch
            app.images.element(boundBy: 0).pinch(withScale: 1.1, velocity: 2.0)
            app.images.element(boundBy: 0).tap()
        case "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)":         // 12.9-inch
            break
        case "iPad Pro 12.9-inch (6th generation) (Wi-Fi)":         // 12.9-inch
            break
        default:
            break
        }
        sleep(1)                        // Leave time for animation
        app.buttons["actions"].tap()
        app.collectionViews.buttons["Edit Parameters"].tap()
        sleep(2)                        // Leave time for animation
        snapshot("Image05")
        
        // Screenshot #6: create album & add image buttons
        app.buttons["Cancel"].tap()
        sleep(2)                        // Leave time for animation
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(2)                        // Leave time for animation
        switch deviceType {
        case "iPhone SE (1st generation)":                          // 4-inch
             "iPhone SE (3rd generation)",                          // 4.7-inch
             "iPhone 8 Plus",                                       // 5.5-inch
             "iPhone 14",                                           // 5.8-inch
             "iPhone 14 Pro",                                       // 6.1-inch
             "iPhone 14 Plus",                                      // 6.5-inch
             "iPhone 15 Pro Max":                                   // 6.7-inch
            for _ in 1...4 {
                app.collectionViews.firstMatch.swipeUp()
            }
        case "iPad Pro 9.7-inch (Wi-Fi + Cellular)":                // 9.7-inch
            for _ in 1...3 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPad Pro 10.5 inch (Wi-Fi)":                          // 10.5-inch
            for _ in 1...3 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPad Pro 11-inch (4th generation) (Wi-Fi)":           // 11-inch
            for _ in 1...4 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPad Pro 12.9-inch (2nd generation) (Wi-Fi)":         // 12.9-inch
            for _ in 1...2 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        case "iPad Pro 12.9-inch (6th generation) (Wi-Fi)":         // 12.9-inch
            for _ in 1...2 {
                app.collectionViews.firstMatch.swipeUp(velocity: 200)
                sleep(1)
            }
        default:
            break
        }
        app.buttons["add"].tap()
        sleep(2)                        // Leave time for animation
        snapshot("Image06")
        
        // Screenshot #7: local images
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
        
        // Screenshot #8: upload images, parameters
        app.collectionViews.buttons["groupByWeek"].tap()
        sleep(1)                        // Leave time for animation
        if deviceType.contains("iPhone") {
            app.toolbars.buttons["Upload"].tap()
        } else {
            app.navigationBars["LocalImagesNav"].buttons["Upload"].tap()
        }
        sleep(1)
        snapshot("Image08")
        
        // Screenshot #9: upload images, settings
        app.navigationBars["UploadSwitchView"]/*@START_MENU_TOKEN@*/.buttons["settings"]/*[[".segmentedControls.buttons[\"settings\"]",".buttons[\"settings\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        sleep(1)
        snapshot("Image09")
        
        // Screenshot #10: settings
        app.navigationBars["UploadSwitchView"].buttons["Cancel"].tap()
        let localimagesnavNavigationBar = app.navigationBars["LocalImagesNav"]
        localimagesnavNavigationBar.buttons.element(boundBy: 0).tap()
        sleep(1)                        // Leave time for animation
        localimagesnavNavigationBar.buttons.element(boundBy: 0).tap()
        app.navigationBars["LocalAlbumsNav"].buttons["Cancel"].tap()
        app.buttons["rootAlbum"].tap()
        sleep(1)                        // Leave time for animation
        app.buttons["settings"].tap()
        sleep(1)                        // Leave time for animation
        app.tables["settings"].cells["server"].swipeUp()
        app.tables["settings"].firstMatch.swipeUp(velocity: 200)
        sleep(2)                        // Leave time for animation
        snapshot("Image10")
        */
    }
}
