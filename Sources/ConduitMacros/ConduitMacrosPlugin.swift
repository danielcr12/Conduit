// ConduitMacrosPlugin.swift
// Conduit
//
// Compiler plugin registration for Conduit macros.

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ConduitMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        GenerableMacro.self,
        GuideMacro.self,
    ]
}
