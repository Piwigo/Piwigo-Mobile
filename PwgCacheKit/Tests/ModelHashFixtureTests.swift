//
//  ModelHashFixtureTests.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 19 October 2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import CoreData
import XCTest
@testable import PwgCacheKit

/**
 Guards every shipped data model against being edited in place.

 A store records the entity version hashes of the model which wrote it, and Core Data
 opens it only if one of the models in the app has the same hashes. Editing a
 `.xcdatamodel` after a build using it has left the machine — TestFlight included —
 leaves the stores written by that build matching no model: the migration gate
 cannot place them, and the app has to set them aside. That is how model 0P, edited
 on 17, 18 and 21 August 2026 and shipped in v4.4 on 30 August, left stores which
 4.4.2 could not open.

 The hashes below are those of the models as they were released. When this test
 fails for a version which has shipped, restore the model and add a new version
 instead. Only the last version, while it is unreleased, may be edited: regenerate its
 entry from the failure message when it is released.
 */
final class ModelHashFixtureTests: XCTestCase {

    private static let releasedHashes: [DataMigrationVersion: [String: String]] = [
        .version01: [
            "Tag": "JQ0uIc1kBqFncJuFN3yJvgX/nt1XCxtUrGLOLQTstzg=",
        ],
        .version02: [
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Tag": "JQ0uIc1kBqFncJuFN3yJvgX/nt1XCxtUrGLOLQTstzg=",
        ],
        .version03: [
            "Location": "cRsAbjnibvoeCpFVrxrmhNWs4DZTe5bT9CQB32rFR3Y=",
            "Tag": "DJE66S/tIW9YlEc3lFWGRQ3FrJJikkICQakf4dlD+Tk=",
            "Upload": "bAsE8MBqLyyYZ0xLfbWuFccMP0OGg64FhYgI14ojkQg=",
        ],
        .version04: [
            "Location": "cRsAbjnibvoeCpFVrxrmhNWs4DZTe5bT9CQB32rFR3Y=",
            "Tag": "DJE66S/tIW9YlEc3lFWGRQ3FrJJikkICQakf4dlD+Tk=",
            "Upload": "2fX0pcexSQ5p5YZSY0Lw5wXF6iOVxU20uTldu6qSHwA=",
        ],
        .version05: [
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Tag": "LJ1L6SQAGMlQJDeydu1iil4Agjzq0SBjqOYhYOiWoq0=",
            "Upload": "gv7831/Cu1pwgXrCJeMred08fqTjy51PSqJrc1Rjrik=",
        ],
        .version06: [
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Tag": "LJ1L6SQAGMlQJDeydu1iil4Agjzq0SBjqOYhYOiWoq0=",
            "Upload": "gv7831/Cu1pwgXrCJeMred08fqTjy51PSqJrc1Rjrik=",
        ],
        .version07: [
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Tag": "LJ1L6SQAGMlQJDeydu1iil4Agjzq0SBjqOYhYOiWoq0=",
            "Upload": "eluIS2mWvNe4PrsDKvg+wylyjpD2U4An2cjYq1+e3Jk=",
        ],
        .version08: [
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Tag": "LJ1L6SQAGMlQJDeydu1iil4Agjzq0SBjqOYhYOiWoq0=",
            "Upload": "tfq8m8IcICo0Jmo9fqmqfvTDqzuN963DgbFENFVFKjU=",
        ],
        .version09: [
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Tag": "QRHOULUY5UiuGvjqPMldH8AmoJi4Noi0LCpbrixWHCY=",
            "Upload": "tfq8m8IcICo0Jmo9fqmqfvTDqzuN963DgbFENFVFKjU=",
        ],
        .version0A: [
            "Album": "czvJMd6gXHgPGPWgNz71UzSIqGKGeYABzGpQ0E9143c=",
            "Image": "NkkGqBr3qPu2y0Yyw0Nhkv72RZB7XemcUT37NoWgMK0=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "O6PlgcxAK9UW4iF6G2qPXyNBJVqaCkYhmE3jAzmI53I=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "AYjIYV1YynRrIsSwZrNLI5FAckVOOVNXTHg9MUaPdTw=",
            "User": "mmFgL/m+YTKKo7q+rckwopUbyldP7DgJP69LJeqdJRY=",
        ],
        .version0B: [
            "Album": "X4KluJgXs1RfcTKIYLbZ39vkokmHD3LKPTb1oi/5AuA=",
            "Image": "RyJlLFk5eZTb38fXSKGSpTCD2ZZLrQ3uHR4Wg7ytzdA=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "O6PlgcxAK9UW4iF6G2qPXyNBJVqaCkYhmE3jAzmI53I=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "AYjIYV1YynRrIsSwZrNLI5FAckVOOVNXTHg9MUaPdTw=",
            "User": "mmFgL/m+YTKKo7q+rckwopUbyldP7DgJP69LJeqdJRY=",
        ],
        .version0C: [
            "Album": "X4KluJgXs1RfcTKIYLbZ39vkokmHD3LKPTb1oi/5AuA=",
            "Image": "9DLDwTk3NGoAcP34jyyG/a+/gBXDraITeJ0wtTCq0sA=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "O6PlgcxAK9UW4iF6G2qPXyNBJVqaCkYhmE3jAzmI53I=",
            "Sizes": "u9ZOOkPTmMf07FI3KG+R0GrK4Zh8aYM8VPnt8iHCKsc=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "AYjIYV1YynRrIsSwZrNLI5FAckVOOVNXTHg9MUaPdTw=",
            "User": "mmFgL/m+YTKKo7q+rckwopUbyldP7DgJP69LJeqdJRY=",
        ],
        .version0D: [
            "Album": "gLJNRJNjU5nnb+Ci9zFcYWefMEpF0Q4bxELvDkzRefE=",
            "Image": "9DLDwTk3NGoAcP34jyyG/a+/gBXDraITeJ0wtTCq0sA=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "O6PlgcxAK9UW4iF6G2qPXyNBJVqaCkYhmE3jAzmI53I=",
            "Sizes": "u9ZOOkPTmMf07FI3KG+R0GrK4Zh8aYM8VPnt8iHCKsc=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "AYjIYV1YynRrIsSwZrNLI5FAckVOOVNXTHg9MUaPdTw=",
            "User": "mmFgL/m+YTKKo7q+rckwopUbyldP7DgJP69LJeqdJRY=",
        ],
        .version0E: [
            "Album": "gLJNRJNjU5nnb+Ci9zFcYWefMEpF0Q4bxELvDkzRefE=",
            "Image": "xb4hNZ4MSfYFXpCeZj0D+PHBE0fR0tSz1osqiDedFi0=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "O6PlgcxAK9UW4iF6G2qPXyNBJVqaCkYhmE3jAzmI53I=",
            "Sizes": "u9ZOOkPTmMf07FI3KG+R0GrK4Zh8aYM8VPnt8iHCKsc=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "AYjIYV1YynRrIsSwZrNLI5FAckVOOVNXTHg9MUaPdTw=",
            "User": "mmFgL/m+YTKKo7q+rckwopUbyldP7DgJP69LJeqdJRY=",
        ],
        .version0F: [
            "Album": "gLJNRJNjU5nnb+Ci9zFcYWefMEpF0Q4bxELvDkzRefE=",
            "Image": "xb4hNZ4MSfYFXpCeZj0D+PHBE0fR0tSz1osqiDedFi0=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "O6PlgcxAK9UW4iF6G2qPXyNBJVqaCkYhmE3jAzmI53I=",
            "Sizes": "u9ZOOkPTmMf07FI3KG+R0GrK4Zh8aYM8VPnt8iHCKsc=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "AYjIYV1YynRrIsSwZrNLI5FAckVOOVNXTHg9MUaPdTw=",
            "User": "wFt3Xemu0OVM8dJz0yro9xppF1UZmdcaSp8DX4UW2ng=",
        ],
        .version0G: [
            "Album": "owMIDEd22TLBStg4ULK8Di51Plq7Q8g+PwbDoONT8XA=",
            "Image": "n7aOJ3BNnhgkHuI6WEv7rijRHa91ibI6UAiYvA9qTAI=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "O6PlgcxAK9UW4iF6G2qPXyNBJVqaCkYhmE3jAzmI53I=",
            "Sizes": "u9ZOOkPTmMf07FI3KG+R0GrK4Zh8aYM8VPnt8iHCKsc=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "AYjIYV1YynRrIsSwZrNLI5FAckVOOVNXTHg9MUaPdTw=",
            "User": "wFt3Xemu0OVM8dJz0yro9xppF1UZmdcaSp8DX4UW2ng=",
        ],
        .version0H: [
            "Album": "owMIDEd22TLBStg4ULK8Di51Plq7Q8g+PwbDoONT8XA=",
            "Image": "n7aOJ3BNnhgkHuI6WEv7rijRHa91ibI6UAiYvA9qTAI=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "O6PlgcxAK9UW4iF6G2qPXyNBJVqaCkYhmE3jAzmI53I=",
            "Sizes": "u9ZOOkPTmMf07FI3KG+R0GrK4Zh8aYM8VPnt8iHCKsc=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "AYjIYV1YynRrIsSwZrNLI5FAckVOOVNXTHg9MUaPdTw=",
            "User": "ve+PTwGAK9I23cC9hg4QhZpr3PPbnsXMiL/mOQORicM=",
        ],
        .version0I: [
            "Album": "xJv/MfXhUa/k/t8glzVk6at+2FnSOKNWY3uIKDPYTQU=",
            "Image": "n7aOJ3BNnhgkHuI6WEv7rijRHa91ibI6UAiYvA9qTAI=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "O6PlgcxAK9UW4iF6G2qPXyNBJVqaCkYhmE3jAzmI53I=",
            "Sizes": "u9ZOOkPTmMf07FI3KG+R0GrK4Zh8aYM8VPnt8iHCKsc=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "T8fnGg+zwxmKwuGD0Pr+gLNfwoMaZM/asW49TkNbMrM=",
            "User": "ve+PTwGAK9I23cC9hg4QhZpr3PPbnsXMiL/mOQORicM=",
        ],
        .version0J: [
            "Album": "xJv/MfXhUa/k/t8glzVk6at+2FnSOKNWY3uIKDPYTQU=",
            "Image": "n7aOJ3BNnhgkHuI6WEv7rijRHa91ibI6UAiYvA9qTAI=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "lL9NbYomUJH5nz2rXLwgJyPn795GcXOVwjAcJKbOfvI=",
            "Sizes": "u9ZOOkPTmMf07FI3KG+R0GrK4Zh8aYM8VPnt8iHCKsc=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "T8fnGg+zwxmKwuGD0Pr+gLNfwoMaZM/asW49TkNbMrM=",
            "User": "y8lRXftJKWftk+X8/LaPyFmucdPMmaPwmTZZa3cJqHY=",
            "UserGroup": "j9B/k13qa2upVppsA5HVzrFUBSnytDCi8llUqBq1E1w=",
        ],
        .version0K: [
            "Album": "xJv/MfXhUa/k/t8glzVk6at+2FnSOKNWY3uIKDPYTQU=",
            "Image": "T3FuE+3fLxE+/IPytnx/KUQLDQqSjNyon4BVhOcag4E=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "lL9NbYomUJH5nz2rXLwgJyPn795GcXOVwjAcJKbOfvI=",
            "Sizes": "u9ZOOkPTmMf07FI3KG+R0GrK4Zh8aYM8VPnt8iHCKsc=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "gW2r4lLn083sTjFqQFAPOpnozx/wxZdYP7Ul3TrSIFU=",
            "User": "y8lRXftJKWftk+X8/LaPyFmucdPMmaPwmTZZa3cJqHY=",
            "UserGroup": "j9B/k13qa2upVppsA5HVzrFUBSnytDCi8llUqBq1E1w=",
        ],
        .version0L: [
            "Album": "US7g+7AQsu8Pm6e3jv0eHOi7fF6RCbTQAXSI6XGnx7c=",
            "Image": "MgwH+cGqCU5kulm6mBagsw2gynayG5qnesWgaFEjTJI=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "lL9NbYomUJH5nz2rXLwgJyPn795GcXOVwjAcJKbOfvI=",
            "Sizes": "u9ZOOkPTmMf07FI3KG+R0GrK4Zh8aYM8VPnt8iHCKsc=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "gW2r4lLn083sTjFqQFAPOpnozx/wxZdYP7Ul3TrSIFU=",
            "User": "y8lRXftJKWftk+X8/LaPyFmucdPMmaPwmTZZa3cJqHY=",
            "UserGroup": "j9B/k13qa2upVppsA5HVzrFUBSnytDCi8llUqBq1E1w=",
        ],
        .version0M: [
            "Album": "/etqF4gcw/MbK160Z3Xigf5zzzA3xCJINANTcwRijdM=",
            "Image": "LhouO1qp0rVuzDkkzd/X3DXRrWNVDaY0RzsJniJU8Bw=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "lL9NbYomUJH5nz2rXLwgJyPn795GcXOVwjAcJKbOfvI=",
            "Sizes": "u9ZOOkPTmMf07FI3KG+R0GrK4Zh8aYM8VPnt8iHCKsc=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "gW2r4lLn083sTjFqQFAPOpnozx/wxZdYP7Ul3TrSIFU=",
            "User": "y8lRXftJKWftk+X8/LaPyFmucdPMmaPwmTZZa3cJqHY=",
            "UserGroup": "j9B/k13qa2upVppsA5HVzrFUBSnytDCi8llUqBq1E1w=",
        ],
        .version0N: [
            "Album": "/etqF4gcw/MbK160Z3Xigf5zzzA3xCJINANTcwRijdM=",
            "Image": "LhouO1qp0rVuzDkkzd/X3DXRrWNVDaY0RzsJniJU8Bw=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "lL9NbYomUJH5nz2rXLwgJyPn795GcXOVwjAcJKbOfvI=",
            "Sizes": "4JpZ3ED5mZMQXNaP1xadBPeTvXb3kHOD4pZtOSJ0zI0=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "gW2r4lLn083sTjFqQFAPOpnozx/wxZdYP7Ul3TrSIFU=",
            "User": "y8lRXftJKWftk+X8/LaPyFmucdPMmaPwmTZZa3cJqHY=",
            "UserGroup": "j9B/k13qa2upVppsA5HVzrFUBSnytDCi8llUqBq1E1w=",
        ],
        .version0O: [
            "Album": "/etqF4gcw/MbK160Z3Xigf5zzzA3xCJINANTcwRijdM=",
            "Image": "LhouO1qp0rVuzDkkzd/X3DXRrWNVDaY0RzsJniJU8Bw=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "lL9NbYomUJH5nz2rXLwgJyPn795GcXOVwjAcJKbOfvI=",
            "Sizes": "4JpZ3ED5mZMQXNaP1xadBPeTvXb3kHOD4pZtOSJ0zI0=",
            "Tag": "ezsjj5qxM+whmGPiyVcFRQmYEFymDFxxJ7+MC9H2mJU=",
            "Upload": "+ow5JOa2gUMcWtydo2H/rKX02w+ALCVw7uqIjT8Ejd0=",
            "User": "y8lRXftJKWftk+X8/LaPyFmucdPMmaPwmTZZa3cJqHY=",
            "UserGroup": "j9B/k13qa2upVppsA5HVzrFUBSnytDCi8llUqBq1E1w=",
        ],
        .version0P: [
            "Album": "BBfmVRJM3+Pv+nj5g6M+I8hp7NUw6g3RPzcrhtUN86I=",
            "Image": "QdTOar8QFKLpqZ5N3VK0EOH9MvM3DA/E+IOggMsNCLo=",
            "Location": "bCP59BwtJeBKuJUX7URAmnvf9P0Q2PlBWNYn9zyJFFY=",
            "Server": "lL9NbYomUJH5nz2rXLwgJyPn795GcXOVwjAcJKbOfvI=",
            "Sizes": "4JpZ3ED5mZMQXNaP1xadBPeTvXb3kHOD4pZtOSJ0zI0=",
            "Tag": "WOELsW5NmBbxLwdiK2TKOUrVgGebeH1R9kNU1Iwu2c0=",
            "Upload": "53wlOFmAFngkPseUSmdidByRmfHtkl00oLvqkEPu0zM=",
            "User": "B/nun4tEtFqTgOEG4HhyI849202nC/jOm34i3cxblYw=",
            "UserGroup": "XZNwcukKNqH5LLJJfSfO3n/bZhWqDUAm+t4kRPXxvMo=",
        ],
    ]

    func testEveryShippedModelHasItsFixture() {
        XCTAssertEqual(Set(Self.releasedHashes.keys), Set(DataMigrationVersion.allCases),
                       "A version was added or removed: add or remove its entry in releasedHashes")
    }

    func testShippedModelsAreUnchanged() {
        for (version, expected) in Self.releasedHashes {
            let hashes = NSManagedObjectModel.managedObjectModel(forVersion: version)
                .entityVersionHashesByName.mapValues { $0.base64EncodedString() }
            let drifted = Set(hashes.keys).union(expected.keys)
                .filter { hashes[$0] != expected[$0] }.sorted()
            XCTAssertTrue(drifted.isEmpty,
                          "\(version.rawValue) was edited after its release; entities: \(drifted.joined(separator: ", "))")
        }
    }
}
