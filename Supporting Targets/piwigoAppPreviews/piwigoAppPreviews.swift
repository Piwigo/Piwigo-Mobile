//
//  piwigoUITests.swift
//  piwigoUITests
//
//  Created by Eddy Lelièvre-Berna on 25/08/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

import XCTest

class piwigoAppStore: XCTestCase {
    
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
    
    // MARK: - Prepare Videos
    func testVideoUpload() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let app = XCUIApplication()
        let deviceType = UIDevice().modelName
        sleep(2);
        
        // Create "Delft" album
        app.buttons["add"].tap()
        app.typeText("Delft")
        app.alerts["CreateAlbum"].scrollViews.otherElements.buttons["Add"].tap()
        sleep(1)                        // Leave time for animation
        
        // Open "Delft" album
        app.collectionViews.children(matching: .cell).element(boundBy: 0).tap()
        
        // Tap "Upload" button
        app.buttons["add"].tap()
        app/*@START_MENU_TOKEN@*/.buttons["addImages"]/*[[".buttons[\"imageUpload\"]",".buttons[\"addImages\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
//        sleep(1)                        // Leave time for animation

        // Select Recent album
        app.tables.children(matching: .cell).matching(identifier: "Recent").element.tap()
//        sleep(1)                        // Leave time for animation

        // Select photo
        let images = app.collectionViews.matching(identifier: "CameraRoll").children(matching: .cell)
        images.element(boundBy: 4).children(matching: .other).element.tap()
        
        // Display upload settings
        if deviceType.contains("iPhone") {
            app.toolbars.buttons["Upload"].tap()
        } else {
            app.navigationBars["LocalImagesNav"].buttons["Upload"].tap()
        }
//        sleep(1)                        // Leave time for animation

        // Check upload settings
        app.navigationBars["UploadSwitchView"]/*@START_MENU_TOKEN@*/.buttons["settings"]/*[[".segmentedControls.buttons[\"settings\"]",".buttons[\"settings\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        // Upload photos
        app.navigationBars["UploadSwitchView"].buttons["Upload"].tap()
        
        // Return to album
        app.navigationBars["LocalImagesNav"].buttons["Photo Library"].tap()
        app.navigationBars["LocalAlbumsNav"].buttons["Cancel"].tap()
        
        // Return to root
        app.buttons["rootAlbum"].tap()
        sleep(18)                        // Leave time for animation
        
        // Delete temporary album
        let collectionCell = app.collectionViews.children(matching: .cell).element(boundBy: 0)
        let tableQuery = collectionCell.children(matching: .other).element.tables.element(boundBy: 0)
        tableQuery/*@START_MENU_TOKEN@*/.staticTexts["comment"]/*[[".cells[\"albumName, comment, nberImages\"].staticTexts[\"comment\"]",".staticTexts[\"comment\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.swipeLeft()
        tableQuery.buttons["swipeTrash"].tap()
        sleep(1)                        // Leave time for animation
        app.scrollViews.otherElements.buttons["DeleteAll"].tap()
        app.typeText("1")
        app.typeText("1")
        app.typeText(XCUIKeyboardKey.delete.rawValue)
        app.alerts["Are you sure?"].scrollViews.otherElements/*@START_MENU_TOKEN@*/.buttons["DeleteAll"]/*[[".buttons[\"DELETE\"]",".buttons[\"DeleteAll\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        sleep(2)

        // Clear Upload cache
        app.navigationBars.element(boundBy: 0).buttons["settings"].tap()
        sleep(2);
        app.tables["settings"].cells["server"].swipeUp()
        sleep(1);
        app.tables["settings"].cells["displayImageTitles"].swipeUp()
        sleep(1);
        app.tables["settings"].cells["wifiOnly"].swipeUp()
        sleep(1);
        app.tables["settings"]/*@START_MENU_TOKEN@*/.staticTexts["Clear Cache"]/*[[".cells[\"Clear Cache\"].staticTexts[\"Clear Cache\"]",".cells[\"clearCache\"].staticTexts[\"Clear Cache\"]",".staticTexts[\"Clear Cache\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app.scrollViews.otherElements.buttons["uploadCache"].tap()
        app.navigationBars["Settings"].buttons["Done"].tap()
    }
}
