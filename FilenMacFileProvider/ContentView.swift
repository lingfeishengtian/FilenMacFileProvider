//
//  ContentView.swift
//  FilenMacFileProvider
//
//  Created by Hunter Han on 11/26/23.
//

import SwiftUI
import FileProvider
import FilenSDK

let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("com.hunterhan.FilenMacFileProvider.FileProviderExt"), displayName: "Filen")

class MMKVCredentialChecker: ObservableObject {
    @Published var isAuthorized: Bool = false
    
    init() {
        self.isAuthorized = self.isLoggedIn()
    }
    
    func isLoggedIn () -> Bool {
        autoreleasepool {
            guard let loggedIn = MMKVInstance.shared.getFromKey(key: "isLoggedIn") as? Int, let apiKey = MMKVInstance.shared.getFromKey(key: "apiKey") as? String, let masterKeys = MMKVInstance.shared.getFromKey(key: "masterKeys") as? Array<String> else {
                return false
            }
            
            if (loggedIn == 0 || apiKey.count <= 0 || masterKeys.count <= 0) {
                return false
            }
            
            return true
        }
    }
    
    func retrieveConfigCredentials(filenClient: FilenClient) {
        guard let config = filenClient.config, let userId = config.userId, let defaultFolderUUID = config.baseFolderUUID else { return }
        
        MMKVInstance.shared.setKey(key: "isLoggedIn", value: 1)
        MMKVInstance.shared.setKey(key: "apiKey", value: config.apiKey)
        MMKVInstance.shared.setKey(key: "masterKeys", value: config.masterKeys)
        MMKVInstance.shared.setKey(key: "userId", value: userId)
        MMKVInstance.shared.setKey(key: "defaultDriveUUID:\(userId)", value: defaultFolderUUID)
        self.isAuthorized = isLoggedIn()
    }
}

struct ContentView: View {
    @StateObject var mmkvCredentialChecker = MMKVCredentialChecker()
    @State var username: String = ""
    @State var password: String = ""
    @State var twoFactor: String = ""
    
    @State var loading: Bool = false
    
    let filenClient = FilenClient(tempPath: FileManager.default.temporaryDirectory)
    
    var body: some View {
        VStack {
            Form {
                Text("Logged In: \(mmkvCredentialChecker.isAuthorized ? "Yes" : "No")")
                TextField("Username", text: $username)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                SecureField("Password", text: $password)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                TextField("Two Factor", text: $twoFactor)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.oneTimeCode)
                Button("Login") {
                    loading = true
                    Task {
                        try? await filenClient.login(email: username, password: password, twoFactorCode: twoFactor)
                        mmkvCredentialChecker.retrieveConfigCredentials(filenClient: filenClient)
                        loading = false
                    }
                }
                        
            }.overlay {
                if loading {
                    Color.black.opacity(0.3).overlay {
                        ProgressView()
                    }
                }
            }
            Button("Refresh File Provider") {
                NSFileProviderManager(for: domain)!.signalEnumerator(for: NSFileProviderItemIdentifier.workingSet, completionHandler: { err in
                    print(err)
                })
            }
            Button("Add File Provider") {
                NSFileProviderManager.add(domain, completionHandler: { error in
                    print(error)
                })
            }
            Button("Remove All File Providers") {
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
