//
//  piwigoUITests.swift
//  piwigoUITests
//
//  Created by Eddy Lelièvre-Berna on 25/08/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

import XCTest

public enum Model : String {
    case simulator     = "simulator/sandbox",
    //iPod
    iPod1              = "iPod 1",
    iPod2              = "iPod 2",
    iPod3              = "iPod 3",
    iPod4              = "iPod 4",
    iPod5              = "iPod 5",
    //iPad
    iPad2              = "iPad 2",
    iPad3              = "iPad 3",
    iPad4              = "iPad 4",
    iPadAir            = "iPad Air ",
    iPadAir2           = "iPad Air 2",
    iPad5              = "iPad 5", //aka iPad 2017
    iPad6              = "iPad 6", //aka iPad 2018
    //iPad mini
    iPadMini           = "iPad Mini",
    iPadMini2          = "iPad Mini 2",
    iPadMini3          = "iPad Mini 3",
    iPadMini4          = "iPad Mini 4",
    //iPad pro
    iPadPro9_7         = "iPad Pro 9.7\"",
    iPadPro10_5        = "iPad Pro 10.5\"",
    iPadPro12_9        = "iPad Pro 12.9\"",
    iPadPro2_12_9      = "iPad Pro 2 12.9\"",
    //iPhone
    iPhone4            = "iPhone 4",
    iPhone4S           = "iPhone 4S",
    iPhone5            = "iPhone 5",
    iPhone5S           = "iPhone 5S",
    iPhone5C           = "iPhone 5C",
    iPhone6            = "iPhone 6",
    iPhone6plus        = "iPhone 6 Plus",
    iPhone6S           = "iPhone 6S",
    iPhone6Splus       = "iPhone 6S Plus",
    iPhoneSE           = "iPhone SE",
    iPhone7            = "iPhone 7",
    iPhone7plus        = "iPhone 7 Plus",
    iPhone8            = "iPhone 8",
    iPhone8plus        = "iPhone 8 Plus",
    iPhoneX            = "iPhone X",
    iPhoneXs           = "iPhone XS",
    iPhoneXsMax        = "iPhone XS Max",
    iPhoneXr           = "iPhone XR",
    //Apple TV
    AppleTV            = "Apple TV",
    AppleTV_4K         = "Apple TV 4K",
    unrecognized       = "?unrecognized?"
}

// #-#-#-#-#-#-#-#-#-#-#-#-#-#-#
// MARK: UIDevice extensions
// #-#-#-#-#-#-#-#-#-#-#-#-#-#-#

public extension UIDevice {
    public var type: Model {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
                
            }
        }
        var modelMap : [ String : Model ] = [
            "i386"      : .simulator,
            "x86_64"    : .simulator,
            //iPod
            "iPod1,1"   : .iPod1,
            "iPod2,1"   : .iPod2,
            "iPod3,1"   : .iPod3,
            "iPod4,1"   : .iPod4,
            "iPod5,1"   : .iPod5,
            //iPad
            "iPad2,1"   : .iPad2,
            "iPad2,2"   : .iPad2,
            "iPad2,3"   : .iPad2,
            "iPad2,4"   : .iPad2,
            "iPad3,1"   : .iPad3,
            "iPad3,2"   : .iPad3,
            "iPad3,3"   : .iPad3,
            "iPad3,4"   : .iPad4,
            "iPad3,5"   : .iPad4,
            "iPad3,6"   : .iPad4,
            "iPad4,1"   : .iPadAir,
            "iPad4,2"   : .iPadAir,
            "iPad4,3"   : .iPadAir,
            "iPad5,3"   : .iPadAir2,
            "iPad5,4"   : .iPadAir2,
            "iPad6,11"  : .iPad5, //aka iPad 2017
            "iPad6,12"  : .iPad5,
            "iPad7,5"   : .iPad6, //aka iPad 2018
            "iPad7,6"   : .iPad6,
            //iPad mini
            "iPad2,5"   : .iPadMini,
            "iPad2,6"   : .iPadMini,
            "iPad2,7"   : .iPadMini,
            "iPad4,4"   : .iPadMini2,
            "iPad4,5"   : .iPadMini2,
            "iPad4,6"   : .iPadMini2,
            "iPad4,7"   : .iPadMini3,
            "iPad4,8"   : .iPadMini3,
            "iPad4,9"   : .iPadMini3,
            "iPad5,1"   : .iPadMini4,
            "iPad5,2"   : .iPadMini4,
            //iPad pro
            "iPad6,3"   : .iPadPro9_7,
            "iPad6,4"   : .iPadPro9_7,
            "iPad7,3"   : .iPadPro10_5,
            "iPad7,4"   : .iPadPro10_5,
            "iPad6,7"   : .iPadPro12_9,
            "iPad6,8"   : .iPadPro12_9,
            "iPad7,1"   : .iPadPro2_12_9,
            "iPad7,2"   : .iPadPro2_12_9,
            //iPhone
            "iPhone3,1" : .iPhone4,
            "iPhone3,2" : .iPhone4,
            "iPhone3,3" : .iPhone4,
            "iPhone4,1" : .iPhone4S,
            "iPhone5,1" : .iPhone5,
            "iPhone5,2" : .iPhone5,
            "iPhone5,3" : .iPhone5C,
            "iPhone5,4" : .iPhone5C,
            "iPhone6,1" : .iPhone5S,
            "iPhone6,2" : .iPhone5S,
            "iPhone7,1" : .iPhone6plus,
            "iPhone7,2" : .iPhone6,
            "iPhone8,1" : .iPhone6S,
            "iPhone8,2" : .iPhone6Splus,
            "iPhone8,4" : .iPhoneSE,
            "iPhone9,1" : .iPhone7,
            "iPhone9,3" : .iPhone7,
            "iPhone9,2" : .iPhone7plus,
            "iPhone9,4" : .iPhone7plus,
            "iPhone10,1" : .iPhone8,
            "iPhone10,4" : .iPhone8,
            "iPhone10,2" : .iPhone8plus,
            "iPhone10,5" : .iPhone8plus,
            "iPhone10,3" : .iPhoneX,
            "iPhone10,6" : .iPhoneX,
            "iPhone11,2" : .iPhoneXs,
            "iPhone11,4" : .iPhoneXsMax,
            "iPhone11,6" : .iPhoneXsMax,
            "iPhone11,8" : .iPhoneXr,
            //AppleTV
            "AppleTV5,3" : .AppleTV,
            "AppleTV6,2" : .AppleTV_4K
        ]
        
        if let model = modelMap[String.init(validatingUTF8: modelCode!)!] {
            if model == .simulator {
                if let simModelCode = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
                    if let simModel = modelMap[String.init(validatingUTF8: simModelCode)!] {
                        return simModel
                    }
                }
            }
            return model
        }
        return Model.unrecognized
    }
}

class piwigoAppStore: XCTestCase {
        
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
    
    func testScreenshots() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        let app = XCUIApplication()
        let deviceType = UIDevice().type.rawValue
        sleep(2);

        // Select Photos Title A->Z sort order
        app.navigationBars.element(boundBy: 0).buttons["preferences"].tap()
        sleep(1);
        app.tables["preferences"].cells["defaultSort"].tap()
        app.tables["sortSelect"].cells.element(boundBy: 0).tap()
        app.navigationBars.buttons["Done"].tap()

        // Screenshot #1: swipe left and reveal album actions
        var index = 1
        if deviceType.hasPrefix("iPad") {
            index = 7
        }
        let collectionCell = app.collectionViews.children(matching: .cell).element(boundBy: index)
        let tableQuery = collectionCell.children(matching: .other).element.tables.element(boundBy: 0)
        sleep(1);
        tableQuery/*@START_MENU_TOKEN@*/.staticTexts["comment"]/*[[".cells[\"albumName, comment, nberImages\"].staticTexts[\"comment\"]",".staticTexts[\"comment\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.swipeLeft()
        snapshot("Image1")
        
        // Screenshot #2: collection of images
        app.collectionViews.children(matching: .cell).element(boundBy: 2).tap()
        app.collectionViews.children(matching: .cell).element(boundBy: 0).swipeUp()
        sleep(2);
        snapshot("Image2")

        // Screenshot #3: collection with selected images
        app.navigationBars.buttons["Select"].tap()
        if deviceType.hasPrefix("iPhone") {
            app.collectionViews.children(matching: .cell).element(boundBy: 16).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 21).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 20).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 19).tap()
            app.collectionViews.children(matching: .cell).element(boundBy: 17).tap()
        } else {
            if (deviceType == "iPad Pro 9.7\"") {
                app.collectionViews.children(matching: .cell).element(boundBy: 16).tap()
                app.collectionViews.children(matching: .cell).element(boundBy: 24).tap()
                app.collectionViews.children(matching: .cell).element(boundBy: 23).tap()
                app.collectionViews.children(matching: .cell).element(boundBy: 22).tap()
                app.collectionViews.children(matching: .cell).element(boundBy: 21).tap()
                app.collectionViews.children(matching: .cell).element(boundBy: 20).tap()
            } else {
                app.collectionViews.children(matching: .cell).element(boundBy: 20).tap()
                app.collectionViews.children(matching: .cell).element(boundBy: 21).tap()
                app.collectionViews.children(matching: .cell).element(boundBy: 22).tap()
                app.collectionViews.children(matching: .cell).element(boundBy: 31).tap()
                app.collectionViews.children(matching: .cell).element(boundBy: 30).tap()
                app.collectionViews.children(matching: .cell).element(boundBy: 29).tap()
                app.collectionViews.children(matching: .cell).element(boundBy: 28).tap()
            }
        }
        snapshot("Image3")

        // Screenshot #4: image previewed
        app.navigationBars.buttons["Cancel"].tap()
        if deviceType.hasPrefix("iPhone") {
            app.collectionViews.children(matching: .cell).element(boundBy: 15).tap()
        } else {
            if (deviceType == "iPad Pro 9.7\"") {
                app.collectionViews.children(matching: .cell).element(boundBy: 14).tap()
            } else {
                app.collectionViews.children(matching: .cell).element(boundBy: 18).tap()
            }
        }
        if deviceType == "iPhone XS Max" {
            app.images.element(boundBy: 0).pinch(withScale: 1.1, velocity: 2.0)
            app.images.element(boundBy: 0).pinch(withScale: 0.675, velocity: -2.0)
        }
        if deviceType == "iPhone X" {
            app.images.element(boundBy: 0).pinch(withScale: 1.1, velocity: 2.0)
            app.images.element(boundBy: 0).pinch(withScale: 0.735, velocity: -2.0)
        }
        if deviceType == "iPhone 8 Plus" {
            app.images.element(boundBy: 0).pinch(withScale: 1.1, velocity: 2.0)
            app.images.element(boundBy: 0).pinch(withScale: 0.59, velocity: -2.0)
        }
        if deviceType == "iPhone 8" {
            app.images.element(boundBy: 0).pinch(withScale: 1.1, velocity: 2.0)
            app.images.element(boundBy: 0).pinch(withScale: 0.52, velocity: -2.0)
        }
        if deviceType == "iPhone SE" {
            app.images.element(boundBy: 0).pinch(withScale: 1.1, velocity: 2.0)
            app.images.element(boundBy: 0).pinch(withScale: 0.49, velocity: -2.0)
        }
        if (deviceType == "iPad Pro 9.7\"") {
            app.images.element(boundBy: 0).pinch(withScale: 1.15, velocity: 2.0)
        }
        if (deviceType == "iPad Pro 10.5\"") {
            app.images.element(boundBy: 0).pinch(withScale: 1.1, velocity: 2.0)
        }
        if (deviceType == "iPad Pro 12.9\"") {
            app.images.element(boundBy: 0).pinch(withScale: 1.1, velocity: 2.0)
        }
        snapshot("Image4")
        
        // Screenshot #5: upload view
        app.navigationBars["Castle"].buttons.element(boundBy: 0).tap()
        sleep(2);                       // Leave time for animation
        app.buttons["add"].tap();
        snapshot("Image5")
        
        // Screenshot #6: upload images
        app.tables.children(matching: .cell).element(boundBy: 0).tap()
        app.tables.children(matching: .cell).element(boundBy: 0).tap()
        app.collectionViews.children(matching: .cell).element(boundBy: 0).children(matching: .other).element.tap()
        app.collectionViews.children(matching: .cell).element(boundBy: 1).children(matching: .other).element.tap()
        app.collectionViews.children(matching: .cell).element(boundBy: 2).children(matching: .other).element.tap()
        app.collectionViews.children(matching: .cell).element(boundBy: 3).children(matching: .other).element.tap()
        app.collectionViews.children(matching: .cell).element(boundBy: 4).children(matching: .other).element.tap()
        app.collectionViews.children(matching: .cell).element(boundBy: 5).children(matching: .other).element.tap()
        app.navigationBars.buttons["upload"].tap()
        sleep(1);
        app.tables.children(matching: .cell).element(boundBy: 1).swipeLeft()
        snapshot("Image6")

        // Screenshot #7: settings
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons["Done"].tap()
        app.buttons["rootAlbum"].tap()
        app.navigationBars.buttons["preferences"].tap()
        app.tables["preferences"].cells["server"].swipeUp()
        snapshot("Image7")
    }
}
