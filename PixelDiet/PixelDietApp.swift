//
//  PixelDietApp.swift
//  PixelDiet
//
//  Created by George Khananaev on 3/15/26.
//

import SwiftUI

@main
struct PixelDietApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: PixelDietDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
