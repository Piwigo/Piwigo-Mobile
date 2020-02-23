//
//  Tag.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  An NSManagedObject subclass for the Tag entity.

import CoreData

// MARK: - Core Data
/**
 Managed object subclass for the Tag entity.
 */

@objc
class Tag: NSManagedObject {

    // A unique identifier for removing duplicates. Constrain
    // the PiwigoTagData entity on this attribute in the data model editor.
    @NSManaged var tagId: Int64
    
    // The other attributes of a tag.
    @NSManaged var tagName: String
    @NSManaged var lastModified: Date
    @NSManaged var numberOfImagesUnderTag : Int64

    // Singleton
    @objc static let sharedInstance: Tag = Tag()
    
    /**
     Updates a Tag instance with the values from a TagProperties.
     */
    func update(with tagProperties: TagProperties) throws {
        
        // Update the tag only if the Id and Name properties have values.
        guard let newId = tagProperties.id,
              let newName = tagProperties.name else {
                throw TagError.missingData
        }
        tagId = newId
        tagName = newName

        // In the absence of date, use today
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        lastModified = dateFormatter.date(from: tagProperties.lastmodified ?? "") ?? Date()

        // In the absence of count, use max integer
        if let newCount = tagProperties.counter {
            numberOfImagesUnderTag = newCount
        } else {
            numberOfImagesUnderTag = Int64.max
        }
    }
}

// MARK: - Codable, kPiwigoTagsGetList
/**
 A struct for decoding JSON with the following structure returned by kPiwigoTagsGetList:

{"result":
   {"tags":[
       {"id":1,"lastmodified":"2018-08-23 15:30:43","counter":11,"name":"Birthday","url":"https:…","url_name":"birthday"},
       {"id":14,"lastmodified":"2019-08-27 20:33:01","counter":5,"name":"Cities","url":"https:…","url_name":"cities"},
       {"id":2,"lastmodified":"2018-08-23 15:30:43","counter":9,"name":"Piwigo","url":"https:…","url_name":"piwigo"}
       ]
   },
"stat":"ok"}
 
 or with the following structure returned by kPiwigoTagsGetAdminList:

 {"result":
    {"tags":[
        {"id":"1","lastmodified":"2018-08-23 15:30:43","name":"Birthday","url_name":"birthday"},
        {"id":"14","lastmodified":"2019-08-27 20:33:01","name":"Cities","url_name":"cities"},
        {"id":"2","lastmodified":"2018-08-23 15:30:43","name":"Piwigo","url_name":"piwigo"},
        {"id":"18","lastmodified":"2020-02-08 18:02:22","name":"Test Tag","url_name":"test_tag"}
        ]
    },
 "stat":"ok"}

 Stores an array of decoded TagProperties for later use in creating or updating Tag instances.
*/
struct TagJSON: Decodable {

    private enum RootCodingKeys: String, CodingKey {
        case stat
        case result
        case err
        case message
    }

    private enum ResultCodingKeys: String, CodingKey {
        case tags
        case id
        case name
        case lastmodified
        case url_name
    }

    // Constants
    var stat: String?
    var errorCode = 0
    var errorMessage = ""
    
    // A TagProperties array of decoded Tag data.
    var tagPropertiesArray = [TagProperties]()

    init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        stat = try rootContainer.decodeIfPresent(String.self, forKey: .stat)
        if (stat == "ok")
        {
            // Result container keyed by ResultCodingKeys
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .result)
//            dump(resultContainer)
            
            // Decodes tags from the data and store them in the array
            do {
                // Use TagProperties struct
                try tagPropertiesArray = resultContainer.decode([TagProperties].self, forKey: .tags)
            }
            catch {
                // Use a different struct because id is a String instead of an Int
                let tagPropertiesArray4Admin = try resultContainer.decode([TagProperties4Admin].self, forKey: .tags)
                
                // Inject data into TagProperties after converting id
                for tagProperty4Admin in tagPropertiesArray4Admin {
                    let id:Int64? = Int64(tagProperty4Admin.id ?? "")!
                    let tagProperty = TagProperties(id: id, name: tagProperty4Admin.name, lastmodified: tagProperty4Admin.lastmodified, url_name: tagProperty4Admin.url_name, counter: Int64.max, url: "")
                    tagPropertiesArray.append(tagProperty)
                }
            }
        }
        else if (stat == "fail")
        {
            // Retrieve Piwigo server error
            errorCode = try rootContainer.decode(Int.self, forKey: .err)
            errorMessage = try rootContainer.decode(String.self, forKey: .message)
        }
        else {
            // Unexpected Piwigo server error
        }
    }
}

/**
 A struct for decoding JSON returned by kPiwigoTagsGetList.
 All members are optional in case they are missing from the data.
*/
struct TagProperties: Codable
{
    let id: Int64?                  // 1
    let name: String?               // "Birthday"
    let lastmodified: String?       // "2018-08-23 15:30:43"
    let url_name: String?           // "birthday"
    let counter: Int64?             // 8
    let url: String?                // "https:…"
}

/**
 A struct for decoding JSON returned by kPiwigoTagsGetAdminList:
 All members are optional in case they are missing from the data.
*/
struct TagProperties4Admin: Codable
{
    let id: String?                 // 1 (String instead of Int)
    let name: String?               // "Birthday"
    let lastmodified: String?       // "2018-08-23 15:30:43"
    let url_name: String?           // "birthday"
}
