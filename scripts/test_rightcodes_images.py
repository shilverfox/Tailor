#!/usr/bin/env python3
"""Minimal Right Code async Images API protocol test.

Follows the documented flow exactly:
1. POST /draw/v1/images/generations with async=true.
2. Poll GET /v1/tasks/{task_id} until completed or failed.
3. Download data[0].url when completed.

The API key is read locally from ~/.hermes/profiles/wechat/.env and is never
printed or persisted in the result file.
"""

import argparse
import json
import os
import pwd
import ssl
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import certifi


API_BASE = "https://www.right.codes"
ENV_PATH = Path(pwd.getpwuid(os.getuid()).pw_dir) / ".hermes/profiles/wechat/.env"
USER_AGENT = "curl/8.0.1"


def api_key() -> str:
    for line in ENV_PATH.read_text(encoding="utf-8").splitlines():
        if line.startswith("RIGHTCODES_API_KEY="):
            key = line.split("=", 1)[1].strip()
            if key:
                return key
    raise RuntimeError("RIGHTCODES_API_KEY is missing or empty")


def make_context(insecure: bool) -> ssl.SSLContext:
    return ssl._create_unverified_context() if insecure else ssl.create_default_context(cafile=certifi.where())


def read_bytes(request: urllib.request.Request, context: ssl.SSLContext, timeout: int) -> bytes:
    with urllib.request.urlopen(request, context=context, timeout=timeout) as response:
        return response.read()


def read_json(request: urllib.request.Request, context: ssl.SSLContext, timeout: int) -> dict:
    return json.loads(read_bytes(request, context, timeout))


def main() -> int:
    parser = argparse.ArgumentParser(description="Test the documented right.codes async Images API.")
    parser.add_argument("--output-dir", type=Path, default=Path("Tailor/Resources/RightCodeTest"))
    parser.add_argument("--model", default="gpt-image-2")
    parser.add_argument("--size", default="1792x1024")
    parser.add_argument("--image-size", choices=["1K", "2K", "4K"], help="Optional documented output resolution for supported gpt-image models.")
    parser.add_argument("--prompt", default="A quiet, warm memorial photograph of a senior golden retriever resting beside printed family photographs on cream linen, no text, no watermark, no fantasy elements.")
    parser.add_argument("--request-timeout", type=int, default=30)
    parser.add_argument("--poll-timeout", type=int, default=600)
    parser.add_argument("--poll-interval", type=float, default=2.0)
    parser.add_argument("--insecure-transport", action="store_true", help="Use only if the local Python CA store cannot validate right.codes.")
    args = parser.parse_args()

    context = make_context(args.insecure_transport)
    output_dir = args.output_dir.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    result = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "endpoint": f"{API_BASE}/draw/v1/images/generations",
        "model": args.model,
        "size": args.size,
        "transport": "insecure-compatibility" if args.insecure_transport else "verified",
    }

    try:
        payload_dict = {
            "model": args.model,
            "prompt": args.prompt,
            "n": 1,
            "size": args.size,
            "async": True,
        }
        if args.image_size:
            payload_dict["imageSize"] = args.image_size
        payload = json.dumps(payload_dict).encode("utf-8")
        submission = urllib.request.Request(
            f"{API_BASE}/draw/v1/images/generations",
            data=payload,
            headers={"Authorization": f"Bearer {api_key()}", "Content-Type": "application/json", "User-Agent": USER_AGENT},
        )
        submitted = read_json(submission, context, args.request_timeout)
        result["submission"] = submitted
        task_id = submitted.get("task_id")
        if not task_id:
            raise RuntimeError(f"Expected task_id, received: {submitted}")
        print(f"Submitted task: {task_id}", flush=True)

        deadline = time.monotonic() + args.poll_timeout
        while time.monotonic() < deadline:
            status_request = urllib.request.Request(
                f"{API_BASE}/v1/tasks/{task_id}",
                headers={"Authorization": f"Bearer {api_key()}", "User-Agent": USER_AGENT},
            )
            status = read_json(status_request, context, args.request_timeout)
            result["last_status"] = status
            state = status.get("status")
            print(f"Status: {state or 'completed-response'}", flush=True)
            if status.get("data"):
                url = status["data"][0]["url"]
                image_request = urllib.request.Request(url)
                image_path = output_dir / "rightcodes_protocol_test.png"
                image_path.write_bytes(read_bytes(image_request, context, args.request_timeout))
                result.update({"outcome": "completed", "image_path": str(image_path), "task_id": task_id})
                break
            if state == "failed":
                result.update({"outcome": "failed", "task_id": task_id})
                break
            time.sleep(args.poll_interval)
        else:
            result.update({"outcome": "poll_timeout", "task_id": task_id})
    except urllib.error.HTTPError as error:
        result.update({"outcome": "http_error", "status_code": error.code, "error": error.read().decode("utf-8", errors="replace")[:1000]})
    except Exception as error:
        result.update({"outcome": "error", "error": f"{type(error).__name__}: {error}"})

    result["finished_at"] = datetime.now(timezone.utc).isoformat()
    manifest = output_dir / "rightcodes_protocol_test.json"
    manifest.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Result: {result['outcome']}; manifest: {manifest}", flush=True)
    return 0 if result["outcome"] == "completed" else 2


if __name__ == "__main__":
    raise SystemExit(main())
