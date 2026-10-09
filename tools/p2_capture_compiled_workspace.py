"""Capture the compiled Flutter workspace after real browser loading completes."""

import argparse
import json
from pathlib import Path

from playwright.sync_api import sync_playwright


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--chrome", required=True)
    parser.add_argument("--url", default="http://127.0.0.1:8767/")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=args.chrome,
            args=["--no-sandbox", "--disable-dev-shm-usage", "--enable-unsafe-swiftshader"],
        )
        try:
            for stage in ("overview", "resized", "integrated"):
                page = browser.new_page(
                    viewport={"width": 1550, "height": 1050}, device_scale_factor=1
                )
                errors = []
                page.on("pageerror", lambda error: errors.append(str(error)))
                try:
                    response = page.goto(
                        f"{args.url}?stage={stage}",
                        wait_until="networkidle",
                        timeout=45000,
                    )
                    if response is None or response.status != 200:
                        raise RuntimeError(f"Workspace failed to load: {stage}")
                    # Wall-clock time allows CanvasKit to draw after the async
                    # asset preload. Chrome virtual-time budgets can advance
                    # past pending GPU/network work and capture a blank page.
                    page.wait_for_timeout(3000)
                    page.screenshot(
                        path=str(output / f"P2_{stage}_real_flutter_chromium.png"),
                        timeout=15000,
                    )
                    if errors:
                        raise RuntimeError(f"Flutter JS errors: {errors}")
                finally:
                    (output / f"{stage}-page-errors.json").write_text(
                        json.dumps(errors, ensure_ascii=False), encoding="utf-8"
                    )
                    page.close()
        finally:
            browser.close()


if __name__ == "__main__":
    main()
