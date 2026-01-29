/**
 * Simple persistent session test - keeps connection open for manual UI inspection.
 * Run with: node tests/test-persistent.mjs
 * Press Ctrl+C to disconnect.
 */
import * as net from "node:net";
import * as crypto from "node:crypto";

const SOCKET_PATH = "/tmp/pi-island.sock";
const SESSION_ID = crypto.randomUUID();

console.log("[Test] Connecting to Pi Island...");
console.log("[Test] Session ID:", SESSION_ID);

const client = net.createConnection(SOCKET_PATH, () => {
  console.log("[Test] Connected!");

  function send(type, payload) {
    const msg = JSON.stringify({
      type,
      payload: { ...payload, sessionId: SESSION_ID },
    }) + "\n";
    client.write(msg);
  }

  // Handshake
  send("HANDSHAKE", {
    pid: process.pid,
    project: "/Users/test/persistent-project",
    model: "claude-sonnet-4-20250514",
  });
  console.log("[Test] Sent handshake");

  // Initial status
  send("STATUS", { state: "idle" });

  // User message
  setTimeout(() => {
    send("MESSAGE", {
      id: crypto.randomUUID(),
      role: "user",
      content: "This is a test message to verify the UI displays correctly.",
      timestamp: Date.now(),
    });
    console.log("[Test] Sent user message");
  }, 500);

  // Assistant response
  setTimeout(() => {
    send("STATUS", { state: "thinking" });
    console.log("[Test] Status: thinking");
  }, 1000);

  setTimeout(() => {
    send("MESSAGE", {
      id: crypto.randomUUID(),
      role: "assistant", 
      content: "I received your message. The connection is working correctly!",
      timestamp: Date.now(),
    });
    send("STATUS", { state: "idle" });
    console.log("[Test] Sent assistant message, status: idle");
  }, 2000);

  console.log("\n[Test] Connection will stay open. Press Ctrl+C to disconnect.");
  console.log("[Test] Check Pi Island UI - hover over notch to expand.\n");
});

client.on("data", (data) => {
  console.log("[Test] Received:", data.toString().trim());
});

client.on("error", (err) => {
  console.error("[Test] Error:", err.message);
  process.exit(1);
});

client.on("close", () => {
  console.log("[Test] Connection closed");
  process.exit(0);
});

// Keep process alive
process.on("SIGINT", () => {
  console.log("\n[Test] Disconnecting...");
  client.end();
});
