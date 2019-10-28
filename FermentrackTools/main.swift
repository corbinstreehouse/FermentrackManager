//
//  main.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/26/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation

// TODO: How do I want to get the locations into here?
let g_defaultFermentrackBasePathKeyName = "FermentrackBasePath"


func makeRedisProcess() -> Process {
    let redisServerURL =  Bundle.main.url(forAuxiliaryExecutable: "redis-server")!
    let redisConfURL = Bundle.main.resourceURL!.appendingPathComponent("redis.conf")

    let redisProcess = Process()
    redisProcess.executableURL = redisServerURL
    redisProcess.arguments = [redisConfURL.path]
    
    // maybe capture stderror/stdout?
    
    return redisProcess
}

func isRedisAlive() -> Bool {
    let redisCliURL =  Bundle.main.url(forAuxiliaryExecutable: "redis-cli")!
    let cliProcess = Process()
    cliProcess.executableURL = redisCliURL
    cliProcess.arguments = ["ping"]
    let outPipe = Pipe()
    cliProcess.standardOutput = outPipe
    
    try? cliProcess.run()
    cliProcess.waitUntilExit()
    
    let outputHandle = outPipe.fileHandleForReading
    let data = outputHandle.readDataToEndOfFile() // Or just 5 bytes?
    let s = String(data: data, encoding: .ascii)
    if let s = s {
        if s.starts(with: "PONG") {
            return true
        }
    }
    return false
}

var g_redisProcess: Process?
var g_redisError: String?

func killLastRedis() {
    // if we don't have redis running, then we shouldn't have a g_redisProcess going...or it crashed
    if let p = g_redisProcess {
        if p.isRunning {
            p.terminate()
        }
    }
}

func launchRedis() {
    g_redisProcess = makeRedisProcess()
    do {
        try g_redisProcess!.run()
    } catch {
        g_redisError = error.localizedDescription
    }
}


var g_circusProcess: Process?
var g_circusError: String?

func isCircusAlive() -> Bool {
    if g_circusProcess != nil && g_circusProcess!.isRunning {
        return true
    }
    // TODO: Do the following and look for:
    // python3 -m circus.circusctl --timeout 1
    // circusctl 0.15.0
    // Timed out.

    return false
}


func launchCircus() {
    // Reset the global error variable
    g_circusError = nil
    
    guard let fermentrackBasePath = UserDefaults.standard.string(forKey: g_defaultFermentrackBasePathKeyName) else {
        g_circusError = "Fermentrack base path location not set."
        return
    }
    
    let fermentrackBaseURL = URL(fileURLWithPath: fermentrackBasePath)
    
    if !FileManager.default.fileExists(atPath: fermentrackBasePath) {
        g_circusError = "Fermentrack base path at '\(fermentrackBasePath)' does not exist."
        return
    }
    let pythonPath = fermentrackBaseURL.appendingPathComponent("fermentrack").path
    let circusExecutableURL = fermentrackBaseURL.appendingPathComponent("venv/bin/circusd")
    // The ini file has a hardcoded PYTHON_PATH. We open up the ini file, modify it, and write it out to a temporary location and use that as our ini file
    
    let circusIniFileTemplatePath = fermentrackBaseURL.appendingPathComponent("fermentrack/circus.ini")
    let circusIniFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("fermentrack_mac_circus.ini")
    do {
        let circusIniFile = try String(contentsOf: circusIniFileTemplatePath)
        // Tottally not the best way to do this, but the easiest
        let pythonPathIniFileLine = "PYTHONPATH = " + pythonPath
        let updatedCircusIniFile = circusIniFile.replacingOccurrences(of: "PYTHONPATH = /home/fermentrack/fermentrack", with: pythonPathIniFileLine)
        try updatedCircusIniFile.write(to: circusIniFilePath, atomically: true, encoding: .ascii)
    } catch {
        g_circusError = "Error loading circus.ini file from '\(circusIniFileTemplatePath.path)'\n" + error.localizedDescription
        return
    }
    
    let process = Process()
    process.executableURL = circusExecutableURL
    process.arguments = [circusIniFilePath.path]
    // We have to setup a few things for circus to work correctly, such as the python virtual env
    var circusEnvPath = fermentrackBaseURL.appendingPathComponent("venv/bin").path
    if let currentEnvPath = ProcessInfo.processInfo.environment["PATH"] {
        circusEnvPath = circusEnvPath + ":" + currentEnvPath
    }
    process.currentDirectoryURL = fermentrackBaseURL
    process.environment = ["PYTHONPATH": pythonPath,
                           "VIRTUAL_ENV": fermentrackBaseURL.appendingPathComponent("venv").path,
                           "HOME": fermentrackBasePath, // circus.ini is based on this variable
                           "PATH": circusEnvPath,
                           "PWD": fermentrackBasePath]
    
    do {
        try process.run()
    } catch {
        g_circusError = error.localizedDescription
    }
    
    g_circusProcess = process;
}

// TODO: how to setup the default install location and get it to here?
UserDefaults.standard.register(defaults: [g_defaultFermentrackBasePathKeyName : "/Users/corbin/Projects/Fermentrack"])

while (true) {
    
    if (!isRedisAlive()) {
        // Try to launch redis
        killLastRedis()
        launchRedis()
    }
    
    if (!isCircusAlive()) {
        launchCircus()
    }
    
    // just wait...
    Thread.sleep(forTimeInterval: 1.0)
}

