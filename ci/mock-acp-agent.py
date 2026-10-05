#!/usr/bin/env python3
"""A minimal ACP agent over stdio (newline-delimited JSON-RPC 2.0), for CI.

Answers initialize / session/new, and replies to every session/prompt with
one agent_message_chunk "PONG: <prompt text>" followed by end_turn. Any other
request gets an empty result; notifications are ignored. No network, no keys.
"""
import json
import sys


def send(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    msg = json.loads(line)
    method, mid, params = msg.get("method"), msg.get("id"), msg.get("params") or {}
    if mid is None or method is None:  # notification, or a response to us
        continue
    if method == "initialize":
        result = {"protocolVersion": params.get("protocolVersion", 1),
                  "agentCapabilities": {"loadSession": False},
                  "authMethods": []}
    elif method == "session/new":
        result = {"sessionId": "mock-session-1"}
    elif method == "session/prompt":
        text = " ".join(b.get("text", "") for b in params.get("prompt", [])
                        if b.get("type") == "text").strip()
        send({"jsonrpc": "2.0", "method": "session/update",
              "params": {"sessionId": params.get("sessionId"),
                         "update": {"sessionUpdate": "agent_message_chunk",
                                    "content": {"type": "text", "text": "PONG: " + text}}}})
        result = {"stopReason": "end_turn"}
    else:
        result = {}
    send({"jsonrpc": "2.0", "id": mid, "result": result})
