//
//  FermentrackInstaller.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/30/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation
import AppKit


class FermentrackInstaller {
    
    private var installURL: URL
    private var statusHandler: ((NSAttributedString) -> Void)
    private var repoURL: URL
    
    init(installURL: URL, repoURL: URL, statusHandler: @escaping (NSAttributedString) -> Void) {
        self.statusHandler = statusHandler
        self.repoURL = repoURL
        self.installURL = installURL
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
            repeat {
                if let event = NSApp.nextEvent(matching: NSEvent.EventTypeMask.any, until: NSDate.distantPast, inMode: .default, dequeue: true) {
                    NSApp.sendEvent(event)
                } else {
                    break;
                }
            } while true
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
        statusHandler(bold("Setting up Python virtual environment directory\n"))
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
    
    public func startInstall() {
        
        do {
            try makeHomeDirectory()
            try cloneRepository()
            try setupPythonVenv()
            try setupPipRequirements()
            try makeSecretSettings()
            try doMigrate()
            try collectStatic()
                    
        } catch {
            printError(string: "ERROR: " + error.localizedDescription)
        }
        
        
    }
    
    
}
