#!/usr/bin/env python3
"""Deterministic stand-in for `claude -p` in stream-json mode. Never calls a model.

Message shapes follow recordings of Claude Code 2.1.283."""
import json
import os
import sys

args = sys.argv[1:]
for flag in ("--input-format", "--output-format", "--include-partial-messages", "--permission-prompt-tool"):
    assert flag in args, args
session = args[args.index("--resume") + 1] if "--resume" in args else "fake-session"
model = "claude-opus-5-5"
cwd = os.getcwd()
waiting = {}  # request_id -> scenario, for requests sent to Neovim


def send(message):
    # Deliberately split JSON across writes, including inside a UTF-8 character.
    data = (json.dumps(message, ensure_ascii=False) + "\n").encode()
    cut = data.find("ø".encode()) + 1 if "ø".encode() in data else len(data) // 2
    os.write(1, data[:cut])
    os.write(1, data[cut:])


def system_init():
    send({"type": "system", "subtype": "init", "session_id": session, "model": model,
          "permissionMode": "auto", "cwd": cwd})


def text(message_id, value, parent=None):
    if parent is None:
        send({"type": "stream_event", "event": {"type": "message_start", "message": {"id": message_id}},
              "parent_tool_use_id": None})
        send({"type": "stream_event", "event": {"type": "content_block_start", "index": 0,
              "content_block": {"type": "text", "text": ""}}, "parent_tool_use_id": None})
        for part in (value[:2], value[2:]):
            send({"type": "stream_event", "event": {"type": "content_block_delta", "index": 0,
                  "delta": {"type": "text_delta", "text": part}}, "parent_tool_use_id": None})
    send({"type": "assistant", "parent_tool_use_id": parent, "session_id": session,
          "message": {"id": message_id, "role": "assistant", "content": [{"type": "text", "text": value}]}})


def tool(tool_id, name, tool_input):
    send({"type": "assistant", "parent_tool_use_id": None, "session_id": session,
          "message": {"id": "msg-" + tool_id, "role": "assistant",
                      "content": [{"type": "tool_use", "id": tool_id, "name": name, "input": tool_input}]}})


def tool_result(tool_id, is_error=False):
    send({"type": "user", "parent_tool_use_id": None, "session_id": session,
          "message": {"role": "user", "content": [{"type": "tool_result", "tool_use_id": tool_id,
                                                   "content": "result", "is_error": is_error}]}})


def result(subtype="success", is_error=False, errors=None, value=""):
    send({"type": "result", "subtype": subtype, "is_error": is_error, "errors": errors,
          "result": value, "session_id": session})


def ask(scenario, tool_name, tool_input, **extra):
    request_id = "request-" + scenario
    waiting[request_id] = scenario
    send({"type": "control_request", "request_id": request_id,
          "request": {"subtype": "can_use_tool", "tool_name": tool_name, "display_name": tool_name,
                      "input": tool_input, "tool_use_id": "tool-" + scenario, **extra}})


QUESTIONS = [
    {"question": "Which size?", "header": "Size", "multiSelect": False,
     "options": [{"label": "Small", "description": "One file"}, {"label": "Large", "description": "Many files"}]},
    {"question": "Which colours?", "header": "Colours", "multiSelect": True,
     "options": [{"label": "Red"}, {"label": "Blue"}, {"label": "Green"}]},
]


def answered(scenario, response):
    if scenario == "unsupported":
        assert response["subtype"] == "error", response
        return
    assert response["subtype"] == "success", response
    decision = response["response"]
    if scenario == "question":
        assert decision == {"behavior": "allow", "updatedInput": {
            "questions": QUESTIONS, "answers": {"Which size?": "Large", "Which colours?": "Red, Blue"}}}, decision
    elif scenario == "plan":
        assert decision == {"behavior": "allow", "updatedInput": {"plan": "- Step one\n- Step two"}}, decision
    elif scenario in ("allow", "hidden"):
        assert decision == {"behavior": "allow", "updatedInput": {"command": "echo hi"}}, decision
    elif scenario == "deny":
        assert decision["behavior"] == "deny" and decision["message"], decision
    tool_result("tool-" + scenario, decision["behavior"] == "deny")
    text("msg-" + scenario, "Response received: " + scenario)
    result()


for line in sys.stdin:
    message = json.loads(line)
    if message["type"] == "control_request":
        subtype = message["request"]["subtype"]
        reply = {"type": "control_response", "response": {"subtype": "success", "request_id": message["request_id"]}}
        if subtype == "initialize":
            reply["response"]["response"] = {"current_permission_mode": "auto", "models": [
                {"value": "default", "resolvedModel": "claude-opus-5-5", "displayName": "Default (recommended)"},
                {"value": "opus", "resolvedModel": "claude-opus-5-5", "displayName": "Opus 5.5"},
                {"value": "claude-opus-4-8", "resolvedModel": "claude-opus-4-8", "displayName": "Opus 4.8"}]}
            send(reply)
        elif subtype == "interrupt":
            reply["response"]["response"] = {"still_queued": []}
            send(reply)
            result("error_during_execution", True, ["[ede_diagnostic] aborted"])
        else:
            raise AssertionError(subtype)
        continue
    if message["type"] == "control_response":
        answered(waiting.pop(message["response"]["request_id"]), message["response"])
        continue
    assert message["type"] == "user" and message["parent_tool_use_id"] is None, message
    scenario = message["message"]["content"]
    system_init()
    if scenario == "crash":
        sys.exit(7)
    elif scenario == "stream":
        waiting["unsupported-1"] = "unsupported"
        send({"type": "control_request", "request_id": "unsupported-1", "request": {"subtype": "hook_callback"}})
        text("msg-subagent", "DO NOT SHOW", parent="toolu_agent")
        tool("toolu_read", "Read", {"file_path": cwd + "/calc.py"})
        tool_result("toolu_read")
        text("msg-final", "Høllo — final authoritative text")
        result()
    elif scenario == "notice":
        send({"type": "system", "subtype": "informational", "level": "notice", "session_id": session,
              "content": "Opus 5.5's safeguards stopped the response above"})
        model = "claude-opus-4-8"
        system_init()
        text("msg-notice", "Continued on the fallback model")
        result()
    elif scenario == "question":
        tool("tool-question", "AskUserQuestion", {"questions": QUESTIONS})
        ask("question", "AskUserQuestion", {"questions": QUESTIONS}, requires_user_interaction=True)
    elif scenario == "plan":
        tool("tool-plan", "ExitPlanMode", {"plan": "- Step one\n- Step two"})
        ask("plan", "ExitPlanMode", {"plan": "- Step one\n- Step two"}, requires_user_interaction=True)
    elif scenario in ("allow", "deny", "hidden"):
        tool("tool-" + scenario, "Bash", {"command": "echo hi"})
        ask(scenario, "Bash", {"command": "echo hi"}, description="Print a greeting",
            blocked_path=cwd + "/outside.txt")
    elif scenario == "error":
        result("success", True, value="API Error: overloaded")
    elif scenario != "wait":
        raise AssertionError(scenario)
