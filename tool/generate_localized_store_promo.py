#!/usr/bin/env python3
"""Build localized, store-ready promotional screenshots from captured D1V UI.

The source captures stay untouched. Output files are written below each locale's
``app-store`` directory so they can be uploaded directly to App Store Connect.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE_ROOT = ROOT / "docs" / "localized-screenshots"
WATCH_SOURCE = (
    ROOT
    / "docs"
    / "store-assets-v2"
    / "app-store"
    / "apple-watch"
    / "ultra-3-422x514"
)
ICON = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset" / "1024.png"

SCREENS = (
    ("01-home", "home-screen.png", "#FF5BA7"),
    ("02-terminal", "terminal-screen.png", "#35D07F"),
    ("03-project", "project-detail-screen.png", "#7E8CFF"),
    ("04-chat", "chat-with-ai-screen.png", "#F2A55F"),
)

# Short, outcome-led copy. Keep every line brief enough to survive thumbnail viewing.
COPY = {
    "en": ["Build. Keep moving.", "Your terminal. Anywhere.", "Every project. In view.", "AI, in project context."],
    "zh": ["开始构建，持续推进。", "终端，随时可用。", "每个项目，尽在掌握。", "AI，始终理解项目。"],
    "zh_Hant": ["開始構建，持續推進。", "終端，隨時可用。", "每個專案，盡在掌握。", "AI，始終理解專案。"],
    "es": ["Crea. Sigue avanzando.", "Tu terminal. Donde sea.", "Cada proyecto, a la vista.", "IA con contexto de proyecto."],
    "fr": ["Créez. Continuez d'avancer.", "Votre terminal, partout.", "Chaque projet en vue.", "L'IA dans le contexte du projet."],
    "de": ["Bauen. Weiterkommen.", "Dein Terminal. Überall.", "Jedes Projekt im Blick.", "KI im Projektkontext."],
    "pt_BR": ["Crie. Continue avançando.", "Seu terminal. Em qualquer lugar.", "Cada projeto à vista.", "IA no contexto do projeto."],
    "pt_PT": ["Crie. Continue a avançar.", "O seu terminal. Em qualquer lugar.", "Cada projeto à vista.", "IA no contexto do projeto."],
    "ja": ["つくる。進み続ける。", "ターミナルを、どこでも。", "すべてのプロジェクトを、見渡す。", "プロジェクトを理解するAI。"],
    "ko": ["만들고, 계속 나아가세요.", "어디서나 내 터미널.", "모든 프로젝트를 한눈에.", "프로젝트 맥락을 아는 AI."],
    "ru": ["Создавайте. Двигайтесь дальше.", "Ваш терминал. Где угодно.", "Каждый проект на виду.", "ИИ в контексте проекта."],
    "ar": ["ابنِ. وواصل التقدّم.", "طرفيتك. في أي مكان.", "كل مشروع أمامك.", "ذكاء اصطناعي يفهم المشروع."],
    "hi": ["बनाइए। आगे बढ़ते रहिए।", "आपका टर्मिनल। कहीं भी।", "हर प्रोजेक्ट, नज़र में।", "प्रोजेक्ट के संदर्भ में AI।"],
    "id": ["Bangun. Terus bergerak.", "Terminal Anda. Di mana saja.", "Setiap proyek, terlihat.", "AI dalam konteks proyek."],
    "th": ["สร้าง แล้วไปต่อ", "เทอร์มินัลของคุณ ทุกที่", "ทุกโปรเจกต์ ในมุมมอง", "AI ที่เข้าใจบริบทโปรเจกต์"],
    "vi": ["Xây dựng. Tiếp tục tiến lên.", "Terminal của bạn. Mọi nơi.", "Mọi dự án, trong tầm mắt.", "AI trong đúng ngữ cảnh dự án."],
    "tr": ["İnşa et. İlerlemeye devam et.", "Terminalin. Her yerde.", "Her proje göz önünde.", "Proje bağlamında yapay zeka."],
    "it": ["Crea. Continua a muoverti.", "Il tuo terminale. Ovunque.", "Ogni progetto, in vista.", "IA nel contesto del progetto."],
    "nl": ["Bouw. Blijf vooruitgaan.", "Je terminal. Overal.", "Elk project in beeld.", "AI in projectcontext."],
    "pl": ["Twórz. Idź dalej.", "Twój terminal. Wszędzie.", "Każdy projekt w zasięgu wzroku.", "AI w kontekście projektu."],
    "sv": ["Bygg. Fortsätt framåt.", "Din terminal. Var som helst.", "Varje projekt i blickfånget.", "AI i projektets kontext."],
    "cs": ["Tvořte. Pokračujte dál.", "Váš terminál. Kdekoli.", "Každý projekt na očích.", "AI v kontextu projektu."],
    "he": ["בונים. ממשיכים קדימה.", "המסוף שלך. בכל מקום.", "כל פרויקט מול העיניים.", "AI בהקשר של הפרויקט."],
    "uk": ["Створюйте. Рухайтеся далі.", "Ваш термінал. Будь-де.", "Кожен проєкт на виду.", "ШІ в контексті проєкту."],
    "da": ["Byg. Bliv ved.", "Din terminal. Overalt.", "Hvert projekt i sigte.", "AI i projektets kontekst."],
    "nb": ["Bygg. Fortsett fremover.", "Terminalen din. Overalt.", "Hvert prosjekt i sikte.", "KI i prosjektkontekst."],
    "fi": ["Rakenna. Jatka eteenpäin.", "Päätteesi. Missä vain.", "Jokainen projekti näkyvissä.", "Tekoäly projektin kontekstissa."],
    "ro": ["Construiește. Mergi înainte.", "Terminalul tău. Oriunde.", "Fiecare proiect, la vedere.", "AI în contextul proiectului."],
    "hu": ["Építs. Haladj tovább.", "A terminálod. Bárhol.", "Minden projekt szem előtt.", "MI a projekt kontextusában."],
    "el": ["Δημιούργησε. Συνέχισε μπροστά.", "Το τερματικό σου. Παντού.", "Κάθε έργο, μπροστά σου.", "AI στο πλαίσιο του έργου."],
    "bg": ["Създавайте. Продължавайте напред.", "Вашият терминал. Навсякъде.", "Всеки проект на фокус.", "AI в контекста на проекта."],
    "fa": ["بسازید. ادامه دهید.", "ترمینال شما. هرجا.", "هر پروژه، پیش روی شما.", "هوش مصنوعی در بستر پروژه."],
    "bn": ["তৈরি করুন। এগিয়ে যান।", "আপনার টার্মিনাল। যে কোনো জায়গায়।", "প্রতিটি প্রজেক্ট, চোখের সামনে।", "প্রজেক্টের প্রেক্ষিতে AI।"],
    "ms": ["Bina. Terus bergerak.", "Terminal anda. Di mana-mana.", "Setiap projek, dalam pandangan.", "AI dalam konteks projek."],
    "fil": ["Bumuo. Magpatuloy.", "Terminal mo. Kahit saan.", "Bawat proyekto, kita.", "AI sa konteksto ng proyekto."],
}

FONT_DEFAULT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
FONT_BY_LOCALE = {
    "zh": "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "zh_Hant": "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "ja": "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
    "ko": "/System/Library/Fonts/Supplemental/AppleGothic.ttf",
    "ar": "/System/Library/Fonts/GeezaPro.ttc",
    "fa": "/System/Library/Fonts/GeezaPro.ttc",
    "hi": "/System/Library/Fonts/Kohinoor.ttc",
    "bn": "/System/Library/Fonts/KohinoorBangla.ttc",
    "th": "/System/Library/Fonts/ThonburiUI.ttc",
}
RTL = {"ar", "fa", "he"}


def run(*args: str) -> None:
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def render_text(font: str, text: str, width: int, height: int, size: int, color: str, gravity: str, path: Path) -> None:
    run(
        "magick", "-background", "none", "-fill", color, "-font", font,
        "-pointsize", str(size), "-size", f"{width}x{height}", "-gravity", gravity,
        f"caption:{text}", str(path),
    )


def card(source: Path, width: int, height: int, radius: int, output: Path, work: Path) -> None:
    scaled = work / "scaled.png"
    shell = work / "shell.png"
    mask = work / "mask.png"
    run("magick", str(source), "-resize", f"{width}x{height}!", str(scaled))
    run(
        "magick", "-size", f"{width}x{height}", "xc:#111B34", "-stroke", "#33405C",
        "-strokewidth", "3", "-fill", "none", "-draw",
        f"roundrectangle 2,2 {width - 3},{height - 3} {radius},{radius}", str(shell),
    )
    run(
        "magick", "-size", f"{width}x{height}", "xc:black", "-fill", "white", "-draw",
        f"roundrectangle 0,0 {width - 1},{height - 1} {radius},{radius}", str(mask),
    )
    run("magick", str(scaled), str(mask), "-compose", "copy_opacity", "-composite", str(work / "masked.png"))
    run("magick", str(shell), str(work / "masked.png"), "-compose", "over", "-composite", str(output))


def base(width: int, height: int, accent: str, output: Path) -> None:
    run(
        "magick", "-size", f"{width}x{height}", "xc:#090F20", "-fill", accent,
        "-draw", f"rectangle 0,0 {width},24", "-fill", "#111A31",
        "-draw", f"rectangle 0,24 {width},{height}", "-stroke", "#26324D", "-strokewidth", "2",
        "-draw", f"line 0,{int(height * .245)} {width},{int(height * .245)}", str(output),
    )


def compose_phone(locale: str, index: int, slug: str, source: Path, accent: str, copy: str, output: Path, work: Path) -> None:
    width, height = 1284, 2778
    b = work / "base.png"
    base(width, height, accent, b)
    font = FONT_BY_LOCALE.get(locale, FONT_DEFAULT)
    gravity = "east" if locale in RTL else "west"
    x = 112 if locale not in RTL else 112
    title = work / "title.png"
    label = work / "label.png"
    render_text(font, copy, 1060, 310, 66, "#F5F7FF", gravity, title)
    render_text(font, "D1V  /  MOBILE WORKSPACE", 760, 64, 24, "#BFC9E8", gravity, label)
    card_file = work / "card.png"
    card(source, 1060, 2078, 56, card_file, work)
    label_x = x if locale not in RTL else 412
    title_x = x if locale not in RTL else 112
    run(
        "magick", str(b), str(label), "-gravity", "northwest", "-geometry", f"+{label_x}+112", "-composite",
        str(title), "-gravity", "northwest", "-geometry", f"+{title_x}+206", "-composite",
        str(card_file), "-gravity", "north", "-geometry", "+0+620", "-composite",
        "-background", "#090F20", "-alpha", "remove", "-alpha", "off", str(output),
    )


def compose_ipad(locale: str, index: int, slug: str, source: Path, accent: str, copy: str, output: Path, work: Path) -> None:
    width, height = 2064, 2752
    b = work / "base.png"
    base(width, height, accent, b)
    font = FONT_BY_LOCALE.get(locale, FONT_DEFAULT)
    gravity = "east" if locale in RTL else "west"
    title = work / "title.png"
    label = work / "label.png"
    render_text(font, copy, 1010, 530, 88, "#F5F7FF", gravity, title)
    render_text(font, "D1V  /  MOBILE WORKSPACE", 800, 70, 28, "#BFC9E8", gravity, label)
    card_file = work / "card.png"
    card(source, 900, 1766, 52, card_file, work)
    x = 146 if locale not in RTL else 908
    run(
        "magick", str(b), str(label), "-gravity", "northwest", "-geometry", f"+{x}+230", "-composite",
        str(title), "-gravity", "northwest", "-geometry", f"+{x}+326", "-composite",
        str(card_file), "-gravity", "southeast", "-geometry", "+150+250", "-composite",
        "-background", "#090F20", "-alpha", "remove", "-alpha", "off", str(output),
    )


def compose_watch(locale: str, index: int, slug: str, accent: str, copy: str, output: Path, work: Path) -> None:
    # Use the dedicated Watch companion mockup, never a resized phone capture.
    watch_names = {
        "01-home": "01-home.png",
        "02-terminal": "02-terminal.png",
        "03-project": "05-project.png",
        "04-chat": "06-chat.png",
    }
    source = WATCH_SOURCE / "screenshots" / locale / watch_names[slug]
    if not source.exists():
        raise SystemExit(f"Missing Watch companion mockup: {source}")
    font = FONT_BY_LOCALE.get(locale, FONT_DEFAULT)
    gravity = "east" if locale in RTL else "center"
    text = work / "watch-title.png"
    render_text(font, copy, 366, 66, 22, "#F5F7FF", gravity, text)
    overlay = work / "watch-overlay.png"
    run("magick", "-size", "422x128", "xc:#12203A", "-fill", accent, "-draw", "rectangle 0,0 422,5", str(overlay))
    run(
        "magick", str(source), str(overlay), "-gravity", "north", "-geometry", "+0+72", "-composite",
        str(text), "-gravity", "north", "-geometry", "+0+94", "-composite",
        "-background", "#10213B", "-alpha", "remove", "-alpha", "off", str(output),
    )


def output_paths(locale_dir: Path, slug: str) -> tuple[Path, Path, Path]:
    root = locale_dir / "app-store"
    phone = root / "iphone-6.5" / f"{slug}.png"
    ipad = root / "ipad-13" / f"{slug}.png"
    watch = root / "apple-watch" / "ultra-3-422x514" / f"{slug}.png"
    for path in (phone, ipad, watch):
        path.parent.mkdir(parents=True, exist_ok=True)
    return phone, ipad, watch


def main() -> None:
    if not shutil.which("magick"):
        raise SystemExit("ImageMagick (`magick`) is required.")
    missing = [locale for locale in COPY if not (SOURCE_ROOT / locale).is_dir()]
    if missing:
        raise SystemExit(f"Missing locale capture directories: {', '.join(missing)}")

    watch_only = "--watch-only" in sys.argv[1:]
    manifest: dict[str, object] = {"devices": {}, "locales": {}}
    for locale, headlines in COPY.items():
        locale_dir = SOURCE_ROOT / locale
        locale_outputs: dict[str, object] = {}
        for index, ((slug, source_name, accent), headline) in enumerate(zip(SCREENS, headlines)):
            source = locale_dir / source_name
            if not source.exists():
                raise SystemExit(f"Missing capture: {source}")
            phone, ipad, watch = output_paths(locale_dir, slug)
            work = locale_dir / ".store-work"
            work.mkdir(exist_ok=True)
            if not watch_only:
                compose_phone(locale, index, slug, source, accent, headline, phone, work)
                compose_ipad(locale, index, slug, source, accent, headline, ipad, work)
            compose_watch(locale, index, slug, accent, headline, watch, work)
            locale_outputs[slug] = {
                "headline": headline,
                "iphone_6_5": str(phone.relative_to(SOURCE_ROOT)),
                "ipad_13": str(ipad.relative_to(SOURCE_ROOT)),
                "watch_ultra_3": str(watch.relative_to(SOURCE_ROOT)),
            }
            shutil.rmtree(work)
        manifest["locales"][locale] = locale_outputs

    manifest["devices"] = {
        "iphone-6.5": "1284x2778",
        "ipad-13": "2064x2752",
        "apple-watch-ultra-3": "422x514",
    }
    (SOURCE_ROOT / "app-store-promo-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
