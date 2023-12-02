//
//  ContentView.swift
//  FilenMacFileProvider
//
//  Created by Hunter Han on 11/26/23.
//

import SwiftUI
import FileProvider

let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("io.filen.app.FilenMacFileProvider.FileProviderExt"), displayName: "Filen")

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button("refresh") {
                NSFileProviderManager(for: domain)!.signalEnumerator(for: NSFileProviderItemIdentifier.workingSet, completionHandler: { err in
                    print(err)
                })
            }
            Button("add provider") {
                NSFileProviderManager.add(domain, completionHandler: { error in
                    print(error)
                })
            }
            Button("remove all") {
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
