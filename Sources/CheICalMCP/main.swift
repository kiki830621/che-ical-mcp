import Foundation
import MCP

// Entry point
let server = try await CheICalMCPServer()
try await server.run()
