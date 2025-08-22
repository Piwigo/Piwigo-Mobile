//
//  TimeFormatSelectorViewController+UITableViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: - UITableViewDelegate Methods
extension TimeFormatSelectorViewController: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return TableViewUtilities.rowHeight
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch TimeSection(rawValue: indexPath.section) {
        case .hour, .minute, .second:
            return indexPath.row != 0
        default :
            return false
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch TimeSection(rawValue: indexPath.section) {
        case .hour:
            switch indexPath.row {
            case 1 /* hha option */ :
                timeFormats[indexPath.section] = .hour(format: .hha)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.isUserInteractionEnabled = true
                
            case 2 /* HH option */ :
                timeFormats[indexPath.section] = .hour(format: .HH)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.isUserInteractionEnabled = true
                
            default:
                break
            }
            
        case .minute:
            switch indexPath.row {
            case 1 /* mm option */ :
                timeFormats[indexPath.section] = .minute(format: .mm)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
            
            default:
                break
            }
            
        case .second:
            switch indexPath.row {
            case 1 /* ss option */ :
                timeFormats[indexPath.section] = .second(format: .ss)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.isUserInteractionEnabled = true
                
            case 2 /* ssSSS option */ :
                timeFormats[indexPath.section] = .second(format: .ssSSS)
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.isUserInteractionEnabled = true
                
            default:
                break
            }
            
        default:
            break
        }
        
        // Update header
        updateExample()
    }
}
