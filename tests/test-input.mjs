/**
 * Test input bar - simulates a session and shows received SEND_MESSAGE events.
 * Run with: node tests/test-input.mjs
 */
import * as net from "node:net";
import * as crypto from "node:crypto";

const SOCKET_PATH = "/tmp/pi-island.sock";
const SESSION_ID = crypto.randomUUID();

console.log("[Test] Input Bar Test");
console.log("[Test] Session ID:", SESSION_ID);
console.log("[Test] Connecting...\n");

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
    project: "/Users/test/input-test-project",
    model: "test-model",
  });

  // Initial status
  send("STATUS", { state: "idle" });

  console.log("[Test] Session established. Waiting for SEND_MESSAGE from Pi Island UI...");
  console.log("[Test] Expand Pi Island, type a message, and press Enter or click send.");
  console.log("[Test] Press Ctrl+C to exit.\n");
});

client.on("data", (data) => {
  const text = data.toString();
  const lines = text.split("\n").filter((l) => l.trim());
  
  for (const line of lines) {
    try {
      const msg = JSON.parse(line);
      if (msg.type === "SEND_MESSAGE") {
        console.log("\n[Test] *** RECEIVED SEND_MESSAGE ***");
        console.log("[Test] Session ID:", msg.payload?.sessionId);
        console.log("[Test] Text:", msg.payload?.text);
        console.log("[Test] Timestamp:", new Date(msg.payload?.timestamp).toISOString());
        console.log("");
      } else {
        console.log("[Test] Received:", msg.type);
      }
    } catch {
      console.log("[Test] Raw data:", line);
    }
  }
});

client.on("error", (err) => {
  console.error("[Test] Error:", err.message);
  process.exit(1);
});

client.on("close", () => {
  console.log("[Test] Connection closed");
  process.exit(0);
});

process.on("SIGINT", () => {
  console.log("\n[Test] Disconnecting...");
  client.end();
});
