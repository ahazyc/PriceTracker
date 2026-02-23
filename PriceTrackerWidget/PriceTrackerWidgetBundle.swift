//
//  PriceTrackerWidgetBundle.swift
//  PriceTrackerWidget
//
//  Created by August Zheng on 2026-02-22.
//

import WidgetKit
import SwiftUI

@main
struct PriceTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        PriceTrackerWidget()
        PriceTrackerWidgetControl()
    }
}
