//
//  main.swift
//  FermentrackManager
//
//  Created by Corbin Dunn on 10/26/19.
//  Copyright © 2019 Corbin Dunn. All rights reserved.
//

import Foundation


func makeRedisProcess() -> Process {
    let redisServerURL =  Bundle.main.url(forAuxiliaryExecutable: "redis-server")!
    let redisConfURL = Bundle.main.resourceURL!.appendingPathComponent("redis.conf")

    let redisProcess = Process()
    redisProcess.executableURL = redisServerURL
    redisProcess.arguments = [redisConfURL.path]
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
    let data = outputHandle.readDataToEndOfFile() // Or 5 bytes?
    let s = String(data: data, encoding: .ascii)
    if let s = s {
        if s.starts(with: "PONG") {
            return true
        }
    }
    return false
}

func launchRedis() {
    let redisProcess = makeRedisProcess()
    redisProcess.launch()
}


while (true) {
    
    if (!isRedisAlive()) {
        // Try to launch redis
        launchRedis()
    }
    
    Thread.sleep(forTimeInterval: 1.0)
    // just wait...
}

