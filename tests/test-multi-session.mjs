/**
 * Comprehensive test for Pi Island multi-session support.
 * Simulates multiple concurrent Pi sessions with messages and tool calls.
 * Run with: node tests/test-multi-session.mjs
 */
import * as net from "node:net";
import * as crypto from "node:crypto";

const SOCKET_PATH = "/tmp/pi-island.sock";

class PiSessionSimulator {
  constructor(projectPath, model) {
    this.sessionId = crypto.randomUUID();
    this.projectPath = projectPath;
    this.model = model;
    this.client = null;
    this.connected = false;
  }

  async connect() {
    return new Promise((resolve, reject) => {
      this.client = net.createConnection(SOCKET_PATH, () => {
        this.connected = true;
        console.log(`[${this.projectName}] Connected, session: ${this.sessionId.slice(0, 8)}...`);
        resolve();
      });
      this.client.on("error", reject);
      this.client.on("data", (data) => {
        console.log(`[${this.projectName}] Received: ${data.toString().trim()}`);
      });
    });
  }

  get projectName() {
    return this.projectPath.split("/").pop();
  }

  send(type, payload) {
    if (this.client && this.connected) {
      const msg = JSON.stringify({
        type,
        payload: { ...payload, sessionId: this.sessionId },
      }) + "\n";
      this.client.write(msg);
    }
  }

  async handshake() {
    this.send("HANDSHAKE", {
      pid: process.pid + Math.floor(Math.random() * 1000),
      project: this.projectPath,
      model: this.model,
    });
    await this.delay(50);
  }

  async status(state) {
    this.send("STATUS", { state });
    await this.delay(50);
  }

  async userMessage(text) {
    this.send("MESSAGE", {
      id: crypto.randomUUID(),
      role: "user",
      content: text,
      timestamp: Date.now(),
    });
    await this.delay(50);
  }

  async assistantMessage(text) {
    this.send("MESSAGE", {
      id: crypto.randomUUID(),
      role: "assistant",
      content: text,
      timestamp: Date.now(),
    });
    await this.delay(50);
  }

  async toolStart(tool, input) {
    this.send("TOOL_START", { tool, input });
    await this.delay(50);
  }

  async toolEnd(tool, success = true) {
    this.send("TOOL_END", { tool, success });
    await this.delay(50);
  }

  async disconnect() {
    if (this.client) {
      this.client.end();
      console.log(`[${this.projectName}] Disconnected`);
    }
  }

  delay(ms) {
    return new Promise((r) => setTimeout(r, ms));
  }
}

async function main() {
  console.log("=== Pi Island Multi-Session Test ===\n");

  // Create two concurrent sessions
  const session1 = new PiSessionSimulator("/Users/test/project-alpha", "claude-sonnet-4-20250514");
  const session2 = new PiSessionSimulator("/Users/test/project-beta", "gpt-4o");

  try {
    // Connect both sessions
    await session1.connect();
    await session2.connect();

    // Handshake
    await session1.handshake();
    await session2.handshake();

    // Session 1: Start thinking
    await session1.status("idle");
    await session1.userMessage("Can you help me refactor this function?");
    await session1.status("thinking");

    // Session 2: Quick message
    await session2.status("idle");
    await session2.userMessage("What's the status of the build?");
    await session2.status("thinking");
    await session2.assistantMessage("I'll check the build status for you.");
    await session2.toolStart("bash", { command: "npm run build" });

    // Session 1: Response with tool call
    await session1.assistantMessage("I'll analyze the function and suggest improvements.");
    
    // Send tool call as a message
    session1.send("MESSAGE", {
      id: crypto.randomUUID(),
      role: "toolCall",
      toolName: "read",
      input: { path: "src/utils.ts" },
      timestamp: Date.now(),
    });
    await session1.delay(50);
    
    await session1.toolStart("read", { path: "src/utils.ts" });
    await session1.delay(200);
    await session1.toolEnd("read", true);

    // Session 2: Tool completes
    await session2.delay(200);
    await session2.toolEnd("bash", true);
    await session2.assistantMessage("Build completed successfully with 0 errors.");
    await session2.status("idle");

    // Session 1: Continue work
    await session1.assistantMessage("Here are my suggestions for the refactor...");
    await session1.status("idle");

    console.log("\n=== Test Complete ===");
    console.log("Check Pi Island UI - you should see two sessions with messages.");

    // Keep connections open briefly to see UI update
    await session1.delay(2000);

  } finally {
    await session1.disconnect();
    await session2.disconnect();
  }
}

main().catch(console.error);
