//
//  DateFormatSelectorViewController+UITableViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: UITableViewDelegate Methods
extension DateFormatSelectorViewController: UITableViewDelegate
{
    // MARK: - Headers
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 { return 20 }
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 { return UIView() }
        return nil
    }
    
    
    // MARK: - Year/Month/Day Reordering
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Show reorder control if necessary
        cell.showsReorderControl = isDragEnabled ? self.tableView(tableView, canMoveRowAt: indexPath) : false
    }
    
    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                   toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        // Prevent rows from being moved to Separator section
        guard let proposedSection = DateSection(rawValue: proposedDestinationIndexPath.section),
              proposedSection != .separator
        else { return sourceIndexPath }
        
        // Can only move to first row of Year, Month, Day sections
        if proposedDestinationIndexPath.row != 0 {
            return sourceIndexPath
        }
        
        return proposedDestinationIndexPath
    }
    
    
    // MARK: - Year/Month/Day Format Selection
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let section = dateSections[indexPath.section]
        switch section {
        case DateSection.year, DateSection.month, DateSection.day:
            return indexPath.row != 0
        default :
            return false
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch dateSections[indexPath.section] {
        case .year:
            switch indexPath.row {
            case 1 /* yy option */ :
                dateFormats[indexPath.section] = .year(format: .yy)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.isUserInteractionEnabled = true
                
            case 2 /* yyyy option */ :
                dateFormats[indexPath.section] = .year(format: .yyyy)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.isUserInteractionEnabled = true
                
            default:
                break
            }
            
        case .month:
            switch indexPath.row {
            case 1 /* MM option */ :
                dateFormats[indexPath.section] = .month(format: .MM)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.isUserInteractionEnabled = true
                tableView.cellForRow(at: IndexPath(row: 3, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 3, section: indexPath.section))?.isUserInteractionEnabled = true
                
            case 2 /* MMM option */ :
                dateFormats[indexPath.section] = .month(format: .MMM)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.isUserInteractionEnabled = true
                tableView.cellForRow(at: IndexPath(row: 3, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 3, section: indexPath.section))?.isUserInteractionEnabled = true
                
            case 3 /* MMMM option */ :
                dateFormats[indexPath.section] = .month(format: .MMMM)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.isUserInteractionEnabled = true
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.isUserInteractionEnabled = true
                
            default:
                break
            }
            
        case .day:
            switch indexPath.row {
            case 1 /* dd option */ :
                dateFormats[indexPath.section] = .day(format: .dd)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.isUserInteractionEnabled = true
                tableView.cellForRow(at: IndexPath(row: 3, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 3, section: indexPath.section))?.isUserInteractionEnabled = true
                tableView.cellForRow(at: IndexPath(row: 4, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 4, section: indexPath.section))?.isUserInteractionEnabled = true
                
            case 2 /* ddd option */ :
                dateFormats[indexPath.section] = .day(format: .ddd)
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.isUserInteractionEnabled = true
                tableView.cellForRow(at: IndexPath(row: 3, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 3, section: indexPath.section))?.isUserInteractionEnabled = true
                tableView.cellForRow(at: IndexPath(row: 4, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 4, section: indexPath.section))?.isUserInteractionEnabled = true
                
            case 3 /* EEE option */ :
                dateFormats[indexPath.section] = .day(format: .EEE)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.isUserInteractionEnabled = true
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.isUserInteractionEnabled = true
                tableView.cellForRow(at: IndexPath(row: 4, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 4, section: indexPath.section))?.isUserInteractionEnabled = true
                
            case 4 /* EEEE option */ :
                dateFormats[indexPath.section] = .day(format: .EEEE)
                tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                tableView.cellForRow(at: indexPath)?.isUserInteractionEnabled = false
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.isUserInteractionEnabled = true
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.isUserInteractionEnabled = true
                tableView.cellForRow(at: IndexPath(row: 3, section: indexPath.section))?.accessoryType = .none
                tableView.cellForRow(at: IndexPath(row: 3, section: indexPath.section))?.isUserInteractionEnabled = true
                
            default:
                break
            }
            
        default:
            break
        }
        
        // Update example
        updateExample()
    }
}
