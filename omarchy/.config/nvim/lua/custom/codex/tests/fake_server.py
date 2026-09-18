#!/usr/bin/env python3
"""Deterministic app-server peer. Never calls a model or accesses Codex storage."""
import json
import os
from pathlib import Path
import sys

initialized = False
thread_id = "new-session"
turn_id = "turn-1"
scenario = ""
approval = None
schemas = os.environ.get("CODEX_NVIM_SCHEMA")
if schemas:
    import jsonschema


def send(message):
    # Deliberately split JSON across writes, including inside a UTF-8 character.
    data = (json.dumps(message, ensure_ascii=False) + "\n").encode()
    cut = data.find("ø".encode()) + 1 if "ø".encode() in data else len(data) // 2
    os.write(1, data[:cut])
    os.write(1, data[cut:])


def reply(request, result):
    send({"id": request["id"], "result": result})


def event(method, **params):
    send({"method": method, "params": {"threadId": thread_id, **params}})


def item(value, phase="completed"):
    event("item/" + phase, turnId=turn_id, item=value)


def complete(status="completed"):
    event("turn/completed", turn={"id": turn_id, "status": status, "items": [], "error": None})


def answer(text):
    item({"id": "assistant", "type": "agentMessage", "text": text})
    complete()


def validate(method, params):
    if not schemas:
        return
    names = {
        "initialize": "InitializeParams", "thread/start": "ThreadStartParams",
        "thread/resume": "ThreadResumeParams", "thread/read": "ThreadReadParams",
        "thread/items/list": "ThreadItemsListParams", "model/list": "ModelListParams",
        "thread/list": "ThreadListParams", "turn/start": "TurnStartParams",
        "turn/interrupt": "TurnInterruptParams", "thread/unsubscribe": "ThreadUnsubscribeParams",
    }
    path = next(Path(schemas).rglob(names[method] + ".json"))
    jsonschema.validate(params, json.loads(path.read_text()))


for line in sys.stdin:
    request = json.loads(line)
    if "method" not in request:
        assert approval and request["id"] == approval["id"], request
        result = request["result"]
        if scenario == "approval":
            assert result == {"decision": "accept"}, result
        elif scenario == "file":
            assert result == {"decision": "decline"}, result
        elif scenario == "permissions":
            assert result == {"permissions": {"network": {"enabled": True}}, "scope": "turn"}, result
        elif scenario == "question":
            assert result == {"answers": {"choice": {"answers": ["Small"]}}}, result
        if schemas:
            name = {"approval": "CommandExecutionRequestApprovalResponse", "file": "FileChangeRequestApprovalResponse",
                    "permissions": "PermissionsRequestApprovalResponse", "question": "ToolRequestUserInputResponse"}[scenario]
            path = next(Path(schemas).rglob(name + ".json"))
            jsonschema.validate(result, json.loads(path.read_text()))
        event("serverRequest/resolved", requestId=approval["id"])
        approval = None
        answer("Response received: " + scenario)
        continue
    method = request["method"]
    p = request.get("params", {})
    if method == "initialized":
        initialized = True
        continue
    validate(method, p)
    if method == "initialize":
        reply(request, {"userAgent": "fake", "platformFamily": "unix", "platformOs": "linux"})
        continue
    assert initialized, method
    if method in ("thread/start", "thread/resume"):
        thread_id = p.get("threadId", "new-session")
        if thread_id == "missing":
            send({"id": request["id"], "error": {"code": -32000, "message": "Session not found"}})
            continue
        thread = {"id": thread_id, "name": None, "status": {"type": "idle"},
                  "historyMode": "legacy" if thread_id == "legacy" else "paginated", "turns": []}
        reply(request, {"thread": thread, "cwd": os.getcwd(), "model": "model-a", "reasoningEffort": "high"})
    elif method == "thread/items/list":
        if "cursor" not in p:
            reply(request, {"data": [{"turnId": "old", "item": {"id": "user", "type": "userMessage",
                           "content": [{"type": "text", "text": "From the desktop app"}]}}], "nextCursor": "page-2"})
        else:
            reply(request, {"data": [{"turnId": "old", "item": {"id": "assistant", "type": "agentMessage",
                           "text": "External history: blåbær"}}], "nextCursor": None})
    elif method == "thread/read":
        reply(request, {"thread": {"turns": [{"id": "old", "items": [
            {"id": "assistant", "type": "agentMessage", "text": "Legacy CLI history"}]}]}})
    elif method == "thread/list":
        reply(request, {"data": [{"id": "external" if "cursor" in p else "legacy", "name": "External session",
                       "preview": "", "cwd": os.getcwd(), "updatedAt": 1700000000}],
                        "nextCursor": None if "cursor" in p else "page-2"})
    elif method == "model/list":
        model = "model-b" if "cursor" in p else "model-a"
        reply(request, {"data": [{"model": model, "displayName": model, "supportedReasoningEfforts": [
            {"reasoningEffort": "low", "description": "Light"}, {"reasoningEffort": "high", "description": "Deep"}]}],
                        "nextCursor": None if "cursor" in p else "page-2"})
    elif method == "thread/unsubscribe":
        reply(request, {"status": "unsubscribed"})
    elif method == "turn/interrupt":
        reply(request, {})
        complete("interrupted")
    elif method == "turn/start":
        scenario = p["input"][0]["text"]
        if scenario == "crash":
            sys.exit(7)
        if scenario == "fail-start":
            send({"id": request["id"], "error": {"code": -32000, "message": "Turn rejected"}})
            continue
        turn_id = "turn-" + scenario
        if scenario != "fast":
            reply(request, {"turn": {"id": turn_id, "status": "inProgress", "items": []}})
        event("turn/started", turn={"id": turn_id, "status": "inProgress", "items": []})
        event("thread/settings/updated", threadSettings={"model": p.get("model"), "effort": p.get("effort")})
        item({"id": "user", "type": "userMessage", "content": p["input"]})
        if scenario in ("approval", "file", "permissions", "question"):
            params = {"threadId": thread_id, "turnId": turn_id, "itemId": "tool", "cwd": os.getcwd()}
            if scenario == "approval":
                params.update(command="npm install", reason="Install dependencies")
                suffix = "commandExecution/requestApproval"
                item({"id": "tool", "type": "commandExecution", "command": "npm install", "status": "inProgress"}, "started")
            elif scenario == "file":
                suffix = "fileChange/requestApproval"
                item({"id": "tool", "type": "fileChange", "status": "inProgress", "changes": [
                    {"path": "example.lua", "diff": "-old\n+new"}]}, "started")
            elif scenario == "permissions":
                suffix = "permissions/requestApproval"
                params["permissions"] = {"network": {"enabled": True}}
            else:
                suffix = "tool/requestUserInput"
                params["questions"] = [{"id": "choice", "header": "Scope", "question": "Which scope?",
                                        "options": [{"label": "Small", "description": "One file"}], "isOther": True}]
            approval = {"id": "approval-" + scenario, "method": "item/" + suffix, "params": params}
            send(approval)
        elif scenario == "wait":
            pass
        else:
            # Foreign notifications must not contaminate this transcript.
            send({"method": "item/completed", "params": {"threadId": "foreign", "turnId": "x",
                 "item": {"id": "x", "type": "agentMessage", "text": "DO NOT SHOW"}}})
            item({"id": "assistant", "type": "agentMessage", "text": ""}, "started")
            event("item/agentMessage/delta", turnId=turn_id, itemId="assistant", delta="Hø")
            event("item/agentMessage/delta", turnId=turn_id, itemId="assistant", delta="llo")
            answer("Høllo — final authoritative text")
            if scenario == "fast":
                reply(request, {"turn": {"id": turn_id, "status": "completed", "items": []}})
    else:
        raise AssertionError(method)
