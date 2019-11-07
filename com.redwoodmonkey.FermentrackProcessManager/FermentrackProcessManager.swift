//
//  FermentrackManager.swift
//  FermentrackTools
//
//  Created by Corbin Dunn on 10/28/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation

class LocalProcessManagerClient : NSObject, FermentrackProcessManagerClientProtocol {
    func webServerRunningChanged(_ newValue: Bool) {
        
    }
    func handleError(_ error: Error) {
        
    }
}

class FermentrackProcessManager {
    
    // MARK: Client notification list
    private var clients = Set<LocalProcessManagerClient>()
    
    public func addClient(_ client: LocalProcessManagerClient) {
        clients.insert(client)
    }
    
    public func removeClient(_ client: LocalProcessManagerClient) {
        clients.remove(client)
    }
    
    private func notifyClients() {
        let value = self.isWebServerRunning
        for client in clients {
            client.webServerRunningChanged(value)
        }
    }
    
    // MARK: User default keys
    private let fermentrackHomeURLKey = "FermentrackBasePath"
    private let fermentrackShouldReloadOnChangesKey = "FermentrackShouldReloadOnChanges"
    private let webServerManuallyStoppedKey = "webServerManuallyStopped"
    private let apacheUserKey = "apacheUser"
    private let fermentrackIsSetupCompleteKey = "isSetupComplete"

    // MARK: Properties
    
    // fermentrackHomeURL will be set by another thread via the XPC service; we serialize this on the queue to avoid any race conditions via a public method. Reading should be okay.
    var fermentrackHomeURL: URL? {
        willSet {
            UserDefaults.standard.set(newValue, forKey: fermentrackHomeURLKey)
        }
    }
    
    var webServerManuallyStopped = false {
        willSet {
            UserDefaults.standard.set(newValue, forKey: webServerManuallyStoppedKey)
        }
    }
    
    fileprivate var apacheUser: String? {
        willSet {
            UserDefaults.standard.set(newValue, forKey: apacheUserKey)
        }
    }
    fileprivate let apacheGroup = "staff"

    private var apacheServerRootURL: URL? {
        get {
            // This would be ideal, however, I found that mod_wsgi does not handle paths with spaces in the names, and causes failures that stumped me for a bit.
            // So, I have no other choice than to go with a temp location.
            return URL(fileURLWithPath: "/var/tmp/fermentrack_apache")
//            return fermentrackHomeURL?.appendingPathComponent("apache")
        }
    }
    
    public var shouldReloadOnChanges: Bool {
        didSet {
            UserDefaults.standard.set(shouldReloadOnChanges, forKey: fermentrackShouldReloadOnChangesKey)
            processManagerQueue.async {
                self.asyncUpdateShouldReloadOnChanges()
            }
        }
    }
    
    public var isSetupComplete: Bool = false {
        didSet {
            UserDefaults.standard.set(isSetupComplete, forKey: fermentrackIsSetupCompleteKey)
        }
    }
    
    public func mark(isSetupComplete: Bool) {
        processManagerQueue.async {
            // Setting this to false may leave stuff running, so we attempt some cleanup
            if self.isSetupComplete {
                if self.isWebServerRunning {
                    try? self._stopWebServer()
                }
            }
            self.isWebServerSetup = false // Always reset this
            self.isSetupComplete = isSetupComplete
            self.doProcessWork()
        }
    }
        
    private func asyncUpdateShouldReloadOnChanges() {
        if isWebServerRunning {
            try? _stopWebServer()
        }
        isWebServerSetup = false
        doProcessWork()
    }
    
    // Explictly NOT concurrent queue so we can serialize access to work
    private var processManagerQueue = DispatchQueue(label: "com.redwoodmonkey.ProcessManager", attributes: [], autoreleaseFrequency:.inherit, target: nil)
    
    var termDispatchSourceSignal: DispatchSourceSignal
    
    // MARK: Init

    init() {
        fermentrackHomeURL = UserDefaults.standard.url(forKey: fermentrackHomeURLKey)
        shouldReloadOnChanges = UserDefaults.standard.bool(forKey: fermentrackShouldReloadOnChangesKey)
        webServerManuallyStopped = UserDefaults.standard.bool(forKey: webServerManuallyStoppedKey)
        apacheUser = UserDefaults.standard.string(forKey: apacheUserKey)
        isSetupComplete = UserDefaults.standard.bool(forKey: fermentrackIsSetupCompleteKey)

        // watch for sigterm to kill our processes
        termDispatchSourceSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: processManagerQueue)
        termDispatchSourceSignal.setEventHandler {
            self.cleanupAndExit()
        }
        termDispatchSourceSignal.activate()
        
        // The first pass will synchronously start stuff up right now, if we are properly setup
        doProcessWorkAndRepeat()
    }
    
    private func cleanupAndExit() {
        try? _stopWebServer()
        redisProcess?.terminate()   
        circusProcess?.terminate()
        exit(123)
    }
    
    private func doProcessWorkAndRepeat() {
        // Do the work and then check again; how soon depends on if we are fully setup or not
        doProcessWork()
        
        // Check every second when not setup and every 30 seconds when we are setup
        let checkTime: DispatchTime = DispatchTime.now() + (isSetupProperly() ? 1 : 30)
        processManagerQueue.asyncAfter(deadline: checkTime) {
            self.doProcessWorkAndRepeat()
        }
    }
    
    private func syncSetFermentrackHomeURL(url: URL, userName: String) {
        // stop the old process(es) first
        updateIsWebServerRunning()
        if isWebServerRunning {
            try? _stopWebServer()
        }
        
        killExistingCircus()

        // update our state that the setup is based on and mark that we aren't setup again
        self.apacheUser = userName
        self.fermentrackHomeURL = url
        isWebServerSetup = false
        
        doProcessWork()
    }
    
    public func setFermentrackHomeURL(url: URL, userName: String) {
        processManagerQueue.async(flags: .barrier) {
            self.syncSetFermentrackHomeURL(url: url, userName: userName)
        }
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
            cliProcess.arguments = ["--pipe-timeout", "1", "ping"]
            let outPipe = Pipe()
            cliProcess.standardOutput = outPipe
            
            try cliProcess.run()
            // This times out after 1 second
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
    
    private func launchRedis() throws {
        redisProcess = makeRedisProcess()
        try redisProcess!.run()
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
        guard fermentrackHomeURL != nil else { return }
        // Just in case..
        // python3 -m circus.circusctl --json --timeout 1 quit
        // This will error/log, which is expected.
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
        // Now the parent, which might be nil
        circusProcess?.terminate()
        circusProcess = nil
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
    
    // The ini file has a hardcoded PYTHON_PATH. We open up the ini file, modify it, and write it out to a temporary location and use that as our ini file
    private func updateCircusIniFile() throws {
        let circusIniFileTemplatePath = fermentrackHomeURL!.appendingPathComponent("fermentrack/circus.ini")
        let circusIniFileURL = self.circusIniFileURL
        let circusIniFile = try String(contentsOf: circusIniFileTemplatePath)
        
        // Totally not the best way to do this, but the easiest
        let pythonPath = fermentrackHomeURL!.appendingPathComponent("fermentrack").path
        let pythonPathIniFileLine = "PYTHONPATH = " + pythonPath
        let updatedCircusIniFile = circusIniFile.replacingOccurrences(of: "PYTHONPATH = /home/fermentrack/fermentrack", with: pythonPathIniFileLine)
        try updatedCircusIniFile.write(to: circusIniFileURL, atomically: true, encoding: .ascii)
        
    }
    
    private func launchCircus() throws {
        try updateCircusIniFile()
        let process = makeAndSetupPythonProcess()
        process.executableURL = fermentrackHomeURL!.appendingPathComponent("venv/bin/circusd")
        process.arguments = [self.circusIniFileURL.path]
        try process.run()
        circusProcess = process;
    }
    
    var isWebServerRunning: Bool = false {
        didSet (oldValue) {
            if (oldValue != isWebServerRunning) {
                notifyClients()
            }
        }
    }
    
    private func updateIsWebServerRunning() {
        isWebServerRunning = getIsWebServerAlive()
    }
    
    private func getIsWebServerAlive() -> Bool {
        // Basically, we are alive if the httpd.pid exists. we could check to make sure the process exists too, but it seems to go away even if i kill httpd
        if let apacheServerRootURL = apacheServerRootURL {
            return FileManager.default.fileExists(atPath: apacheServerRootURL.appendingPathComponent("httpd.pid").path)
        }
        return false
    }
    
    private func errorFromString(_ s: String) -> NSError {
        return NSError(domain: "com.redwoodmonkey", code: 0, userInfo: [NSLocalizedDescriptionKey: s])
    }
    
    private func setupWebServer() throws {
        let attributes: [FileAttributeKey:Any] = [FileAttributeKey.groupOwnerAccountName: apacheGroup, FileAttributeKey.ownerAccountName: apacheUser!]
        
        try FileManager.default.createDirectory(at: apacheServerRootURL!, withIntermediateDirectories: true, attributes: attributes)
        // Not sure we need this; I was originally trying to run as the _www user/group and had permission issues when installing into areas that the current user can read/write
//        try FileManager.default.setAttributes(attributes, ofItemAtPath: self.fermentrackHomeURL!.path)
                    
        let process = makeAndSetupPythonProcess()
        process.executableURL = self.fermentrackHomeURL!.appendingPathComponent("venv/bin/python3")
        process.arguments = ["manage.py", "runmodwsgi",  "--server-root=" + apacheServerRootURL!.path, "--user", apacheUser!, "--group", apacheGroup, "--setup-only"]
        if shouldReloadOnChanges {
            process.arguments!.append("--reload-on-changes")
        }
//        let stdOutPipe = Pipe()
//        p.standardOutput = stdOutPipe
        let stdErrPipe = Pipe()
        process.standardError = stdErrPipe
        
        let printDataFromFile = { (fileHandle: FileHandle) in
            if let string = String(data: fileHandle.availableData, encoding: .utf8) {
                if string.count > 0 {
                    self.processManagerQueue.async {
                        self.isWebServerSetup = false
                        self.handleError(self.errorFromString(string))
                    }
                }
            }
        }
        
//        stdOutPipe.fileHandleForReading.readabilityHandler = printDataFromFile
        stdErrPipe.fileHandleForReading.readabilityHandler = printDataFromFile
        
        try process.run()
        isWebServerSetup = true // will get set to false on a background thread..
        process.waitUntilExit() // wait for the setup to finish and return
        stdErrPipe.fileHandleForReading.readabilityHandler = nil
        
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
        
    }
    
    private func runApacheCtl(withCommand command: String) throws {
        guard fermentrackHomeURL != nil else { return }
        if let rootURL = apacheServerRootURL {
            let process = makeAndSetupPythonProcess()
            process.executableURL = rootURL.appendingPathComponent("apachectl")
            process.arguments = [command]
            try process.run()
            process.waitUntilExit()
            // Give it a brief moment to startup
            Thread.sleep(forTimeInterval: TimeInterval(0.5))
        }
    }
        
    private func asyncStartWebServer() {
        webServerManuallyStopped = false
        isWebServerSetup = false
        doProcessWork()
    }
    
    func startWebServer() {
        processManagerQueue.async {
            self.asyncStartWebServer()
        }
    }
    
    private func asyncStopWebServer() {
        do {
            try _stopWebServer()
            webServerManuallyStopped = true
            updateIsWebServerRunning()
        } catch {
            handleError(error)
        }
    }
    
    func stopWebServer()  {
        processManagerQueue.async {
            self.asyncStopWebServer()
        }
    }
    
    func restartWebServer()  {
        do {
            try _restartWebServer()

        } catch {
            handleError(error)
        }
    }
    
    private func startWebServerIfNotManuallyStopped() throws {
        if !webServerManuallyStopped {
            try _startWebServer()
        }
    }
    
    private func _startWebServer() throws {
        try runApacheCtl(withCommand: "start")
        updateIsWebServerRunning()
    }
    
    private func _stopWebServer() throws {
        try runApacheCtl(withCommand: "stop")
    }
    
    private func _restartWebServer() throws {
        try runApacheCtl(withCommand: "restart")
    }
    
    private func attemptToSetupWebServer() {
        if isSetupProperly() && !isWebServerSetup {
            do {
                try setupWebServer()
            } catch {
                handleError(error)
            }
        }
    }
    
    private var isWebServerSetup = false
    private func isSetupProperly() -> Bool {
        if fermentrackHomeURL != nil && apacheUser != nil && isSetupComplete {
            return true
        }
        return false
    }
    
    private func doProcessWork() {
        do {
            if !isSetupProperly() {
                throw errorFromString("Not setup!, url:\(fermentrackHomeURL?.path ?? "nil"), apacheUser:\(apacheUser ?? "nil")")
            }
            
            if (!isWebServerSetup) {
                attemptToSetupWebServer()
            }

            if (!isRedisAlive()) {
                killLastRedis()
                try launchRedis()
            }
            
            if (!isCircusAlive()) {
                killExistingCircus()
                try launchCircus()
            }
            
            // Now start the server, if no errors
            updateIsWebServerRunning()
            if (!webServerManuallyStopped && !isWebServerRunning) {
                try _startWebServer()
            }
            //
        } catch {
            handleError(error)
        }
    }
    
    fileprivate func handleError(_ error: Error) {
        print("ERROR:" + error.localizedDescription)
        for client in clients {
            client.handleError(error)
        }
    }
}


