//
//  FermentrackInstaller.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/30/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation
import AppKit
import ServiceManagement

extension NSApplication {
    func processEvents() {
        repeat {
            if let event = NSApp.nextEvent(matching: NSEvent.EventTypeMask.any, until: NSDate.distantPast, inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            } else {
                break;
            }
        } while true
    }
}

class FermentrackInstaller {
    
    private var installURL: URL
    private var statusHandler: ((NSAttributedString) -> Void)
    private var repoURL: URL
    
    convenience init() {
        self.init(installURL: AppDelegate.shared.fermentrackHomeURL!,
                  repoURL: AppDelegate.shared.fermentrackRepoURL,
                  statusHandler: { (NSAttributedString) in
            
        })
    }
    
    init(installURL: URL, repoURL: URL, statusHandler: @escaping (NSAttributedString) -> Void) {
        self.statusHandler = statusHandler
        self.repoURL = repoURL
        self.installURL = installURL
    }
    
    public func checkIfInstallDirectoryEmpty() -> Bool {
        if let contents = try? FileManager.default.contentsOfDirectory(at: self.installURL, includingPropertiesForKeys: [], options: []) {
            // Ignore hidden files
            for fileNameURL in contents {
                if fileNameURL.lastPathComponent.starts(with: ".") {
                    // Ignore
                } else {
                    return false;
                }
            }
        }
        return true
    }
    
    private func bold(_ s: String) -> NSAttributedString {
        let boldFont = NSFont.boldSystemFont(ofSize: 14)
        return NSAttributedString(string: s, attributes: [NSAttributedString.Key.font: boldFont])
    }
    
    private func printStatus(string: String) {
        statusHandler(NSAttributedString(string: string))
    }
    
    private func printError(string: String) {
        let s = NSAttributedString(string: string, attributes: [NSAttributedString.Key.foregroundColor: NSColor.red])
        statusHandler(s)

    }
    
    private func runCommand(executableURL: URL, arguments: [String]?, environment: [String: String]? = nil, currentDirectoryURL: URL? = nil) throws {
        let p = Process()
        p.executableURL = executableURL
        p.arguments = arguments
        let stdOutPipe = Pipe()
        p.standardOutput = stdOutPipe
        let stdErrPipe = Pipe()
        p.standardError = stdErrPipe
        p.environment = environment
        p.currentDirectoryURL = currentDirectoryURL
        
        let printDataFromFile = { (fileHandle: FileHandle) in
            if let string = String(data: fileHandle.availableData, encoding: .utf8) {
                if string.count > 0 {
                    RunLoop.main.perform {
                        self.printStatus(string: string)
                    }
                }
            }
        }
        
        stdOutPipe.fileHandleForReading.readabilityHandler = printDataFromFile
        stdErrPipe.fileHandleForReading.readabilityHandler = printDataFromFile
        
        try p.run()
        
        repeat {
            NSApp.processEvents()
        } while p.isRunning
        
        stdOutPipe.fileHandleForReading.readabilityHandler = nil
        stdErrPipe.fileHandleForReading.readabilityHandler = nil
        
        if p.terminationStatus != 0 {
            throw CustomError.withMessage("Non zero termination status!")
        }
    }
    
    private func makeHomeDirectory() throws {
        statusHandler(bold("Creating Fermentrack home directory\n"))
        printStatus(string: installURL.path)
        printStatus(string: "\n")
        NSApp.processEvents()
        try FileManager.default.createDirectory(at: installURL, withIntermediateDirectories: true, attributes: [:])
    }
    
    // return true if succeeded...false if failure
    private func cloneRepository() throws {
        statusHandler(bold("Cloning Fermentrack source\n"))
        try runCommand(executableURL: URL(fileURLWithPath: "/usr/bin/git"), arguments: ["clone", repoURL.absoluteString, fermentrackSourceURL.path, "--progress"])
    }
    
    private var virtualEnvURL: URL {
        return installURL.appendingPathComponent("venv")
    }
    
    private var fermentrackSourceURL: URL {
        return installURL.appendingPathComponent("fermentrack")
    }
    
    private func getPythonVirtualEnvironment() -> [String: String] {
        // The python environment setup for circus/python
        var environmentPath = virtualEnvURL.appendingPathComponent("bin").path
        
        if let currentEnvPath = ProcessInfo.processInfo.environment["PATH"] {
            environmentPath = environmentPath + ":" + currentEnvPath
        }
        
        return ["PYTHONPATH": installURL.path, // is this right?
                "VIRTUAL_ENV": virtualEnvURL.path,
                "PATH": environmentPath,
                "PWD": installURL.path,
                "LC_ALL": "en_US.UTF-8",
                "LANG": "en_US.UTF-8",]
    }

    private func setupPythonVenv() throws {
        statusHandler(bold("Setting up the python virtual environment directory\n"))
        let pythonURL = URL(fileURLWithPath: "/usr/local/bin/python3")
        try runCommand(executableURL: pythonURL, arguments: ["-m", "venv", virtualEnvURL.path])
        printStatus(string: "Done.\n")
    }
    
    private func setupPipRequirements() throws {
        let pipURL = virtualEnvURL.appendingPathComponent("bin/pip3")
        let requirementsFileURL = fermentrackSourceURL.appendingPathComponent("requirements_macos.txt")
        statusHandler(bold("Setting up Python venv requirements\n"))
        try runCommand(executableURL: pipURL, arguments: ["install", "-r", requirementsFileURL.path], environment: getPythonVirtualEnvironment())
        printStatus(string: "Done.\n")
    }
    
    private func makeSecretSettings() throws {
        statusHandler(bold("Running make_secretsettings.sh from the script repo\n"))
        let bashURL = URL(fileURLWithPath: "/bin/bash")
        let scriptFile = fermentrackSourceURL.appendingPathComponent("utils/make_secretsettings.sh")
        try runCommand(executableURL: bashURL, arguments: [scriptFile.path], environment: ["LC_CTYPE" : "C"])
        
        printStatus(string: "Done.\n")
    }
    
    private func runPython(arguments: [String]?) throws {
        let pythonURL = virtualEnvURL.appendingPathComponent("bin/python3")
        if !FileManager.default.fileExists(atPath: pythonURL.path) {
            throw CustomError.withMessage("No virtual env python setup at:" + pythonURL.path)
        }
        try runCommand(executableURL: pythonURL, arguments: arguments, environment: getPythonVirtualEnvironment(), currentDirectoryURL: fermentrackSourceURL)
    }
    
    private func doMigrate() throws {
        statusHandler(bold("Running manage.py migrate...\n"))
        try runPython(arguments: ["manage.py", "migrate"])
        printStatus(string: "Done.\n")
    }

    private func collectStatic() throws {
        statusHandler(bold("Running manage.py collectstatic...\n"))
        try runPython(arguments: ["manage.py", "collectstatic", "--noinput"])
        printStatus(string: "Done.\n")
    }
    
    private func installLaunchDaemon(named: String) throws {
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)
        try withUnsafeMutablePointer(to: &authItem) { (authItemPtr) in
            var authRights = AuthorizationRights(count: 1, items: authItemPtr)
            try withUnsafePointer(to: &authRights) { (authRightsPtr) in
                var authRef: AuthorizationRef? = nil
                try withUnsafeMutablePointer(to: &authRef) { (authRefPtr) in
                    
                    let authFlags: AuthorizationFlags = [AuthorizationFlags.interactionAllowed, AuthorizationFlags.preAuthorize, AuthorizationFlags.extendRights]

                    let status = AuthorizationCreate(authRightsPtr, nil /*kAuthorizationEmptyEnvironment*/, authFlags, authRefPtr)

                    if status != errAuthorizationSuccess {
                        throw CustomError.withMessage("Failed to create authorization ref, error code: \(status)")
                    }
                    
                    var cfError: Unmanaged<CFError>? = nil
                    try withUnsafeMutablePointer(to: &cfError, { (cfErrorPtr) in
                        let result = SMJobBless(kSMDomainSystemLaunchd, named as CFString, authRefPtr.pointee, cfErrorPtr)
                        if (!result) {
                            throw cfErrorPtr.pointee!.takeUnretainedValue() // Value was already retained/autoreleased, i assume.
                        }
            
                    })
                }
            }
        }
    }
    
    public func installRedis() throws {
        statusHandler(bold("Installing redis...\n"))

        let redisCliURL =  Bundle.main.url(forAuxiliaryExecutable: "redis-cli")!
        let redisServerURL = Bundle.main.url(forAuxiliaryExecutable: "redis-server")!
        let redisConfURL = Bundle.main.resourceURL!.appendingPathComponent("redis.conf")
        
        let redisDestURL = self.installURL.appendingPathComponent("redis")
        let redisDestCliURL = redisDestURL.appendingPathComponent("redis-cli")
        let redisDestServerURL = redisDestURL.appendingPathComponent("redis-server")
        let redisDestConfURL = redisDestURL.appendingPathComponent("redis.conf")
        
        try FileManager.default.createDirectory(at: redisDestURL, withIntermediateDirectories: true, attributes: [:])
        
        if !FileManager.default.fileExists(atPath: redisDestCliURL.path) {
            try FileManager.default.copyItem(at: redisCliURL, to: redisDestCliURL)
        } else {
            printStatus(string: "redis-cli seems to exist; not copying.\n")
        }
        if !FileManager.default.fileExists(atPath: redisDestServerURL.path) {
            try FileManager.default.copyItem(at: redisServerURL, to: redisDestServerURL)
        } else {
            printStatus(string: "redis-server seems to exist; not copying.\n")

        }
        if FileManager.default.fileExists(atPath: redisDestConfURL.path) {
            printStatus(string: "redis.conf exists, but overwriting it!\n")
            try FileManager.default.removeItem(at: redisDestConfURL)
            try FileManager.default.copyItem(at: redisConfURL, to: redisDestConfURL)
        } else {
            try FileManager.default.copyItem(at: redisConfURL, to: redisDestConfURL)
        }
        
        printStatus(string: "Done.\n")
    }
    
    public func installProcessManagerDaemon() throws {
        statusHandler(bold("Installing Process Manager (a system launch daemon which requires privileges)\n"))
        NSApp.processEvents()
        let name = "com.redwoodmonkey.FermentrackProcessManager"
        try installLaunchDaemon(named: name)
        printStatus(string: "Done.\n")
    }
    
    private func setupProcessManager() throws {
        statusHandler(bold("Setting up the Process Manager with the installation directory and user name\n"))
        AppDelegate.shared.fermentrackHomeURL = self.installURL
        AppDelegate.shared.isProcessManagerSetup = true
        printStatus(string: "Done.\n")
    }
    
    public func doFullAutomatedInstall(withProcessManager: Bool) -> Bool {
        
        do {
            if withProcessManager {
                try installProcessManagerDaemon()
                AppDelegate.shared.startServerConnection()
            } else {
                statusHandler(bold("Process Manager already installed.\n"))
            }
            try makeHomeDirectory()
            try installRedis()
            try cloneRepository()
            try setupPythonVenv()
            try setupPipRequirements()
            try makeSecretSettings()
            try doMigrate()
            try collectStatic()
            try setupProcessManager()

            statusHandler(bold("Full automated install succeeded!\n"))
            return true
        } catch {
            printError(string: "ERROR: " + error.localizedDescription)
            printError(string: "\nTry deleting the contents of the installation directory and trying again, or customizing the install directory and attempting another full automated install.\n\nThe current install directory is: \(installURL.path)\n")
            return false
        }
        
    }
    
    
}
