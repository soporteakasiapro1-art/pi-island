/**
 * Check Pi Island status - queries the socket server for current state.
 * Run with: node tests/check-status.mjs
 */
import * as net from "node:net";

const SOCKET_PATH = "/tmp/pi-island.sock";

console.log("Checking Pi Island status...\n");

// Try to connect
const client = net.createConnection(SOCKET_PATH);

client.on("connect", () => {
  console.log("Socket server: RUNNING");
  console.log("Socket path:", SOCKET_PATH);
  client.end();
});

client.on("error", (err) => {
  if (err.code === "ENOENT") {
    console.log("Socket server: NOT RUNNING (socket file not found)");
  } else if (err.code === "ECONNREFUSED") {
    console.log("Socket server: NOT RUNNING (connection refused)");
  } else {
    console.log("Socket server: ERROR -", err.message);
  }
  process.exit(1);
});

client.on("close", () => {
  console.log("\nPi Island is ready to accept connections.");
  process.exit(0);
});
