//
//  FermentrackManager.swift
//  FermentrackTools
//
//  Created by Corbin Dunn on 10/28/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation

class FermentrackProcessManager {
    var lastError: String?
    
    // fermentrackHomeURL will be set by another thread via the XPC service; we serialize this on the queue to avoid any race conditions via a public method
    private var fermentrackHomeURL: URL? {
        didSet {
            // Save the value
            UserDefaults.standard.set(fermentrackHomeURL, forKey: fermentrackHomeURLKey)
        }
    }

    
    private let apacheServerRootURL: URL!
    private let fermentrackHomeURLKey = "FermentrackBasePath"
    // Explictly NOT concurrent queue so we can serialize access to work
    private var processManagerQueue = DispatchQueue(label: "com.redwoodmonkey.ProcessManager", attributes: [], autoreleaseFrequency:.inherit, target: nil)


    init() {
        // Use the previous fermentrack home location; it might not exist yet
        fermentrackHomeURL = UserDefaults.standard.url(forKey: fermentrackHomeURLKey)
        
        apacheServerRootURL = FileManager.default.temporaryDirectory.appendingPathComponent("fermentrack_apache", isDirectory: true)
        // Ensure the directory exists
        do {
            try FileManager.default.createDirectory(at: apacheServerRootURL, withIntermediateDirectories: true, attributes: [:])
        } catch {
            // If it exists, that is okay, ignore errors
        }
        
        // The first pass will synchronously start stuff up, if we are properly setup
        attemptSetup()
        doAsyncProcessWork()
    }
    
    private func doAsyncProcessWork() {
        // Do the work and then async check again one second later
        doProcessWork()
        processManagerQueue.asyncAfter(deadline: .now() + 1) {
            self.doAsyncProcessWork()
        }
    }
    
    public func setFermentrackHomeURL(url: URL) {
        processManagerQueue.async(flags: .barrier) {
            self.fermentrackHomeURL = url
            self.attemptSetup()
        }
    }
    
    public func getFermentrackHomeURL() -> URL? {
        return self.fermentrackHomeURL
    }
    
    private func makeRedisProcess() -> Process {
        let redisServerURL = fermentrackHomeURL!.appendingPathComponent("redis/redis-server")
        let redisConfURL = fermentrackHomeURL!.appendingPathComponent("redis/redis.conf")

        let redisProcess = Process()
        redisProcess.executableURL = redisServerURL
        redisProcess.arguments = [redisConfURL.path]
        
        // maybe capture stderror/stdout?
        
        return redisProcess
    }

    private func isRedisAlive() -> Bool {
        do {
            let redisCliURL = fermentrackHomeURL!.appendingPathComponent("redis/redis-cli")
            let cliProcess = Process()
            cliProcess.executableURL = redisCliURL
            cliProcess.arguments = ["ping"]
            let outPipe = Pipe()
            cliProcess.standardOutput = outPipe
            
            try cliProcess.run()
            cliProcess.waitUntilExit()
            
            let outputHandle = outPipe.fileHandleForReading
            let data = outputHandle.readDataToEndOfFile() // Or just 5 bytes?
            let s = String(data: data, encoding: .ascii)
            if let s = s {
                if s.starts(with: "PONG") {
                    return true
                }
            }
        } catch {
            print("Error checking redis: ", error)
        }
        return false
    }

    private var redisProcess: Process?

    private func killLastRedis() {
        // if we don't have redis running, then we shouldn't have a g_redisProcess going...or it crashed
        if let p = redisProcess {
            if p.isRunning {
                p.terminate()
            }
        }
    }

    private func launchRedis() {
        redisProcess = makeRedisProcess()
        do {
            try redisProcess!.run()
        } catch {
            lastError = error.localizedDescription
        }
    }


    private var circusProcess: Process?

    private func isCircusAlive() -> Bool {
        if circusProcess != nil && circusProcess!.isRunning {
            return true
        }
        // TODO: We could do the following and look for:
        // python3 -m circus.circusctl --json --timeout 1 status
        // Timed out.
        
        // Or, we get a json response...
        // {"status": "ok", "time": 1572234050.587931, "statuses": {"Fermentrack": "active", "huey": "active", "processmgr": "active", "tilt-": "active"}, "id": "b0fee88e51414feba3a82f212ff06cb7"}

        return false
    }

    private func killExistingCircus() {
        // Just in case..
        // python3 -m circus.circusctl --json --timeout 1 quit
        do {
            let process = makeAndSetupPythonProcess()
            process.executableURL = fermentrackHomeURL!.appendingPathComponent("venv/bin/python3")
            process.arguments = ["-m", "circus.circusctl", "--json", "--timeout", "1", "quit"]
            try process.run()
            process.waitUntilExit()
        } catch {
            // ignore errors here
            print(error.localizedDescription)
        }
    }

    private func makeAndSetupPythonProcess() -> Process {
        let virtualEnvURL = fermentrackHomeURL!.appendingPathComponent("venv")
        
        // The python environment setup for circus/python
        var environmentPath = virtualEnvURL.appendingPathComponent("bin").path
        
        if let currentEnvPath = ProcessInfo.processInfo.environment["PATH"] {
            environmentPath = environmentPath + ":" + currentEnvPath
        }

        // The "fermentrack" sub directory should be our PYTHONPATH
        let fermentrackURL = fermentrackHomeURL!.appendingPathComponent("fermentrack")
        
        let process = Process()
        process.currentDirectoryURL = fermentrackURL
        process.environment = ["PYTHONPATH": fermentrackURL.path,
                                "VIRTUAL_ENV": virtualEnvURL.path,
                                "HOME": fermentrackHomeURL!.path,
                                "PATH": environmentPath,
                                "PWD": fermentrackURL.path,
                                "LC_ALL": "en_US.UTF-8",
                                "LANG": "en_US.UTF-8",]
        return process
    }
    
    private var circusIniFileURL: URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("fermentrack_mac_circus.ini")
    }
    
    private var circusIniFileIsUpdated = false
    // The ini file has a hardcoded PYTHON_PATH. We open up the ini file, modify it, and write it out to a temporary location and use that as our ini file
    private func updateCircusIniFileIfNecessary() throws {
        if circusIniFileIsUpdated {
            return
        }
        
        circusIniFileIsUpdated = true
        
        let circusIniFileTemplatePath = fermentrackHomeURL!.appendingPathComponent("fermentrack/circus.ini")
        let circusIniFileURL = self.circusIniFileURL
        let circusIniFile = try String(contentsOf: circusIniFileTemplatePath)
        
        // Totally not the best way to do this, but the easiest
        let pythonPath = fermentrackHomeURL!.appendingPathComponent("fermentrack").path
        let pythonPathIniFileLine = "PYTHONPATH = " + pythonPath
        let updatedCircusIniFile = circusIniFile.replacingOccurrences(of: "PYTHONPATH = /home/fermentrack/fermentrack", with: pythonPathIniFileLine)
        try updatedCircusIniFile.write(to: circusIniFileURL, atomically: true, encoding: .ascii)

    }
    
    private func launchCircus() {
        // Reset the global error variable
        circusProcess?.terminate()
        circusProcess = nil
        
        do {
            let process = makeAndSetupPythonProcess()
            process.executableURL = fermentrackHomeURL!.appendingPathComponent("venv/bin/circusd")
            process.arguments = [self.circusIniFileURL.path]
            try process.run()
            circusProcess = process;

        } catch {
            lastError = error.localizedDescription
        }
    }
    
    private func isWebServerAlive() -> Bool {
        // Basically, we are alive if the httpd.pid exists. we could check to make sure the process exists too, but it seems to go away even if i kill httpd
        return FileManager.default.fileExists(atPath: apacheServerRootURL.appendingPathComponent("httpd.pid").path)
    }

    private func setupWebServer() {
        do {
            let process = makeAndSetupPythonProcess()
            process.executableURL = self.fermentrackHomeURL!.appendingPathComponent("venv/bin/python3")
            process.arguments = ["manage.py", "runmodwsgi",  "--server-root=" + apacheServerRootURL.path, "--user", "_www", "--group", "_www"]
            try process.run()
//            process.waitUntilExit()
            // todo: loook for the following info:
//            Successfully ran command.
//            Server URL         : http://localhost:8000/
//            Server Root        : /var/tmp/testsetup
//            Server Conf        : /var/tmp/testsetup/httpd.conf
//            Error Log File     : /var/tmp/testsetup/error_log (warn)
//            Rewrite Rules      : /var/tmp/testsetup/rewrite.conf
//            Environ Variables  : /var/tmp/testsetup/envvars
//            Control Script     : /var/tmp/testsetup/apachectl
//            Request Capacity   : 5 (1 process * 5 threads)
//            Request Timeout    : 60 (seconds)
//            Startup Timeout    : 15 (seconds)
//            Queue Backlog      : 100 (connections)
//            Queue Timeout      : 45 (seconds)
//            Server Capacity    : 20 (event/worker), 20 (prefork)
//            Server Backlog     : 500 (connections)
//            Locale Setting     : en_US.UTF-8
            
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    private func runApacheCtl(withCommand command: String) {
        do {
              let process = makeAndSetupPythonProcess()
              process.executableURL = apacheServerRootURL.appendingPathComponent("apachectl")
              process.arguments = [command]
              try process.run()
              process.waitUntilExit()
          } catch {
              lastError = error.localizedDescription
          }
    }
    
    public var isWebServerRunning: Bool {
        get {
            return self.isWebServerAlive()
        }
    }
    
    public func startWebServer() {
        runApacheCtl(withCommand: "start")
    }

    public func stopWebServer() {
        runApacheCtl(withCommand: "stop")
    }

    public func restartWebServer() {
        runApacheCtl(withCommand: "restart")
    }
    
    private func attemptSetup() {
        if fermentrackHomeURL != nil {
            if isWebServerAlive() {
                // Maybe kill the server to force a reload?
                stopWebServer()
            }
            setupWebServer()
        }
    }
    
    private func doProcessWork() {
        
        if fermentrackHomeURL == nil {
            return // Not yet setup...
        }
        
        lastError = nil
        
        if (!isRedisAlive()) {
            killLastRedis()
            launchRedis()
        }
        
        if (lastError == nil && !isCircusAlive()) {
            killExistingCircus()
            launchCircus()
        }
        
        // Now start the server, if no errors
        if (lastError == nil && !isWebServerAlive()) {
            startWebServer()
        }
//
        if let lastError = lastError {
            print(lastError)
        }
    }
}
