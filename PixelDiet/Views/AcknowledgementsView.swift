import SwiftUI

/// Third-party notices required by the licenses of bundled open-source code.
struct AcknowledgementsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(String(localized: "Acknowledgements"))
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(String(localized: "Done")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Text(String(localized: "PixelDiet uses the following open-source software."))
                .foregroundStyle(.secondaryText)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("libwebp")
                        .font(.headline)
                    if let url = URL(string: "https://chromium.googlesource.com/webm/libwebp") {
                        Link("chromium.googlesource.com/webm/libwebp", destination: url)
                            .font(.caption)
                    }
                    Text(Self.libwebpLicense)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(24)
        .frame(width: 560, height: 520)
    }

    private static let libwebpLicense = """
    Copyright (c) 2010, Google Inc. All rights reserved.

    Redistribution and use in source and binary forms, with or without \
    modification, are permitted provided that the following conditions are met:

      * Redistributions of source code must retain the above copyright notice, \
    this list of conditions and the following disclaimer.

      * Redistributions in binary form must reproduce the above copyright notice, \
    this list of conditions and the following disclaimer in the documentation \
    and/or other materials provided with the distribution.

      * Neither the name of Google nor the names of its contributors may be used \
    to endorse or promote products derived from this software without specific \
    prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" \
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE \
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE \
    ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE \
    LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR \
    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF \
    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS \
    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN \
    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) \
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE \
    POSSIBILITY OF SUCH DAMAGE.

    Additional IP Rights Grant (Patents): Google grants a perpetual, worldwide, \
    non-exclusive, no-charge, royalty-free, irrevocable patent license for its \
    implementations of the WebM codecs, as described in the PATENTS file \
    distributed with libwebp.
    """
}
