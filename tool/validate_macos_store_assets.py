#!/usr/bin/env python3

import argparse
import json
import struct
from pathlib import Path


LOCALES = (
    "en", "da", "uk", "ru", "hu", "hi", "id", "tr", "bn", "he", "el", "de",
    "it", "nb", "cs", "ja", "fr", "pl", "th", "sv", "zh", "zh_Hant", "ro", "fi",
    "nl", "pt_BR", "pt_PT", "es", "vi", "ar", "ko", "ms",
)
SCREENSHOTS = (
    "01-home.png", "02-terminal.png", "03-community.png", "04-profile.png",
    "05-project.png", "06-chat.png",
)


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate localized macOS App Store assets")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("docs/store-assets-v3/app-store/macos"),
    )
    args = parser.parse_args()

    metadata_path = args.root / "metadata.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    errors: list[str] = []

    actual_locales = set(metadata) - {"_shared"}
    if actual_locales != set(LOCALES):
        errors.append(
            f"metadata locales differ: missing={sorted(set(LOCALES) - actual_locales)}, "
            f"extra={sorted(actual_locales - set(LOCALES))}"
        )

    app_store_locales: set[str] = set()
    for locale in LOCALES:
        entry = metadata.get(locale, {})
        app_store_locale = entry.get("app_store_locale", "")
        if not app_store_locale:
            errors.append(f"{locale}: missing app_store_locale")
        elif app_store_locale in app_store_locales:
            errors.append(f"{locale}: duplicate App Store locale {app_store_locale}")
        app_store_locales.add(app_store_locale)

        for field, limit in (("promotional_text", 170), ("description", 4000), ("keywords", 100)):
            value = entry.get(field, "")
            if not value:
                errors.append(f"{locale}: missing {field}")
            elif len(value) > limit:
                errors.append(f"{locale}: {field} has {len(value)} characters (max {limit})")

        locale_dir = args.root / "screenshots" / locale
        actual_files = {path.name for path in locale_dir.glob("*.png")}
        if actual_files != set(SCREENSHOTS):
            errors.append(
                f"{locale}: screenshots differ: missing={sorted(set(SCREENSHOTS) - actual_files)}, "
                f"extra={sorted(actual_files - set(SCREENSHOTS))}"
            )
        for filename in SCREENSHOTS:
            path = locale_dir / filename
            if path.exists():
                try:
                    size = png_size(path)
                except ValueError as exc:
                    errors.append(str(exc))
                else:
                    if size != (1440, 900):
                        errors.append(f"{path}: expected 1440x900, got {size[0]}x{size[1]}")

    if errors:
        print("macOS App Store asset validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"Validated {len(LOCALES)} locales and {len(LOCALES) * len(SCREENSHOTS)} screenshots")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
