/**
 * Pi Island Extension
 *
 * Bridges the Pi Coding Agent to the Pi Island native macOS app via Unix Domain Socket.
 * Install to: ~/.pi/agent/extensions/pi-island.ts
 */
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import * as net from "node:net";
import * as crypto from "node:crypto";

const SOCKET_PATH = process.env.PI_ISLAND_SOCKET ?? "/tmp/pi-island.sock";

interface PendingRequest {
  resolve: (allow: boolean) => void;
  reject: (error: Error) => void;
}

export default function (pi: ExtensionAPI) {
  console.log("[pi-island] Extension loaded");
  
  let client: net.Socket | null = null;
  let connected = false;
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  const pendingRequests = new Map<string, PendingRequest>();

  // Session context (set on session_start)
  let currentSessionId: string | null = null;

  // Helper to send messages to the UI
  function send(type: string, payload: Record<string, unknown>) {
    if (client && connected) {
      // Include sessionId in all messages
      const message = JSON.stringify({
        type,
        payload: { ...payload, sessionId: currentSessionId },
      }) + "\n";
      client.write(message);
    }
  }

  // Connect to the Pi Island socket server
  function connect() {
    if (client) {
      client.destroy();
      client = null;
    }

    client = net.createConnection(SOCKET_PATH);

    client.on("connect", () => {
      connected = true;
      console.log("[pi-island] Connected to Pi Island");
      // Handshake is sent in session_start after we have context
    });

    client.on("data", (data) => {
      const text = data.toString();
      const lines = text.split("\n").filter((l) => l.trim());

      for (const line of lines) {
        try {
          const msg = JSON.parse(line);
          handleUIMessage(msg);
        } catch {
          // Ignore malformed messages
        }
      }
    });

    client.on("error", (err) => {
      // Silent failure - Pi Island may not be running
      connected = false;
      scheduleReconnect();
    });

    client.on("close", () => {
      connected = false;
      scheduleReconnect();
    });
  }

  function scheduleReconnect() {
    if (reconnectTimer) return;
    reconnectTimer = setTimeout(() => {
      reconnectTimer = null;
      connect();
    }, 5000); // Retry every 5 seconds
  }

  function handleUIMessage(msg: { type: string; payload?: Record<string, unknown> }) {
    switch (msg.type) {
      case "TOOL_RES": {
        const id = msg.payload?.id as string;
        const allow = msg.payload?.allow as boolean;
        const pending = pendingRequests.get(id);
        if (pending) {
          pendingRequests.delete(id);
          pending.resolve(allow);
        }
        break;
      }
      case "SEND_MESSAGE": {
        const text = msg.payload?.text as string;
        const sessionId = msg.payload?.sessionId as string;
        if (text && sessionId === currentSessionId) {
          // TODO: Inject message into Pi agent
          // For now, log it - Pi doesn't have a direct API for injecting user input
          console.log(`[pi-island] Received message from UI: ${text}`);
          // Future: Could use ctx.ui.notify or find another way to inject
        }
        break;
      }
      case "INTERRUPT": {
        // Future: handle interrupt requests
        break;
      }
    }
  }

  // Session lifecycle
  pi.on("session_start", async (_event, ctx) => {
    // Get session ID from session manager
    const sessionFile = ctx.sessionManager.getSessionFile();
    currentSessionId = sessionFile
      ? sessionFile.split("/").pop()?.replace(".jsonl", "").split("_").pop() ?? null
      : crypto.randomUUID();

    connect();

    // Send handshake after connection (or queue it)
    setTimeout(() => {
      send("HANDSHAKE", {
        pid: process.pid,
        project: process.cwd(),
        model: ctx.model?.id ?? undefined,
      });
      send("STATUS", { state: "idle" });
    }, 100);
  });

  pi.on("session_shutdown", async () => {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer);
    }
    if (client) {
      client.destroy();
    }
  });

  // Agent lifecycle
  pi.on("agent_start", async () => {
    send("STATUS", { state: "thinking" });
  });

  pi.on("agent_end", async () => {
    send("STATUS", { state: "idle" });
  });

  // Turn lifecycle
  pi.on("turn_start", async () => {
    send("STATUS", { state: "thinking" });
  });

  pi.on("turn_end", async (event) => {
    send("STATUS", { state: "idle" });

    // Send assistant message if present
    if (event.message) {
      // Extract text content from message
      const content = event.message.content;
      let text = "";
      if (typeof content === "string") {
        text = content;
      } else if (Array.isArray(content)) {
        for (const block of content) {
          if (block.type === "text") {
            text += block.text + "\n";
          }
        }
      }

      if (text.trim()) {
        send("MESSAGE", {
          id: crypto.randomUUID(),
          role: "assistant",
          content: text.trim(),
          timestamp: Date.now(),
        });
      }
    }
  });

  // User input - capture before agent processes
  pi.on("input", async (event) => {
    if (event.text) {
      send("MESSAGE", {
        id: crypto.randomUUID(),
        role: "user",
        content: event.text,
        timestamp: Date.now(),
      });
    }
    return { action: "continue" };
  });

  // Tool execution
  pi.on("tool_call", async (event, ctx) => {
    const { toolName, toolCallId, input } = event;

    // Send tool start status
    send("TOOL_START", {
      tool: toolName,
      input: input,
    });

    // Also send as a message for chat display
    send("MESSAGE", {
      id: toolCallId ?? crypto.randomUUID(),
      role: "toolCall",
      toolName: toolName,
      input: input,
      timestamp: Date.now(),
    });

    // Check if this tool requires permission (Phase 2 implementation)
    const sensitiveTools = ["bash"];
    const sensitivePatterns = [/rm\s+-rf/, /sudo/, /dd\s+/, />\s*\/dev\//];

    if (toolName === "bash" && typeof input.command === "string") {
      const isSensitive = sensitivePatterns.some((pattern) =>
        pattern.test(input.command)
      );

      if (isSensitive && connected) {
        const requestId = crypto.randomUUID();

        // Send permission request to UI
        send("TOOL_REQ", {
          id: requestId,
          tool: toolName,
          cmd: input.command,
        });

        // Wait for UI response
        try {
          const allowed = await new Promise<boolean>((resolve, reject) => {
            pendingRequests.set(requestId, { resolve, reject });

            // Timeout after 60 seconds
            setTimeout(() => {
              if (pendingRequests.has(requestId)) {
                pendingRequests.delete(requestId);
                reject(new Error("Permission request timed out"));
              }
            }, 60000);
          });

          if (!allowed) {
            return { block: true, reason: "Blocked by Pi Island" };
          }
        } catch {
          // On timeout or error, block for safety
          return { block: true, reason: "Permission request failed" };
        }
      }
    }
  });

  pi.on("tool_result", async (event) => {
    send("TOOL_END", {
      tool: event.toolName,
      success: !event.isError,
    });
  });
}
