import Foundation
import SwiftUI

class BulbService: ObservableObject {
    @Published var bulbIP: String?
    @Published var boxColor: Color = .red
    @Published var statusMessage: String = ""
    
    //Change Status Color
    func turnGreen() {
        boxColor = .green
    }
    func turnRed() {
        boxColor = .red
    }

    // Light On
    func lightOn() {
        guard let ip = bulbIP else {
            statusMessage = "Bulb not connected. Click on reconnect first ❌"
            print("Bulb not connected. Click on connect.")
            return
        }

//        let command = #"""
//        echo -n "{\"id\":1,\"method\":\"setState\",\"params\":{\"state\":true}}" | nc -u -w 1 \#(ip) 38899
//        """#
        
        let command = #"""
        echo -n "{\"id\":1,\"method\":\"setPilot\",\"params\":{\"sceneId\":11,\"dimming\":100}}" | nc -u -w 1 \(ip) 38899
        """#
        
        let output = runShellCommand(command)
        print("Command output: \(output)")
        statusMessage = "Light turned ON 💡"
    }
    
    // Light Off
    func lightOff() {
        guard let ip = bulbIP else {
            statusMessage = "Bulb not connected. Click on reconnect first ❌"
            print("Bulb not connected. Click on connect.")
            return
        }

        let command = #"""
        echo -n "{\"id\":1,\"method\":\"setState\",\"params\":{\"state\":false}}" | nc -u -w 1 \#(ip) 38899
        """#
        let output = runShellCommand(command)
        print("Command output: \(output)")
        statusMessage = "Light turned OFF 🌑"
    }

    // Connect to the bulb by scanning IPs through the network
    func connectBulb() {
        statusMessage = "Scanning for bulb on Wi-Fi... 🔍"
        
        let base = "192.168.1"
        let range = 2..<255
        let group = DispatchGroup()
        var foundIP: String?

        for i in range {
            let ip = "\(base).\(i)"
            group.enter()

            DispatchQueue.global().async {
                let testCommand = #"""
                echo -n "{\"id\":1,\"method\":\"getProp\",\"params\":[\"power\"]}" | nc -u -w 1 \#(ip) 38899
                """#
                let response = self.runShellCommand(testCommand)

                if response.contains("method") {
                    DispatchQueue.main.async {
                        foundIP = ip
                        self.bulbIP = ip
                        self.statusMessage = "Connected to bulb at IP: \(ip) ✅"
                        print("Found bulb at IP: \(ip)")
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if foundIP != nil {
                print("Bulb connected")
                self.turnGreen()
            } else {
                print("Bulb not found.")
                self.turnRed()
                self.statusMessage = "Bulb not found on network ❌"
            }
        }
    }

    // Shell command runner
    func runShellCommand(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.arguments = ["-c", command]
        process.launchPath = "/bin/zsh"

        do {
            try process.run()
        } catch {
            print("Failed to run shell command: \(error)")
            return ""
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}
