#!/usr/bin/env python3
"""Generate localized Apple Watch companion UI mockups.

The Flutter repository does not contain a watchOS target, so these assets are
design mockups, not simulator captures. They deliberately use compact Watch UI
patterns rather than resizing the iPhone application.
"""

from __future__ import annotations

import argparse
import json
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

try:
    import arabic_reshaper
    from bidi.algorithm import get_display
except ImportError:
    arabic_reshaper = None
    get_display = None


ROOT = Path(__file__).resolve().parent.parent
ARB_ROOT = ROOT / "lib" / "l10n" / "arb"
DEFAULT_OUTPUT = (
    ROOT
    / "docs"
    / "store-assets-v2"
    / "app-store"
    / "apple-watch"
    / "ultra-3-422x514"
    / "screenshots"
)
WIDTH, HEIGHT = 422, 514
RTL = {"ar", "fa", "he"}
LOCALES = (
    "en", "zh", "zh_Hant", "es", "fr", "de", "pt_BR", "pt_PT", "ja",
    "ko", "ru", "ar", "hi", "id", "th", "vi", "tr", "it", "nl", "pl",
    "sv", "cs", "he", "uk", "da", "nb", "fi", "ro", "hu", "el", "bg",
    "fa", "bn", "ms", "fil",
)
SCREENS = (
    "01-home", "02-terminal", "03-community", "04-profile", "05-project", "06-chat"
)

COLORS = {
    "bg": "#05070D",
    "surface": "#10141E",
    "surface_2": "#171D29",
    "line": "#2A3242",
    "text": "#F5F7FC",
    "muted": "#98A2B5",
    "pink": "#FF5BA7",
    "green": "#42D392",
    "blue": "#7E8CFF",
    "orange": "#F2A55F",
}

FONT_DEFAULT = Path("/System/Library/Fonts/SFCompact.ttf")
FONT_MONO = Path("/System/Library/Fonts/SFNSMono.ttf")
FONT_UNICODE = Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf")
FONT_BY_LOCALE = {
    "zh": Path("/System/Library/Fonts/Hiragino Sans GB.ttc"),
    "zh_Hant": Path("/System/Library/Fonts/Hiragino Sans GB.ttc"),
    "ja": Path("/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"),
    "ko": Path("/System/Library/Fonts/AppleSDGothicNeo.ttc"),
    "ar": FONT_UNICODE,
    "fa": FONT_UNICODE,
    "he": FONT_UNICODE,
    "hi": Path("/System/Library/Fonts/Kohinoor.ttc"),
    "bn": Path("/System/Library/Fonts/KohinoorBangla.ttc"),
    "th": Path("/System/Library/Fonts/ThonburiUI.ttc"),
}


@lru_cache(maxsize=None)
def load_font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


def load_arb(locale: str) -> dict[str, str]:
    path = ARB_ROOT / f"app_{locale}.arb"
    with path.open(encoding="utf-8") as handle:
        return {k: v for k, v in json.load(handle).items() if not k.startswith("@")}


class Canvas:
    def __init__(self, locale: str, strings: dict[str, str]) -> None:
        self.locale = locale
        self.strings = strings
        self.image = Image.new("RGB", (WIDTH, HEIGHT), COLORS["bg"])
        self.draw = ImageDraw.Draw(self.image)
        self.font_path = FONT_BY_LOCALE.get(locale, FONT_DEFAULT)
        self.rtl = locale in RTL

    def font(self, size: int, mono: bool = False) -> ImageFont.FreeTypeFont:
        path = FONT_MONO if mono else self.font_path
        return load_font(str(path), size)

    def value(self, key: str, fallback: str) -> str:
        value = self.strings.get(key, fallback)
        return value if isinstance(value, str) else fallback

    def text(
        self,
        xy: tuple[int, int],
        value: str,
        size: int,
        fill: str = COLORS["text"],
        *,
        bold: bool = False,
        max_width: int | None = None,
        anchor: str | None = None,
        mono: bool = False,
    ) -> None:
        font = self.font(size + (1 if bold else 0), mono=mono)
        if self.rtl:
            if arabic_reshaper is None or get_display is None:
                raise RuntimeError(
                    "RTL rendering requires tool/requirements-store-screenshots.txt"
                )
            value = get_display(arabic_reshaper.reshape(value))
        if max_width:
            while size > 12 and self.draw.textbbox((0, 0), value, font=font)[2] > max_width:
                size -= 1
                font = self.font(size + (1 if bold else 0), mono=mono)
            if self.draw.textbbox((0, 0), value, font=font)[2] > max_width:
                original = value
                for cutoff in range(len(original) - 1, 0, -1):
                    candidate = original[:cutoff].rstrip() + "..."
                    if self.draw.textbbox((0, 0), candidate, font=font)[2] <= max_width:
                        value = candidate
                        break
        kwargs: dict[str, object] = {"font": font, "fill": fill}
        if anchor:
            kwargs["anchor"] = anchor
        self.draw.text(xy, value, **kwargs)

    def header(self, title: str, accent: str, status: str | None = None) -> None:
        self.text((30, 18), "9:41", 15, COLORS["muted"], bold=True)
        self.draw.ellipse((198, 22, 224, 26), fill=COLORS["line"])
        self.draw.ellipse((376, 18, 384, 26), fill=accent)
        self.text((30, 53), title, 30, bold=True, max_width=300)
        if status:
            self.draw.rounded_rectangle((326, 55, 390, 82), radius=13, fill="#17251F")
            self.draw.ellipse((339, 65, 347, 73), fill=COLORS["green"])
            self.text((356, 68), status, 12, COLORS["green"], max_width=28, anchor="lm")

    def card(self, box: tuple[int, int, int, int], accent: str | None = None) -> None:
        self.draw.rounded_rectangle(box, radius=18, fill=COLORS["surface"], outline=COLORS["line"], width=1)
        if accent:
            x1, y1, _, y2 = box
            self.draw.rounded_rectangle((x1, y1 + 12, x1 + 5, y2 - 12), radius=3, fill=accent)

    def footer_dots(self, active: int) -> None:
        x0 = 180
        for index in range(3):
            radius = 4 if index == active else 3
            fill = COLORS["text"] if index == active else COLORS["line"]
            x = x0 + index * 28
            self.draw.ellipse((x - radius, 488 - radius, x + radius, 488 + radius), fill=fill)


def home(c: Canvas) -> None:
    c.header(c.value("dashboard", "Dashboard"), COLORS["pink"])
    c.card((24, 101, 398, 210), COLORS["pink"])
    c.text((47, 120), c.value("recent_projects", "Recent Projects"), 16, COLORS["muted"], max_width=290)
    c.text((47, 151), "africa-client-dev-system", 21, bold=True, max_width=302)
    c.draw.ellipse((48, 185, 58, 195), fill=COLORS["green"])
    c.text((67, 190), c.value("project_overview_status_active", "Active"), 14, COLORS["green"], anchor="lm", max_width=120)
    c.text((370, 190), c.value("just_now", "Just now"), 13, COLORS["muted"], anchor="rm", max_width=90)
    c.text((30, 237), c.value("activity", "Activity"), 18, bold=True, max_width=220)
    for y, color, title, detail in (
        (272, COLORS["green"], c.value("project_overview_recent_deployments_title", "Recent deployments"), "main  #284"),
        (347, COLORS["blue"], c.value("project_detail_tab_chat", "Chat"), c.value("chat_status_done", "Done")),
        (422, COLORS["orange"], c.value("community", "Community"), c.value("project_overview_community_status_published", "Published")),
    ):
        c.card((24, y, 398, y + 59))
        c.draw.ellipse((43, y + 22, 55, y + 34), fill=color)
        c.text((69, y + 17), title, 15, bold=True, max_width=230)
        c.text((69, y + 39), detail, 12, COLORS["muted"], max_width=220)
        c.text((375, y + 30), ">", 20, COLORS["muted"], anchor="mm")


def terminal(c: Canvas) -> None:
    c.header(c.value("terminal", "Terminal"), COLORS["green"], c.value("chat_status_ready", "Ready"))
    c.card((24, 101, 398, 382), COLORS["green"])
    c.text((47, 120), "africa-client-dev-system", 15, COLORS["muted"], max_width=300, mono=True)
    rows = (
        ("$ git status", COLORS["text"]),
        ("On branch dev", COLORS["muted"]),
        ("$ npm run test", COLORS["text"]),
        ("PASS  src/api/project.test.ts", COLORS["green"]),
        ("12 tests passed  1.8s", COLORS["muted"]),
        ("$ _", COLORS["pink"]),
    )
    y = 163
    for value, color in rows:
        c.text((47, y), value, 15, color, max_width=320, mono=True)
        y += 34
    c.draw.rounded_rectangle((24, 405, 398, 466), radius=24, fill=COLORS["surface_2"])
    c.text((48, 436), c.value("terminal_input_hint", "Run a command"), 15, COLORS["muted"], anchor="lm", max_width=270)
    c.draw.ellipse((347, 417, 385, 455), fill=COLORS["green"])
    c.text((366, 436), ">", 21, COLORS["bg"], bold=True, anchor="mm")
    c.footer_dots(1)


def community(c: Canvas) -> None:
    c.header(c.value("community", "Community"), COLORS["blue"])
    cards = (
        (101, "Mina", "Design system starter", COLORS["pink"], "128"),
        (220, "Alex", "Realtime dashboard", COLORS["green"], "86"),
        (339, "D1V", "Africa client dev", COLORS["orange"], "42"),
    )
    for y, author, title, color, stars in cards:
        c.card((24, y, 398, y + 101))
        c.draw.ellipse((43, y + 19, 77, y + 53), fill=color)
        c.text((60, y + 36), author[0], 16, COLORS["bg"], bold=True, anchor="mm")
        c.text((91, y + 20), author, 14, COLORS["muted"], max_width=155)
        c.text((91, y + 48), title, 17, bold=True, max_width=250)
        c.text((91, y + 77), c.value("project_overview_community_status_published", "Published"), 12, color, max_width=180)
        c.text((370, y + 77), f"+ {stars}", 12, COLORS["muted"], anchor="ra")
    c.footer_dots(2)


def profile(c: Canvas) -> None:
    c.header(c.value("profile", "Profile"), COLORS["orange"])
    c.card((24, 101, 398, 212))
    c.draw.ellipse((43, 120, 113, 190), fill=COLORS["pink"])
    c.text((78, 155), "D1", 22, COLORS["bg"], bold=True, anchor="mm")
    c.text((134, 126), "D1V Builder", 20, bold=True, max_width=225)
    c.text((134, 158), "builder@d1v.ai", 14, COLORS["muted"], max_width=225)
    c.draw.ellipse((135, 185, 145, 195), fill=COLORS["green"])
    c.text((154, 190), c.value("project_overview_status_active", "Active"), 13, COLORS["green"], anchor="lm", max_width=120)
    c.text((30, 238), c.value("settings", "Settings"), 18, bold=True, max_width=230)
    rows = (
        (c.value("upgrade_credits", "Credits"), "2,480", COLORS["pink"]),
        (c.value("github", "GitHub"), c.value("connected", "Connected"), COLORS["green"]),
        (c.value("notifications", "Notifications"), c.value("project_overview_health_status_enabled", "Enabled"), COLORS["blue"]),
    )
    y = 271
    for title, value, color in rows:
        c.card((24, y, 398, y + 58))
        c.draw.ellipse((43, y + 23, 53, y + 33), fill=color)
        c.text((68, y + 29), title, 15, anchor="lm", max_width=190)
        c.text((375, y + 29), value, 13, COLORS["muted"], anchor="rm", max_width=120)
        y += 69
    c.footer_dots(0)


def project(c: Canvas) -> None:
    c.header(c.value("projects_title", "Projects"), COLORS["blue"], c.value("project_overview_status_active", "Active"))
    c.text((30, 103), "africa-client-dev-system", 22, bold=True, max_width=360)
    c.text((30, 134), "dev  /  main", 14, COLORS["muted"], mono=True)
    c.card((24, 165, 398, 276), COLORS["blue"])
    c.text((47, 184), c.value("project_detail_tab_overview", "Overview"), 16, COLORS["muted"], max_width=260)
    c.text((47, 215), c.value("project_overview_health_title", "Health metrics"), 20, bold=True, max_width=290)
    for x, label, color in (
        (48, c.value("project_overview_health_database", "Database"), COLORS["green"]),
        (185, c.value("project_overview_health_analytics", "Analytics"), COLORS["blue"]),
    ):
        c.draw.ellipse((x, 251, x + 9, 260), fill=color)
        c.text((x + 16, 256), label, 12, COLORS["muted"], anchor="lm", max_width=112)
    c.text((30, 303), c.value("project_overview_recent_deployments_title", "Recent deployments"), 18, bold=True, max_width=340)
    c.card((24, 338, 398, 397))
    c.draw.ellipse((43, 361, 55, 373), fill=COLORS["green"])
    c.text((70, 356), "Production  #284", 15, bold=True, max_width=225)
    c.text((70, 379), c.value("just_now", "Just now"), 12, COLORS["muted"], max_width=180)
    c.draw.rounded_rectangle((24, 421, 398, 470), radius=22, fill=COLORS["blue"])
    c.text((211, 446), c.value("project_deploy_action_deploy_prod", "Deploy production"), 16, COLORS["bg"], bold=True, anchor="mm", max_width=315)
    c.footer_dots(1)


def chat(c: Canvas) -> None:
    c.header(c.value("chat_with_ai_title", "Chat with AI"), COLORS["orange"], c.value("chat_status_ready", "Ready"))
    c.text((30, 97), "africa-client-dev-system", 13, COLORS["muted"], max_width=340, mono=True)
    c.draw.rounded_rectangle((24, 129, 330, 206), radius=18, fill=COLORS["surface_2"])
    c.text((43, 146), c.value("chat_empty_subtitle", "Ask about this project or paste code."), 15, max_width=264)
    c.text((43, 184), "YOU", 11, COLORS["muted"], bold=True)
    c.draw.rounded_rectangle((72, 222, 398, 322), radius=18, fill="#202844", outline="#39476E")
    c.text((91, 240), c.value("chat_banner_working_request", "Working through your request."), 15, max_width=278)
    c.text((91, 282), c.value("chat_banner_preview_rebuilding", "Preview is rebuilding."), 14, COLORS["muted"], max_width=278)
    c.text((374, 301), "AI", 11, COLORS["blue"], bold=True, anchor="ra")
    c.draw.rounded_rectangle((24, 340, 360, 393), radius=18, fill=COLORS["surface_2"])
    c.text((43, 356), c.value("chat_banner_send_next_message", "You can send the next message."), 14, max_width=288)
    c.draw.rounded_rectangle((24, 419, 398, 470), radius=23, fill=COLORS["surface"])
    c.text((46, 445), c.value("chat_input_hint", "Type your message..."), 14, COLORS["muted"], anchor="lm", max_width=270)
    c.draw.ellipse((347, 426, 385, 464), fill=COLORS["orange"])
    c.text((366, 445), ">", 21, COLORS["bg"], bold=True, anchor="mm")
    c.footer_dots(2)


RENDERERS = (home, terminal, community, profile, project, chat)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--locales", default=",".join(LOCALES))
    args = parser.parse_args()
    locales = tuple(item.strip() for item in args.locales.split(",") if item.strip())
    manifest: dict[str, object] = {
        "artifact_type": "watch_ui_mockup",
        "not_simulator_capture": True,
        "requires_watchos_target_for_app_store_submission": True,
        "device": "Apple Watch Ultra 3",
        "dimensions": f"{WIDTH}x{HEIGHT}",
        "locales": {},
    }
    for locale in locales:
        strings = load_arb(locale)
        locale_dir = args.output_dir / locale
        locale_dir.mkdir(parents=True, exist_ok=True)
        outputs: list[str] = []
        for filename, renderer in zip(SCREENS, RENDERERS):
            canvas = Canvas(locale, strings)
            renderer(canvas)
            output = locale_dir / f"{filename}.png"
            canvas.image.save(output, format="PNG", compress_level=6)
            outputs.append(str(output.relative_to(args.output_dir)))
        manifest["locales"][locale] = outputs
    manifest_path = args.output_dir.parent / "watch-mockup-manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(locales) * len(SCREENS)} Watch companion mockups in {args.output_dir}")


if __name__ == "__main__":
    main()
