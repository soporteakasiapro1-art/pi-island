/**
 * Test script to validate Unix Domain Socket connection to Pi Island.
 * Run with: node tests/test-bridge.mjs
 */
import * as net from "node:net";
import * as crypto from "node:crypto";

const SOCKET_PATH = "/tmp/pi-island.sock";
const SESSION_ID = crypto.randomUUID();

console.log("[Test] Connecting to Pi Island...");
console.log("[Test] Session ID:", SESSION_ID);

const client = net.createConnection(SOCKET_PATH, () => {
  console.log("[Test] Connected!");

  // Send handshake with sessionId
  const handshake = {
    type: "HANDSHAKE",
    payload: {
      pid: process.pid,
      project: process.cwd(),
      model: "claude-sonnet-4-20250514",
      sessionId: SESSION_ID,
    },
  };
  client.write(JSON.stringify(handshake) + "\n");
  console.log("[Test] Sent handshake");

  // Send initial status
  setTimeout(() => {
    const status = {
      type: "STATUS",
      payload: {
        state: "idle",
        sessionId: SESSION_ID,
      },
    };
    client.write(JSON.stringify(status) + "\n");
    console.log("[Test] Sent status: idle");
  }, 200);

  // Send user message
  setTimeout(() => {
    const message = {
      type: "MESSAGE",
      payload: {
        id: crypto.randomUUID(),
        role: "user",
        content: "Hello, can you help me with a coding task?",
        timestamp: Date.now(),
        sessionId: SESSION_ID,
      },
    };
    client.write(JSON.stringify(message) + "\n");
    console.log("[Test] Sent user message");
  }, 500);

  // Send thinking status
  setTimeout(() => {
    const status = {
      type: "STATUS",
      payload: {
        state: "thinking",
        sessionId: SESSION_ID,
      },
    };
    client.write(JSON.stringify(status) + "\n");
    console.log("[Test] Sent status: thinking");
  }, 800);

  // Send assistant response
  setTimeout(() => {
    const message = {
      type: "MESSAGE",
      payload: {
        id: crypto.randomUUID(),
        role: "assistant",
        content: "Of course! I'd be happy to help you with your coding task. What would you like to work on?",
        timestamp: Date.now(),
        sessionId: SESSION_ID,
      },
    };
    client.write(JSON.stringify(message) + "\n");
    console.log("[Test] Sent assistant message");
  }, 1200);

  // Send tool start
  setTimeout(() => {
    const toolStart = {
      type: "TOOL_START",
      payload: {
        tool: "bash",
        input: { command: "ls -la" },
        sessionId: SESSION_ID,
      },
    };
    client.write(JSON.stringify(toolStart) + "\n");
    console.log("[Test] Sent tool start: bash");
  }, 1500);

  // Send tool end
  setTimeout(() => {
    const toolEnd = {
      type: "TOOL_END",
      payload: {
        tool: "bash",
        success: true,
        sessionId: SESSION_ID,
      },
    };
    client.write(JSON.stringify(toolEnd) + "\n");
    console.log("[Test] Sent tool end");
  }, 2000);

  // Send back to idle
  setTimeout(() => {
    const status = {
      type: "STATUS",
      payload: {
        state: "idle",
        sessionId: SESSION_ID,
      },
    };
    client.write(JSON.stringify(status) + "\n");
    console.log("[Test] Sent status: idle");
  }, 2500);

  // Close after 4 seconds
  setTimeout(() => {
    console.log("[Test] Closing connection");
    client.end();
  }, 4000);
});

client.on("data", (data) => {
  console.log("[Test] Received:", data.toString().trim());
});

client.on("error", (err) => {
  console.error("[Test] Connection error:", err.message);
  console.log("[Test] Is Pi Island running?");
  process.exit(1);
});

client.on("close", () => {
  console.log("[Test] Connection closed");
  process.exit(0);
});
