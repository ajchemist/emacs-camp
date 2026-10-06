#!/usr/bin/env python3
"""Tiny ACP agent for CI, speaking newline-delimited JSON-RPC 2.0 on stdio.

Handles initialize and session/new. For each session/prompt it sends a single
agent_message_chunk "PONG: <prompt text>" and then end_turn. Other requests
return an empty result and notifications are dropped. Offline, keyless.
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
    if mid is None or method is None:  # a notification or a reply to something we sent
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
