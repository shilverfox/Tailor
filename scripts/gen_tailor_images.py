#!/usr/bin/env python3
"""Generate Tailor image assets with provider provenance and bounded retries.

This project-local adaptation keeps the original prompt-file convention but adds
explicit source selection, short per-request timeouts, atomic writes, and a
manifest that records the provider used for each image.

Usage:
  python3 scripts/gen_tailor_images.py --article-dir Tailor/Resources/GeneratedAssets \
    --local-only --source rightcodes --max-images 1
"""

import argparse
import hashlib
import json
import os
import pwd
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import certifi

RC_BASE = "https://www.right.codes/draw"
ENV_PATH = Path(pwd.getpwuid(os.getuid()).pw_dir) / ".hermes/profiles/wechat/.env"
USER_AGENT = "curl/8.0.1"
def ssl_context(insecure_transport: bool) -> ssl.SSLContext:
    """Use verified TLS by default; compatibility mode mirrors the supplied script."""
    if insecure_transport:
        return ssl._create_unverified_context()
    return ssl.create_default_context(cafile=certifi.where())


def env_value(name: str) -> str:
    """Read one dotenv value without printing credentials."""
    try:
        for line in ENV_PATH.read_text(encoding="utf-8").splitlines():
            if line.startswith(f"{name}="):
                value = line.split("=", 1)[1].strip()
                if value:
                    return value
    except OSError as error:
        raise RuntimeError(f"Cannot read credential file: {ENV_PATH}") from error
    raise RuntimeError(f"Missing {name} in {ENV_PATH}")


def request_bytes(request: urllib.request.Request, timeout: int, context: ssl.SSLContext) -> bytes:
    with urllib.request.urlopen(request, context=context, timeout=timeout) as response:
        return response.read()


def json_request(request: urllib.request.Request, timeout: int, context: ssl.SSLContext) -> dict:
    return json.loads(request_bytes(request, timeout, context))


def rightcodes(
    prompt: str,
    size: str,
    model: str,
    request_timeout: int,
    download_timeout: int,
    poll_timeout: int,
    poll_interval: float,
    context: ssl.SSLContext,
) -> tuple[bytes, str | None, str]:
    payload = json.dumps({
        "model": model,
        "prompt": prompt,
        "n": 1,
        "size": size,
        "async": True,
    }).encode("utf-8")
    request = urllib.request.Request(
        f"{RC_BASE}/v1/images/generations",
        data=payload,
        headers={
            "Authorization": f"Bearer {env_value('RIGHTCODES_API_KEY')}",
            "Content-Type": "application/json",
            "Connection": "close",
            "User-Agent": USER_AGENT,
        },
    )
    result = json_request(request, request_timeout, context)
    # The current documented contract is asynchronous.  Retain the direct
    # Images response branch for an already-completed task response.
    task_id = result.get("task_id")
    if result.get("data"):
        image_url = result["data"][0]["url"]
    else:
        if not task_id:
            raise RuntimeError(f"Unexpected right.codes submission response: {result}")
        deadline = time.monotonic() + poll_timeout
        image_url = None
        while time.monotonic() < deadline:
            status_request = urllib.request.Request(
                f"https://www.right.codes/v1/tasks/{task_id}",
                headers={"Authorization": f"Bearer {env_value('RIGHTCODES_API_KEY')}", "Connection": "close", "User-Agent": USER_AGENT},
            )
            status = json_request(status_request, request_timeout, context)
            if status.get("data"):
                image_url = status["data"][0]["url"]
                break
            if status.get("status") == "failed":
                message = status.get("error", {}).get("message", "Unknown upstream failure")
                raise RuntimeError(f"right.codes task {task_id} failed: {message}")
            time.sleep(poll_interval)
        if not image_url:
            raise TimeoutError(f"right.codes task {task_id} did not complete within {poll_timeout}s")
    download = urllib.request.Request(image_url, headers={"Connection": "close"})
    return request_bytes(download, download_timeout, context), task_id, image_url


def size_for(title: str, prompt: str) -> str:
    aspect = re.search(r"--ar\s+(\S+)", prompt)
    ar = aspect.group(1) if aspect else ""
    if ar in {"9:16", "5:7"} or "9:16" in title or "5:7" in title:
        return "1024x1792"
    if ar in {"1:1"} or "1:1" in title:
        return "1024x1024"
    return "1792x1024"


def safe_name(title: str, position: int) -> str:
    name = title.split("（", 1)[0].split("(", 1)[0].strip()
    name = re.sub(r"[^\w\-一-龥]+", "_", name).strip("_")
    return f"{position:02d}_{name or 'asset'}"


def parse_prompts(prompt_file: Path):
    blocks = re.split(r"(?:^|\n)##\s+", prompt_file.read_text(encoding="utf-8"))
    items = []
    for position, block in enumerate(blocks[1:], start=1):
        lines = block.splitlines()
        if not lines:
            continue
        title = lines[0].strip()
        collecting, fragments = False, []
        for line in lines[1:]:
            if line.startswith("Prompt:"):
                collecting = True
                fragments.append(line.split("Prompt:", 1)[1].strip())
            elif collecting and (line.startswith("---") or line.startswith("对应")):
                break
            elif collecting:
                fragments.append(line.strip())
        prompt = re.sub(r"--ar\s+\S+", "", " ".join(fragments)).strip()
        if prompt:
            items.append((safe_name(title, position), title, prompt, size_for(title, " ".join(fragments))))
    return items


def generate(prompt: str, size: str, model: str, request_timeout: int, download_timeout: int, poll_timeout: int, poll_interval: float, context: ssl.SSLContext):
    started = time.monotonic()
    try:
        image, task_id, source_url = rightcodes(prompt, size, model, request_timeout, download_timeout, poll_timeout, poll_interval, context)
        return image, "rightcodes", round(time.monotonic() - started, 1), [], task_id, source_url
    except (KeyError, OSError, RuntimeError, ValueError, urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as error:
        detail = str(error)
        if isinstance(error, urllib.error.HTTPError):
            try:
                body = error.read().decode("utf-8", errors="replace").strip()
                if body:
                    detail = f"{detail}; response={body[:1000]}"
            except OSError:
                pass
        message = f"rightcodes: {type(error).__name__}: {detail}"
        print(f"  [rightcodes failed] {message}", flush=True)
        return None, None, None, [message], None, None


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Tailor assets locally with auditable source metadata.")
    parser.add_argument("--article-dir", required=True, type=Path)
    parser.add_argument("--local-only", action="store_true", help="Required; uploads are deliberately unsupported in this project script.")
    parser.add_argument("--insecure-transport", action="store_true", help="Match the original script's disabled TLS verification. Use only for legacy right.codes compatibility testing.")
    parser.add_argument("--model", default="gpt-image-2", help="A model name enabled for this API key in the Right Code backend.")
    parser.add_argument("--max-images", type=int, default=0, help="0 means all prompts")
    parser.add_argument("--request-timeout", type=int, default=75)
    parser.add_argument("--download-timeout", type=int, default=45)
    parser.add_argument("--poll-timeout", type=int, default=600, help="Maximum time to wait for an async right.codes task.")
    parser.add_argument("--poll-interval", type=float, default=2.0, help="Seconds between right.codes task status checks.")
    args = parser.parse_args()
    if not args.local_only:
        parser.error("Only --local-only is supported; CDN upload is intentionally disabled.")

    directory = args.article_dir.expanduser().resolve()
    prompt_file = directory / "插图提示词.md"
    if not prompt_file.exists():
        parser.error(f"Prompt file not found: {prompt_file}")
    prompts = parse_prompts(prompt_file)
    if args.max_images:
        prompts = prompts[:args.max_images]
    manifest = []
    context = ssl_context(args.insecure_transport)
    transport = "insecure-compatibility" if args.insecure_transport else "verified"
    print(f"Tailor asset generation: {len(prompts)} image(s), source=rightcodes, model={args.model}, TLS={transport}", flush=True)
    for index, (name, title, prompt, size) in enumerate(prompts, start=1):
        print(f"[{index}/{len(prompts)}] {title} -> {name}.png ({size})", flush=True)
        image, provider, elapsed, errors, task_id, source_url = generate(
            prompt, size, args.model, args.request_timeout, args.download_timeout,
            args.poll_timeout, args.poll_interval, context,
        )
        record = {"name": name, "title": title, "size": size, "source": provider, "task_id": task_id, "source_url": source_url, "elapsed_seconds": elapsed, "errors": errors}
        if image:
            target = directory / f"{name}.png"
            temporary = target.with_suffix(".png.tmp")
            temporary.write_bytes(image)
            temporary.replace(target)
            record["path"] = str(target)
            record["bytes"] = len(image)
            record["sha256"] = hashlib.sha256(image).hexdigest()
            print(f"  [saved] source={provider}; elapsed={elapsed}s; path={target.name}; bytes={len(image)}", flush=True)
        else:
            record["path"] = None
            print("  [failed] no provider returned image data", flush=True)
        manifest.append(record)

    manifest_path = directory / "generation_manifest.json"
    manifest_path.write_text(json.dumps({"generated_at": datetime.now(timezone.utc).isoformat(), "items": manifest}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    succeeded = sum(item["source"] is not None for item in manifest)
    print(f"Done: {succeeded}/{len(manifest)} saved. Manifest: {manifest_path}", flush=True)
    return 0 if succeeded == len(manifest) else 2


if __name__ == "__main__":
    raise SystemExit(main())
