//
//  Utils.swift
//  CLICommands
//
//  Created by Siarhei Ladzeika on 3.08.21.
//

import Foundation
@testable import SwiftCLI
import XCTest

extension CLI {

    static func capture(_ block: () -> Void) -> (String, String) {
        let out = CaptureStream()
        let err = CaptureStream()

        Term.stdout = out
        Term.stderr = err
        block()
        Term.stdout = WriteStream.stdout
        Term.stderr = WriteStream.stderr

        out.closeWrite()
        err.closeWrite()

        return (out.readAll(), err.readAll())
    }

}

extension CLI {
    static func createTester(commands: [Routable], description: String? = nil) -> CLI {
        return CLI(name: "tester", description: description, commands: commands)
    }
}

func pad(_ num: Int) -> String {
    var s = String(num)
    while s.count < 3 {
        s = "0" + s
    }
    return s
}

extension XCTestCase {

    func runCommand(_ cmd: Command, _ run: (CLI) -> Int32) -> (code: Int32, out: String, err: String) {

        var result: Int32 = 0
        let (out, err) = CLI.capture {
            let cli = CLI.createTester(commands: [cmd])
            result = run(cli)
        }

        return (result, out, err)
    }
}

extension Array {

    func appending(contentsOf source: Array) -> Array {
        var c = self
        c.append(contentsOf: source)
        return c
    }
}
