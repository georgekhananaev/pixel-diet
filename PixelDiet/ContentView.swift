//
//  ContentView.swift
//  PixelDiet
//
//  Created by George Khananaev on 3/15/26.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: PixelDietDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(PixelDietDocument()))
}
