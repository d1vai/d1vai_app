#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Iterable

import requests
from selenium import webdriver
from selenium.webdriver.chrome.options import Options


APP_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = APP_ROOT.parent
DEFAULT_OUTPUT_DIR = APP_ROOT / "docs" / "readme-assets"
DEFAULT_APP_URL = "http://localhost:7357"
DEFAULT_API_BASE = "https://api.d1v.ai"
DEFAULT_PROJECT_ID = "ai_assistant_saas_ml66gp5172"
DEFAULT_EMAIL = "aboutmydreams@163.com"
DEFAULT_SERVER_PORT = 7360
DEFAULT_VIEWPORT_WIDTH = 660
DEFAULT_VIEWPORT_HEIGHT = 1295
DEFAULT_DEVICE_SCALE_FACTOR = 2
MINT_TOKEN_SCRIPT = REPO_ROOT / "backend_admin" / "tools" / "mint_user_token.py"
ROOT_VENV_PYTHON = REPO_ROOT / ".venv" / "bin" / "python"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Capture logged-in d1vai_app store screenshots from Flutter web."
    )
    parser.add_argument(
        "--app-url",
        default="",
        help="Existing app URL. If omitted, the script builds Flutter web and serves build/web locally.",
    )
    parser.add_argument(
        "--api-base",
        default=DEFAULT_API_BASE,
        help=f"Backend API base for chat seeding (default: {DEFAULT_API_BASE})",
    )
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help=f"Output directory for PNG screenshots (default: {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument(
        "--project-id",
        default=DEFAULT_PROJECT_ID,
        help=f"Project id used for detail/chat screenshots (default: {DEFAULT_PROJECT_ID})",
    )
    parser.add_argument(
        "--email",
        default=DEFAULT_EMAIL,
        help=f"Email used to mint a local JWT when --auth-token is omitted (default: {DEFAULT_EMAIL})",
    )
    parser.add_argument(
        "--auth-token",
        default="",
        help="Existing JWT token. Overrides --email minting when provided.",
    )
    parser.add_argument(
        "--chat-prompt",
        default="Summarize this project in three concise bullets for a mobile product screenshot.",
        help="Prompt used to seed chat history when no project chat exists.",
    )
    parser.add_argument(
        "--skip-chat-seed",
        action="store_true",
        help="Skip the optional chat-history seed step.",
    )
    parser.add_argument(
        "--headed",
        action="store_true",
        help="Run Chrome visibly instead of headless.",
    )
    parser.add_argument(
        "--server-port",
        type=int,
        default=DEFAULT_SERVER_PORT,
        help=f"Port for the temporary static web server (default: {DEFAULT_SERVER_PORT})",
    )
    parser.add_argument(
        "--viewport-width",
        type=int,
        default=DEFAULT_VIEWPORT_WIDTH,
        help=f"Viewport width in CSS pixels (default: {DEFAULT_VIEWPORT_WIDTH})",
    )
    parser.add_argument(
        "--viewport-height",
        type=int,
        default=DEFAULT_VIEWPORT_HEIGHT,
        help=f"Viewport height in CSS pixels (default: {DEFAULT_VIEWPORT_HEIGHT})",
    )
    parser.add_argument(
        "--device-scale-factor",
        type=float,
        default=DEFAULT_DEVICE_SCALE_FACTOR,
        help=f"Device scale factor for screenshots (default: {DEFAULT_DEVICE_SCALE_FACTOR})",
    )
    parser.add_argument(
        "--include-extra-tabs",
        action="store_true",
        help="Also capture community, orders, and docs screens.",
    )
    return parser


def mint_auth_token(email: str) -> str:
    if not ROOT_VENV_PYTHON.exists():
        raise RuntimeError(f"Missing python interpreter for token minting: {ROOT_VENV_PYTHON}")
    if not MINT_TOKEN_SCRIPT.exists():
        raise RuntimeError(f"Missing token mint script: {MINT_TOKEN_SCRIPT}")
    output = subprocess.check_output(
        [
            str(ROOT_VENV_PYTHON),
            str(MINT_TOKEN_SCRIPT),
            "--email",
            email,
            "--hours",
            "24",
        ],
        cwd=str(REPO_ROOT),
        text=True,
    )
    token = output.strip().splitlines()[-1].strip()
    if not token:
        raise RuntimeError("Minted auth token is empty.")
    return token


def ensure_chat_seed(api_base: str, token: str, project_id: str, prompt: str) -> None:
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    history_url = (
        f"{api_base.rstrip('/')}/api/projects/{project_id}/history"
        "?limit=6&include_payload=true"
    )
    response = requests.get(history_url, headers=headers, timeout=30)
    response.raise_for_status()
    payload = response.json()
    entries = payload.get("data") or []
    if entries:
        return

    execute_url = f"{api_base.rstrip('/')}/api/projects/{project_id}/sessions/execute"
    execute_payload = {
        "prompt": prompt,
        "session_type": "new",
        "auto_deploy": False,
    }
    execute_response = requests.post(
        execute_url,
        headers=headers,
        json=execute_payload,
        timeout=90,
    )
    execute_response.raise_for_status()

    deadline = time.time() + 35
    while time.time() < deadline:
        poll = requests.get(history_url, headers=headers, timeout=30)
        poll.raise_for_status()
        poll_entries = (poll.json().get("data") or [])
        if poll_entries:
            return
        time.sleep(2)


def fetch_user_profile(api_base: str, token: str) -> dict:
    response = requests.get(
        f"{api_base.rstrip('/')}/api/user/info",
        headers={"Authorization": f"Bearer {token}"},
        timeout=30,
    )
    response.raise_for_status()
    payload = response.json()
    user = payload.get("data")
    if not isinstance(user, dict):
        raise RuntimeError("Failed to fetch user profile for screenshot auth bootstrap.")
    return user


def build_release_web(api_base: str) -> None:
    subprocess.check_call(
        [
            "flutter",
            "build",
            "web",
            "--release",
            f"--dart-define=API_BASE_URL={api_base}",
        ],
        cwd=str(APP_ROOT),
    )


def serve_release_web(port: int) -> subprocess.Popen[str]:
    build_dir = APP_ROOT / "build" / "web"
    if not build_dir.exists():
        raise RuntimeError(f"Missing built web directory: {build_dir}")
    return subprocess.Popen(
        [sys.executable, "-m", "http.server", str(port)],
        cwd=str(build_dir),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
    )


def wait_for_http_ready(url: str, timeout_seconds: float = 30) -> None:
    deadline = time.time() + timeout_seconds
    last_error: Exception | None = None
    while time.time() < deadline:
        try:
            response = requests.get(url, timeout=3)
            if response.ok:
                return
        except Exception as exc:  # pragma: no cover - best effort polling
            last_error = exc
        time.sleep(0.5)
    raise RuntimeError(f"Timed out waiting for {url}") from last_error


def make_driver(
    headed: bool,
    viewport_width: int,
    viewport_height: int,
    device_scale_factor: float,
) -> tuple[webdriver.Chrome, str]:
    options = Options()
    options.binary_location = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if not headed:
        options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-web-security")
    options.add_argument("--disable-site-isolation-trials")
    options.add_argument("--hide-scrollbars")
    options.add_argument("--no-first-run")
    options.add_argument("--no-default-browser-check")
    options.add_argument(f"--window-size={viewport_width},{viewport_height}")
    options.add_argument(f"--force-device-scale-factor={device_scale_factor}")
    profile_dir = tempfile.mkdtemp(prefix="d1vai_store_capture_profile_")
    options.add_argument(f"--user-data-dir={profile_dir}")
    driver = webdriver.Chrome(options=options)
    driver.execute_cdp_cmd(
        "Emulation.setDeviceMetricsOverride",
        {
            "width": viewport_width,
            "height": viewport_height,
            "deviceScaleFactor": device_scale_factor,
            "mobile": False,
            "screenWidth": viewport_width,
            "screenHeight": viewport_height,
        },
    )
    return driver, profile_dir


def seed_auth(
    driver: webdriver.Chrome,
    app_url: str,
    token: str,
    user_profile: dict,
) -> None:
    driver.get(app_url)
    time.sleep(2.5)
    stored_token = json.dumps(token)
    stored_user = json.dumps(json.dumps(user_profile, ensure_ascii=False))
    driver.execute_script(
        """
        localStorage.setItem('flutter.auth_token', arguments[0]);
        localStorage.setItem('flutter.auth_user', arguments[1]);
        localStorage.removeItem('flutter.onboarding_data');
        """,
        stored_token,
        stored_user,
    )


def bootstrap_authenticated_app(driver: webdriver.Chrome, app_url: str) -> None:
    dashboard_url = f"{app_url.rstrip('/')}/#/dashboard"
    driver.get(dashboard_url)
    driver.refresh()
    wait_for_flutter_frame(driver, 12)
    # Give AuthProvider enough time to restore the user and fan out to dependents.
    time.sleep(6)


def wait_for_flutter_frame(driver: webdriver.Chrome, seconds: float) -> None:
    deadline = time.time() + seconds
    while time.time() < deadline:
        ready = driver.execute_script(
            """
            return Boolean(
              document.querySelector('flt-glass-pane') ||
              document.querySelector('flutter-view') ||
              document.querySelector('canvas')
            );
            """
        )
        if ready:
            time.sleep(2)
            return
        time.sleep(0.5)


def capture_routes(
    driver: webdriver.Chrome,
    app_url: str,
    output_dir: Path,
    routes: Iterable[tuple[str, str, float]],
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for filename, route, wait_seconds in routes:
        driver.execute_script(
            """
            const route = arguments[0];
            const targetHash = '#' + route;
            if (window.location.hash === targetHash) {
              window.dispatchEvent(new HashChangeEvent('hashchange'));
            } else {
              window.location.hash = targetHash;
            }
            """,
            route,
        )
        wait_for_flutter_frame(driver, wait_seconds)
        time.sleep(1.5)
        target = output_dir / filename
        if not driver.get_screenshot_as_file(str(target)):
            raise RuntimeError(f"Failed to save screenshot to {target}")
        print(f"Saved {target}")


def main() -> int:
    args = build_parser().parse_args()
    output_dir = Path(args.output_dir).resolve()
    token = args.auth_token.strip() or mint_auth_token(args.email.strip())
    user_profile = fetch_user_profile(args.api_base.strip(), token)

    if not args.skip_chat_seed:
        ensure_chat_seed(
            api_base=args.api_base.strip(),
            token=token,
            project_id=args.project_id.strip(),
            prompt=args.chat_prompt.strip(),
        )

    app_url = args.app_url.strip()
    server_process: subprocess.Popen[str] | None = None
    if not app_url:
        build_release_web(args.api_base.strip())
        server_process = serve_release_web(args.server_port)
        app_url = f"http://localhost:{args.server_port}"
        wait_for_http_ready(app_url)

    routes = [
        ("home-screen.png", "/dashboard", 8),
        ("my-page-screen.png", "/profile", 8),
        ("project-detail-screen.png", f"/projects/{args.project_id.strip()}?tab=overview", 12),
        ("chat-with-ai-screen.png", f"/projects/{args.project_id.strip()}/chat", 14),
    ]
    if args.include_extra_tabs:
        routes.extend(
            [
                ("community-screen.png", "/community", 10),
                ("orders-screen.png", "/orders?tab=usage", 12),
                ("docs-screen.png", "/docs", 10),
            ]
        )

    driver, profile_dir = make_driver(
        headed=args.headed,
        viewport_width=args.viewport_width,
        viewport_height=args.viewport_height,
        device_scale_factor=args.device_scale_factor,
    )
    try:
        seed_auth(driver, app_url, token, user_profile)
        bootstrap_authenticated_app(driver, app_url)
        capture_routes(driver, app_url, output_dir, routes)
    finally:
        driver.quit()
        subprocess.run(["rm", "-rf", profile_dir], check=False)
        if server_process is not None:
            server_process.terminate()
            try:
                server_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server_process.kill()

    manifest_path = output_dir / "store-screen-manifest.json"
    manifest = {
        "app_url": app_url,
        "api_base": args.api_base.strip(),
        "project_id": args.project_id.strip(),
        "screens": [filename for filename, _, _ in routes],
        "captured_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Wrote {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
