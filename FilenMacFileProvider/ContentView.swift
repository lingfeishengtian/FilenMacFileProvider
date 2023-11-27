//
//  ContentView.swift
//  FilenMacFileProvider
//
//  Created by Hunter Han on 11/26/23.
//

import SwiftUI
import FileProvider

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button("meow") {
                NSFileProviderManager.add(NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("io.filen.app.FilenMacFileProvider.FileProviderExt"), displayName: "Filen"), completionHandler: { error in
                    print(error)
                })
            }
            Button("demeow") {
                NSFileProviderManager.removeAllDomains {error in
                    print(error)
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
