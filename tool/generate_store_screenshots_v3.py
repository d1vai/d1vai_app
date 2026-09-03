#!/usr/bin/env python3
"""Generate an editorial App Store screenshot story from the finished captures.

The design deliberately keeps the product UI dominant.  Each of the six slides
has a distinct editorial composition, while the Watch set remains the genuine
localized Watch UI because its small canvas cannot carry useful extra copy.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import unicodedata
from pathlib import Path

if Path("/tmp/d1v-i18n").is_dir():
    sys.path.insert(0, "/tmp/d1v-i18n")
try:
    import arabic_reshaper
except ImportError:
    arabic_reshaper = None


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "store-assets-v2" / "app-store"
OUTPUT = ROOT / "docs" / "store-assets-v3" / "app-store"
PAGES = ("01-home", "02-terminal", "03-community", "04-profile", "05-project", "06-chat")
ACCENTS = ("#FF4FA1", "#40D986", "#35B8FF", "#F4A34D", "#A58CFF", "#F25F76")
FONT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
FONT_BY_LOCALE = {
    "zh": "/System/Library/Fonts/Hiragino Sans GB.ttc", "zh_Hant": "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "ja": "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc", "ko": "/System/Library/Fonts/Supplemental/AppleGothic.ttf",
    "ar": "/System/Library/Fonts/GeezaPro.ttc", "fa": "/System/Library/Fonts/GeezaPro.ttc",
    "hi": "/System/Library/Fonts/Kohinoor.ttc", "bn": "/System/Library/Fonts/KohinoorBangla.ttc",
    "th": "/System/Library/Fonts/ThonburiUI.ttc",
}
RTL = {"ar", "fa", "he"}

# A single, readable benefit per screen. These are editorial titles, not a UI translation.
COPY = {
 "en": ("Build from anywhere", "A terminal that travels", "Projects, clearly organized", "Your workspace, your way", "Every detail, in view", "AI that knows the work"),
 "zh": ("随时随地开始构建", "随身携带的终端", "项目，清晰有序", "按你的方式工作", "每个细节，尽在掌握", "真正理解工作的 AI"),
 "zh_Hant": ("隨時隨地開始構建", "隨身攜帶的終端機", "專案，清晰有序", "依你的方式工作", "每個細節，盡在掌握", "真正理解工作的 AI"),
 "es": ("Crea desde cualquier lugar", "Un terminal que te acompaña", "Proyectos, bien organizados", "Tu espacio, a tu manera", "Cada detalle, a la vista", "IA que conoce tu trabajo"),
 "fr": ("Créez d'où vous voulez", "Un terminal qui vous suit", "Des projets bien organisés", "Votre espace, à votre façon", "Chaque détail sous les yeux", "Une IA qui connaît le travail"),
 "de": ("Entwickeln. Überall.", "Ein Terminal für unterwegs", "Projekte klar organisiert", "Dein Workspace, deine Art", "Jedes Detail im Blick", "KI, die deine Arbeit kennt"),
 "pt_BR": ("Crie de qualquer lugar", "Um terminal que vai com você", "Projetos bem organizados", "Seu espaço, do seu jeito", "Cada detalhe à vista", "IA que entende seu trabalho"),
 "pt_PT": ("Crie a partir de qualquer lugar", "Um terminal que vai consigo", "Projetos bem organizados", "O seu espaço, à sua maneira", "Cada detalhe à vista", "IA que conhece o seu trabalho"),
 "ja": ("どこからでも、つくる", "持ち歩けるターミナル", "プロジェクトを、整然と", "自分らしいワークスペース", "細部まで、見渡せる", "仕事を理解するAI"),
 "ko": ("어디서나 만들기", "함께 다니는 터미널", "프로젝트를 깔끔하게", "나만의 작업 공간", "모든 세부 사항을 한눈에", "업무를 이해하는 AI"),
 "ru": ("Создавайте откуда угодно", "Терминал всегда с вами", "Проекты в полном порядке", "Ваше пространство, ваши правила", "Все детали на виду", "ИИ, который знает работу"),
 "ar": ("ابنِ من أي مكان", "طرفية ترافقك أينما ذهبت", "مشاريع منظمة بوضوح", "مساحة عملك بطريقتك", "كل تفصيلة أمامك", "ذكاء اصطناعي يفهم عملك"),
 "hi": ("कहीं से भी बनाइए", "टर्मिनल जो साथ चले", "प्रोजेक्ट, स्पष्ट और व्यवस्थित", "आपका कार्यक्षेत्र, आपका तरीका", "हर विवरण, नज़र में", "काम को समझने वाला AI"),
 "id": ("Bangun dari mana saja", "Terminal yang selalu bersama Anda", "Proyek tertata jelas", "Ruang kerja sesuai cara Anda", "Setiap detail terlihat", "AI yang memahami pekerjaan"),
 "th": ("สร้างได้จากทุกที่", "เทอร์มินัลที่ไปกับคุณ", "โปรเจกต์เป็นระเบียบ", "พื้นที่ทำงานในแบบคุณ", "เห็นทุกรายละเอียด", "AI ที่เข้าใจงานของคุณ"),
 "vi": ("Xây dựng từ mọi nơi", "Terminal luôn đồng hành", "Dự án được sắp xếp rõ ràng", "Không gian làm việc theo cách bạn", "Mọi chi tiết trong tầm mắt", "AI hiểu công việc của bạn"),
 "tr": ("Her yerden geliştirin", "Sizinle giden terminal", "Projeler, net biçimde düzenli", "Çalışma alanınız, tarzınız", "Her ayrıntı göz önünde", "İşinizi bilen yapay zeka"),
 "it": ("Crea da qualsiasi luogo", "Un terminale sempre con te", "Progetti organizzati con chiarezza", "Il tuo spazio, a modo tuo", "Ogni dettaglio in vista", "IA che conosce il tuo lavoro"),
 "nl": ("Bouw vanaf elke plek", "Een terminal die meereist", "Projecten helder geordend", "Jouw werkplek, jouw manier", "Elk detail in beeld", "AI die je werk kent"),
 "pl": ("Twórz skądkolwiek chcesz", "Terminal, który jest z tobą", "Projekty w idealnym porządku", "Twoja przestrzeń, twoje zasady", "Każdy szczegół na widoku", "AI, które zna twoją pracę"),
 "sv": ("Bygg var du än är", "En terminal som följer med", "Projekt, tydligt organiserade", "Din arbetsyta, på ditt sätt", "Varje detalj i blickfånget", "AI som känner ditt arbete"),
 "cs": ("Tvořte odkudkoli", "Terminál, který cestuje s vámi", "Projekty přehledně uspořádané", "Váš prostor, váš způsob", "Každý detail na očích", "AI, které zná vaši práci"),
 "he": ("בונים מכל מקום", "טרמינל שנוסע איתך", "פרויקטים מאורגנים בבירור", "מרחב העבודה שלך, בדרך שלך", "כל פרט מול העיניים", "AI שמבין את העבודה שלך"),
 "uk": ("Створюйте звідусіль", "Термінал, що завжди з вами", "Проєкти чітко впорядковані", "Ваш простір, ваші правила", "Кожна деталь на виду", "ШІ, що знає вашу роботу"),
 "da": ("Byg hvor som helst", "En terminal, der rejser med", "Projekter, klart organiseret", "Dit arbejdsrum, din måde", "Hver detalje i sigte", "AI, der kender dit arbejde"),
 "nb": ("Bygg fra hvor som helst", "En terminal som blir med", "Prosjekter, tydelig organisert", "Arbeidsflaten din, på din måte", "Hver detalj i sikte", "KI som kjenner arbeidet ditt"),
 "fi": ("Rakenna mistä tahansa", "Pääte, joka kulkee mukana", "Projektit selkeästi järjestyksessä", "Työtilasi, omalla tavallasi", "Jokainen yksityiskohta näkyvissä", "Työsi tunteva tekoäly"),
 "ro": ("Construiește de oriunde", "Un terminal care te însoțește", "Proiecte organizate clar", "Spațiul tău, în felul tău", "Fiecare detaliu la vedere", "AI care îți cunoaște munca"),
 "hu": ("Építs bárhonnan", "Egy terminál, amely veled utazik", "Projektek, átláthatóan rendezve", "A munkatered, a te módodon", "Minden részlet szem előtt", "MI, amely ismeri a munkád"),
 "el": ("Δημιούργησε από οπουδήποτε", "Ένα τερματικό που ταξιδεύει μαζί σου", "Έργα οργανωμένα με σαφήνεια", "Ο χώρος σου, με τον τρόπο σου", "Κάθε λεπτομέρεια μπροστά σου", "AI που γνωρίζει τη δουλειά σου"),
 "bg": ("Създавайте отвсякъде", "Терминал, който пътува с вас", "Проекти, ясно организирани", "Вашето пространство, вашият начин", "Всеки детайл на видно място", "AI, който познава работата ви"),
 "fa": ("از هر جایی بسازید", "ترمینالی که همراه شماست", "پروژه‌ها، منظم و روشن", "فضای کار شما، به شیوه شما", "هر جزئیات، پیش روی شما", "هوش مصنوعی که کار شما را می‌شناسد"),
 "bn": ("যেকোনো জায়গা থেকে তৈরি করুন", "একটি টার্মিনাল, সবসময় সঙ্গে", "প্রজেক্ট, গুছানো ও স্পষ্ট", "আপনার কর্মক্ষেত্র, আপনার মতো", "প্রতিটি বিস্তারিত চোখের সামনে", "আপনার কাজ বোঝে এমন AI"),
 "ms": ("Bina dari mana-mana", "Terminal yang sentiasa bersama anda", "Projek tersusun dengan jelas", "Ruang kerja anda, cara anda", "Setiap perincian dalam pandangan", "AI yang memahami kerja anda"),
 "fil": ("Bumuo mula saanman", "Terminal na laging kasama", "Mga proyektong malinaw ang ayos", "Workspace mo, paraan mo", "Bawat detalye, kita", "AI na alam ang trabaho mo"),
}


def run(*args: str) -> None:
    subprocess.run(("magick", *args), check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def caption(locale: str, value: str, width: int, height: int, point: int, color: str, gravity: str, path: Path) -> None:
    has_rtl = any(unicodedata.bidirectional(char) in {"R", "AL", "AN"} for char in value)
    if has_rtl and locale in {"ar", "fa"}:
        if arabic_reshaper is None:
            raise SystemExit("RTL rendering requires arabic-reshaper (pip install arabic-reshaper)")
        # ImageMagick's caption delegate paints in logical LTR order. Shape the
        # contextual Arabic forms first, then provide their visual glyph order.
        value = arabic_reshaper.reshape(value)[::-1]
    elif has_rtl and locale == "he":
        value = value[::-1]
    run("-background", "none", "-fill", color, "-font", FONT_BY_LOCALE.get(locale, FONT), "-pointsize", str(point),
        "-size", f"{width}x{height}", "-gravity", gravity, f"caption:{value}", str(path))


def card(source: Path, width: int, height: int, radius: int, output: Path, work: Path) -> None:
    scaled, mask, shadow = work / "screen.png", work / "mask.png", work / "shadow.png"
    run(str(source), "-resize", f"{width}x{height}!", str(scaled))
    run("-size", f"{width}x{height}", "xc:black", "-fill", "white", "-draw", f"roundrectangle 0,0 {width-1},{height-1} {radius},{radius}", str(mask))
    run(str(scaled), str(mask), "-compose", "copy_opacity", "-composite", str(work / "masked.png"))
    run(str(work / "masked.png"), "-bordercolor", "none", "-border", "1", "-background", "#000000", "-shadow", "45x18+0+22", str(shadow))
    run("-size", f"{width+80}x{height+110}", "xc:none", str(shadow), "-geometry", "+40+12", "-composite", str(work / "card-shadow.png"))
    run(str(work / "card-shadow.png"), str(work / "masked.png"), "-geometry", "+40+0", "-composite", str(output))


def surface(width: int, height: int, accent: str, index: int, output: Path) -> None:
    # Solid architectural color fields, not a reusable gradient template.
    args = ["-size", f"{width}x{height}", "xc:#0B1020", "-fill", accent]
    if index == 0: args += ["-draw", f"rectangle 0,0 {width},30", "-fill", "#121A31", "-draw", f"rectangle 0,30 {width},{int(height*.17)}"]
    elif index == 1: args += ["-draw", f"polygon 0,0 {int(width*.42)},0 0,{int(height*.44)}"]
    elif index == 2: args += ["-draw", f"rectangle 0,{int(height*.08)} {int(width*.055)},{height}"]
    elif index == 3: args += ["-draw", f"rectangle {int(width*.80)},0 {width},{height}"]
    elif index == 4: args += ["-draw", f"rectangle 0,{int(height*.73)} {width},{height}"]
    else: args += ["-draw", f"rectangle 0,0 {width},{int(height*.10)}"]
    args += [str(output)]
    run(*args)


def sanitize_profile(source: Path, device: str, output: Path) -> None:
    """Remove account-specific values while preserving localized field labels."""
    regions = {
        "iphone-6.5": ((105, 690, 1175, 737), (105, 842, 1175, 889), (105, 1250, 1175, 1320), (105, 1398, 1175, 1470)),
        "ipad-13": ((470, 610, 1710, 665), (470, 785, 1710, 840), (470, 1215, 1710, 1295), (470, 1388, 1710, 1468)),
        "apple-watch": ((106, 112, 330, 124), (106, 145, 330, 157), (106, 230, 330, 240), (106, 261, 330, 271)),
    }
    fill = "#0F1729"
    draw = " ".join(f"rectangle {x1},{y1} {x2},{y2}" for x1, y1, x2, y2 in regions[device])
    run(str(source), "-fill", fill, "-stroke", fill, "-draw", draw, str(output))


def place(base: Path, overlay: Path, x: int, y: int, output: Path) -> None:
    run(str(base), str(overlay), "-gravity", "northwest", "-geometry", f"+{x}+{y}", "-composite", str(output))


def compose(locale: str, index: int, device: str, source: Path, output: Path, work: Path) -> None:
    dims = {"iphone-6.5": (1284, 2778, 1080, 2230, 66, 52), "ipad-13": (2064, 2752, 1750, 2100, 84, 48)}
    width, height, sw, sh, point, radius = dims[device]
    accent = ACCENTS[index]
    base, text, tag, page = work / "base.png", work / "title.png", work / "tag.png", work / "page.png"
    surface(width, height, accent, index, base)
    gravity = "east" if locale in RTL else "west"
    title_width = width - 190 if device == "iphone-6.5" else 960
    title_height = 260 if device == "iphone-6.5" else 370
    caption(locale, COPY[locale][index], title_width, title_height, point, "#F8FAFF", gravity, text)
    caption(locale, "D1V  /  AI CODING WORKSPACE", title_width, 46, 20 if device == "iphone-6.5" else 24, "#B7C2DE", gravity, tag)
    caption(locale, f"0{index+1}  /  06", 180, 46, 18 if device == "iphone-6.5" else 22, accent, "east", page)
    screen = work / "screen-card.png"
    card_source = source
    if index == 3:
        card_source = work / "sanitized-profile.png"
        sanitize_profile(source, device, card_source)
    card(card_source, sw, sh, radius, screen, work)
    # Six intentional layouts; all retain a large, accurate product screen.
    if device == "iphone-6.5":
        variants = ((102, 76, 102, 136, 102, 470), (120, 120, 120, 182, 102, 505), (116, 82, 116, 142, 116, 468),
                    (104, 94, 104, 156, 102, 492), (106, 86, 106, 148, 102, 438), (102, 84, 102, 145, 102, 468))
    else:
        variants = ((150, 135, 150, 205, 157, 488), (150, 165, 150, 235, 157, 550), (180, 135, 180, 205, 157, 488),
                    (150, 160, 150, 230, 157, 515), (150, 130, 150, 200, 157, 445), (150, 135, 150, 205, 157, 488))
    tx, ty, gx, gy, sx, sy = variants[index]
    if locale in RTL:
        tx = width - tx - title_width
        gx = width - gx - title_width
    step1, step2, step3 = work / "one.png", work / "two.png", work / "three.png"
    place(base, tag, gx, gy, step1)
    place(step1, text, tx, ty, step2)
    place(step2, page, width - 230, 82 if device == "iphone-6.5" else 142, step3)
    place(step3, screen, sx, sy, output)
    run(str(output), "-background", "#0B1020", "-alpha", "remove", "-alpha", "off", str(output))


def main() -> None:
    if not shutil.which("magick"):
        raise SystemExit("ImageMagick is required")
    locales = sorted(path.name for path in (SOURCE / "iphone-6.5" / "screenshots").iterdir() if path.is_dir())
    if set(locales) != set(COPY):
        raise SystemExit(f"COPY locale mismatch: sources={len(locales)} copy={len(COPY)}")
    manifest_only = "--manifest-only" in sys.argv[1:]
    page_filter = next((arg.split("=", 1)[1] for arg in sys.argv[1:] if arg.startswith("--page=")), None)
    if page_filter and page_filter not in PAGES:
        raise SystemExit(f"Unknown page: {page_filter}")
    requested = {arg for arg in sys.argv[1:] if not arg.startswith("--")}
    if requested:
        unknown = requested - set(locales)
        if unknown:
            raise SystemExit(f"Unknown locale(s): {', '.join(sorted(unknown))}")
        locales = [locale for locale in locales if locale in requested]
    manifest = {"version": 3, "concept": "editorial product-led story", "devices": {}, "locales": {}}
    for locale in locales:
        manifest["locales"][locale] = {}
        for index, page in enumerate(PAGES):
            if page_filter and page != page_filter:
                continue
            details = {"headline": COPY[locale][index]}
            for device in ("iphone-6.5", "ipad-13"):
                src = SOURCE / device / "screenshots" / locale / f"{page}.png"
                dest = OUTPUT / device / "screenshots" / locale / f"{page}.png"
                if not manifest_only:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    work = OUTPUT / ".work" / locale / device / page
                    work.mkdir(parents=True, exist_ok=True)
                    compose(locale, index, device, src, dest, work)
                    shutil.rmtree(work)
                details[device] = str(dest.relative_to(OUTPUT))
            # The Watch source is already a native localized app capture at Apple's exact size.
            watch_src = SOURCE / "apple-watch" / "ultra-3-422x514" / "screenshots" / locale / f"{page}.png"
            watch_dest = OUTPUT / "apple-watch" / "ultra-3-422x514" / "screenshots" / locale / f"{page}.png"
            if not manifest_only:
                watch_dest.parent.mkdir(parents=True, exist_ok=True)
                if index == 3:
                    sanitize_profile(watch_src, "apple-watch", watch_dest)
                else:
                    shutil.copy2(watch_src, watch_dest)
            details["apple-watch"] = str(watch_dest.relative_to(OUTPUT))
            manifest["locales"][locale][page] = details
    manifest["devices"] = {"iphone-6.5": "1284x2778", "ipad-13": "2064x2752", "apple-watch-ultra-3": "422x514"}
    if not requested:
        (OUTPUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
