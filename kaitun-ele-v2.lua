#!/usr/bin/env python3
# ================================================
# SATURNITY HOPPER v2.7
# @lanavienrose | github: lucivaantarez
# ================================================

import os, sys, time, json, subprocess, threading, queue, urllib.request, urllib.error, traceback
from datetime import datetime, timedelta

VERSION = "2.7"

# ── ANSI ──────────────────────────────────────────
R   = "\033[0m"
W   = "\033[97m"
G   = "\033[92m"
Y   = "\033[93m"
RD  = "\033[91m"
C   = "\033[96m"
M   = "\033[95m"
GR  = "\033[90m"
DIM = "\033[2m"

# ── PATHS ─────────────────────────────────────────
HOME        = os.path.expanduser("~")
BASE        = os.path.join(HOME, "saturnity")
CONFIG_FILE = os.path.join(BASE, "hopper_config.json")
HOP_FLAG    = os.path.join(BASE, "hop.flag")
LOG_FILE    = os.path.join(BASE, "hopper.log")

# Bug 11 fix — try/except around module-level makedirs
try:
    os.makedirs(BASE, exist_ok=True)
except Exception:
    pass

# Bug 2 fix — check both sdcard path variants
def _find_ps_file():
    candidates = [
        "/sdcard/saturnity/private_servers.txt",         # Bug 1 fix — correct filename
        "/storage/emulated/0/saturnity/private_servers.txt",
        "/sdcard/saturnity/privateserver.txt",            # legacy fallback
        "/storage/emulated/0/saturnity/privateserver.txt",
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return candidates[0]  # default write path

PS_FILE     = _find_ps_file()
SDCARD_BASE = os.path.dirname(PS_FILE)

try:
    os.makedirs(SDCARD_BASE, exist_ok=True)
except Exception:
    pass

# ── LOGGING ───────────────────────────────────────
def log_file(msg):
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}\n")
    except:
        pass

def log_error(context, e):
    tb = traceback.format_exc()
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [ERROR] {context}: {e}\n")
            f.write(f"[TRACEBACK]\n{tb}\n")
    except:
        pass
    print(f"{RD}[-]{R} {context}: {e}")
    print(f"{RD}[-]{R} Full error written to {LOG_FILE}")

def log_session_start():
    log_file("=" * 50)
    log_file(f"SESSION START — Saturnity Hopper v{VERSION}")  # Bug 14 fix
    log_file(f"Python: {sys.version.split()[0]}")
    log_file("=" * 50)

# ── PRINT HELPERS ─────────────────────────────────
def ok(msg):      print(f"{G}[+]{R} {msg}");          log_file(f"[+] {msg}")
def err(msg):     print(f"{RD}[-]{R} {msg}");         log_file(f"[-] {msg}")
def wrn(msg):     print(f"{Y}[!]{R} {msg}");          log_file(f"[!] {msg}")
def inf(msg):     print(f"{C}[~]{R} {msg}");          log_file(f"[~] {msg}")
def hop_log(msg): print(f"{M}[>]{R} {msg}");          log_file(f"[>] {msg}")
def sys_log(msg): print(f"{GR}[#]{R} {GR}{msg}{R}"); log_file(f"[#] {msg}")

def pause(msg="  press enter to continue..."):
    """Bug 15/17 fix — pause so user can read output before redraw."""
    try:
        input(f"\n{DIM}{msg}{R}")
    except (EOFError, OSError):
        time.sleep(1)

# ── DEFAULT CONFIG ─────────────────────────────────
DEFAULT_CONFIG = {
    "launch_delay":     5,
    "hop_delay":        2700,
    "heartbeat_delay":  300,
    "launch_detector":  15,
    "cooldown_hop":     600,
    "fail_limit":       5,
    "webhook_url":      "",
    "webhook_message":  "Saturnity Hopper",
    "refresh_interval": 30,
    "term_width":       0,
    "roblox_package":   "",
    "servers":          []
}

def load_config():
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE) as f:
                cfg = json.load(f)
            for k, v in DEFAULT_CONFIG.items():
                if k not in cfg:
                    cfg[k] = v
            log_file("[~] Config loaded")
            return cfg
    except Exception as e:
        log_error("load_config", e)
    return DEFAULT_CONFIG.copy()

def save_config(cfg):
    try:
        with open(CONFIG_FILE, "w") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        log_error("save_config", e)

# ── PRIVATE SERVER FILE ───────────────────────────
def load_ps_file():
    """Bug 1+2 fix — correct filename, check multiple paths."""
    path = _find_ps_file()
    if not os.path.exists(path):
        return []
    try:
        with open(path, "r") as f:
            lines = [l.strip() for l in f.readlines()]
        servers = [l for l in lines if l and not l.startswith("#") and l.startswith("http")]
        log_file(f"[~] {os.path.basename(path)}: {len(servers)} servers from {path}")
        return servers
    except Exception as e:
        log_error("load_ps_file", e)
        return []

def resolve_servers(cfg):
    """Bug 13 fix — do NOT save ps_file servers into config permanently."""
    ps_servers = load_ps_file()
    if ps_servers:
        inf(f"private_servers.txt found | {len(ps_servers)} servers")
        return ps_servers  # use but don't overwrite config

    if cfg["servers"]:
        inf(f"Using {len(cfg['servers'])} servers from config")
        return cfg["servers"]

    # manual entry
    print()
    inf("No servers found. Enter links one per line, type 'done' when finished.")
    inf(f"Or create: {PS_FILE}")
    print()
    while True:
        link = input(f"{C}  link{GR} > {R}").strip()
        if not link:
            continue
        if link.lower() == "done":
            break
        if link.startswith("http"):
            cfg["servers"].append(link)
            ok(f"Added server {len(cfg['servers'])}")
            log_file(f"[+] Server added: {link[:60]}")
        else:
            wrn("Invalid link — must start with http")
    save_config(cfg)
    return cfg["servers"]

# ── ADB ───────────────────────────────────────────
def adb(cmd):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        if r.returncode != 0 and r.stderr:
            log_file(f"[#] adb stderr: {r.stderr.strip()[:100]}")
        return r.stdout.strip()
    except subprocess.TimeoutExpired:
        log_file(f"[!] adb timeout: {cmd[:60]}")
        return ""
    except Exception as e:
        log_error("adb", e)
        return ""

def get_package(cfg):
    return cfg.get("roblox_package") or "com.roblox.client"

def search_packages(prefix):
    out = adb("pm list packages")
    results = []
    for line in out.splitlines():
        line = line.strip().replace("package:", "")
        if prefix.lower() in line.lower():
            results.append(line)
    return sorted(results)

def launch_roblox(link, cfg):
    pkg = get_package(cfg)
    log_file(f"[>] Launching: {link[:60]} | pkg: {pkg}")
    adb(f'am start -a android.intent.action.VIEW -d "{link}" {pkg}')

def kill_roblox(cfg=None):
    pkg = get_package(cfg) if cfg else "com.roblox.client"
    log_file(f"[>] Killing {pkg}")
    adb(f"am force-stop {pkg}")

def is_roblox_running(cfg):
    pkg = get_package(cfg)
    return bool(adb(f"pidof {pkg}").strip())

def is_in_private_server(cfg):
    out = adb("dumpsys window | grep mCurrentFocus")
    pkg = get_package(cfg)
    return "ActivityNativeMain" in out and pkg in out

# ── WEBHOOK ───────────────────────────────────────
COLOR_MAP = {
    "green":  3720406,  "red":    14689397,
    "yellow": 15736014, "cyan":   5685178,
    "purple": 13006557, "gray":   5131855,
}

def send_webhook(cfg, title, description, color, fields=None):
    url = cfg.get("webhook_url", "").strip()
    if not url:
        return
    embed = {
        "title": title,
        "description": description,
        "color": COLOR_MAP.get(color, 5131855),
        "footer": {"text": f"Saturnity Hopper v{VERSION} • {datetime.now().strftime('%H:%M:%S')}"},
    }
    if fields:
        embed["fields"] = [
            {"name": f["name"], "value": str(f["value"]), "inline": f.get("inline", True)}
            for f in fields
        ]
    def _send():
        try:
            payload = {"embeds": [embed]}
            data = json.dumps(payload).encode("utf-8")
            req  = urllib.request.Request(url, data=data,
                       headers={"Content-Type": "application/json",
                                "User-Agent": "SaturnityHopper/1.0"},
                       method="POST")
            resp = urllib.request.urlopen(req, timeout=8)
            log_file(f"[+] Webhook sent: {title} (status {resp.status})")
        except urllib.error.HTTPError as e:
            body = ""
            try: body = e.read().decode()
            except: pass
            log_file(f"[!] Webhook HTTP {e.code}: {e.reason} | {body[:100]}")
        except Exception as e:
            log_file(f"[!] Webhook failed: {e}")
    threading.Thread(target=_send, daemon=True).start()

# ── HELPERS ───────────────────────────────────────
def fmt_time(seconds):
    if seconds is None or seconds < 0:
        return "--:--"
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"

def get_term_width(cfg=None):
    """Bug 8 fix — respect saved term_width from config."""
    if cfg and cfg.get("term_width", 0) > 0:
        return cfg["term_width"]
    try:
        return os.get_terminal_size().columns
    except:
        return 60

def divider(cfg=None):
    print(f"{DIM}" + "-" * get_term_width(cfg) + f"{R}")

def banner(cfg=None):
    w    = get_term_width(cfg)
    line = "+" + "-" * (w - 2) + "+"
    print(f"{DIM}{line}{R}")
    # Bug 14 fix — use VERSION constant
    print(f"{GR}  SATURNITY HOPPER  {C}v{VERSION}{R}  {DIM}@lanavienrose{R}")
    print(f"{DIM}{line}{R}")

def clear_screen():
    os.system("clear")

# ── INPUT THREAD ──────────────────────────────────
input_queue    = queue.Queue()
_input_running = False

def _input_worker():
    """Bug 10 fix — exit cleanly on EOF."""
    while _input_running:
        try:
            line = sys.stdin.readline()
            if line == "":  # EOF
                break
            stripped = line.strip()
            if stripped:   # Bug 12 fix — don't queue empty lines during hop
                input_queue.put(stripped)
        except:
            break

def get_input():
    try:
        return input_queue.get_nowait()
    except queue.Empty:
        return None

def clear_input_queue():
    """Bug 12 fix — drain leftover keypresses before starting new session."""
    while not input_queue.empty():
        try:
            input_queue.get_nowait()
        except queue.Empty:
            break

# ── STATUS ────────────────────────────────────────
def print_status(s_num, total, hop_rem, fails, fail_limit, cycle, cfg=None):
    ts        = datetime.now().strftime("%H:%M:%S")
    hop_str   = fmt_time(hop_rem) if hop_rem is not None else "--:--"
    hop_color = Y if hop_rem and hop_rem < 300 else W
    f_color   = RD if fails > 0 else G
    print(f"\n{DIM}  [refresh {ts}]{R}")
    print(f"{C}[~]{R} S:{W}{s_num}/{total}{R} | HOP:{hop_color}{hop_str}{R} | FAIL:{f_color}{fails}/{fail_limit}{R} | CYC:{W}{cycle}{R}")

def print_commands(refresh_mode):
    if refresh_mode == 3:
        print(f"\n{GR}  1. status   2. skip   3. +10min   4. stop{R}")
    else:
        print(f"\n{GR}  1. skip   2. +10min   3. stop{R}")
    print(f"{C}hopper{GR} > {R}", end="", flush=True)

def print_cooldown_commands(refresh_mode):
    if refresh_mode == 3:
        print(f"\n{GR}  1. status   2. skip cooldown   3. stop{R}")
    else:
        print(f"\n{GR}  1. skip cooldown   2. stop{R}")
    print(f"{C}hopper{GR} > {R}", end="", flush=True)

# ── INPUT HANDLER ─────────────────────────────────
def handle_hop_input(user_in, refresh_mode, hop_end_ref, extra_ref,
                     stop_ref, skip_ref, s_num, total, hop_rem, fails, fail_limit, cycle):
    try:
        if refresh_mode == 3:
            if user_in == "1":
                print_status(s_num, total, hop_rem, fails, fail_limit, cycle)
                print_commands(refresh_mode)
            elif user_in == "2":
                hop_log(f"Skip triggered — Server {s_num}")
                skip_ref[0] = True
            elif user_in == "3":
                extra_ref[0] += 600
                t = datetime.fromtimestamp(hop_end_ref[0] + extra_ref[0]).strftime("%H:%M:%S")
                inf(f"+10min added | hop at {Y}{t}{R}")
                print_commands(refresh_mode)
            elif user_in == "4":
                stop_ref[0] = True
        else:
            if user_in == "1":
                hop_log(f"Skip triggered — Server {s_num}")
                skip_ref[0] = True
            elif user_in == "2":
                extra_ref[0] += 600
                t = datetime.fromtimestamp(hop_end_ref[0] + extra_ref[0]).strftime("%H:%M:%S")
                inf(f"+10min added | hop at {Y}{t}{R}")
            elif user_in == "3":
                stop_ref[0] = True
    except Exception as e:
        log_error("handle_hop_input", e)

# ── VIEW LOG ──────────────────────────────────────
def view_log():
    clear_screen()
    if not os.path.exists(LOG_FILE):
        inf("No log file yet.")
        pause()
        return
    try:
        with open(LOG_FILE, "r") as f:
            lines = f.readlines()
        last = lines[-40:] if len(lines) > 40 else lines
        divider()
        print(f"{GR}  LOG — last {len(last)} lines  ({LOG_FILE}){R}")
        divider()
        for line in last:
            txt = line.rstrip()
            if "[ERROR]" in txt or "TRACEBACK" in txt:
                print(f"{RD}{txt}{R}")
            elif "[-]" in txt:
                print(f"{RD}{txt}{R}")
            elif "[!]" in txt:
                print(f"{Y}{txt}{R}")
            elif "[+]" in txt:
                print(f"{G}{txt}{R}")
            else:
                print(f"{DIM}{txt}{R}")
        divider()
        pause()  # Bug 15 fix — wait before redraw
    except Exception as e:
        log_error("view_log", e)
        pause()

# ── MENUS ─────────────────────────────────────────
def settings_menu(cfg):
    while True:
        try:
            clear_screen()
            banner(cfg)
            print()
            divider(cfg)
            print(f"{GR}  SETTINGS{R}")
            divider(cfg)
            print(f"{GR}  1. Set launch delay       {DIM}current: {cfg['launch_delay']}s{R}")
            print(f"{GR}  2. Set hop delay           {DIM}current: {fmt_time(cfg['hop_delay'])}{R}")
            print(f"{GR}  3. Set heartbeat delay     {DIM}current: {cfg['heartbeat_delay']}s  max: 3600{R}")
            print(f"{GR}  4. Set launch detector     {DIM}current: {cfg['launch_detector']}s  max: 300{R}")
            print(f"{GR}  5. Set cooldown hop        {DIM}current: {fmt_time(cfg['cooldown_hop'])}{R}")
            print(f"{GR}  6. Set fail limit          {DIM}current: {cfg['fail_limit']}  max: 50{R}")
            print(f"{GR}  7. Set webhook >{R}")
            print(f"{GR}  8. Manage servers >{R}")
            print(f"{GR}  9. Adjust layout >{R}")
            print(f"{GR}  p. Set Roblox package   {DIM}current: {get_package(cfg)}{R}")
            print(f"{GR}  q. Test start{R}")
            print(f"{GR}  t. Test webhook{R}")
            print(f"{GR}  l. View log{R}")
            print(f"{GR}  0. Back{R}")
            print()
            try:
                c = input(f"{C}settings{GR} > {R}").strip().lower()
            except (EOFError, OSError):
                break

            # Bug 3 fix — skip empty input
            if not c:
                continue

            if c == "1":
                v = input("  Launch delay (seconds): ").strip()
                if v.isdigit():
                    cfg["launch_delay"] = int(v); save_config(cfg); ok(f"Launch delay: {v}s")
                    pause()
            elif c == "2":
                v = input("  Hop delay (minutes): ").strip()
                if v.isdigit():
                    cfg["hop_delay"] = int(v) * 60; save_config(cfg); ok(f"Hop delay: {v}min")
                    pause()
            elif c == "3":
                v = input("  Heartbeat (seconds, max 3600): ").strip()
                if v.isdigit():
                    cfg["heartbeat_delay"] = min(int(v), 3600); save_config(cfg)
                    ok(f"Heartbeat: {cfg['heartbeat_delay']}s"); pause()
            elif c == "4":
                v = input("  Launch detector (seconds, max 300): ").strip()
                if v.isdigit():
                    cfg["launch_detector"] = min(int(v), 300); save_config(cfg)
                    ok(f"Launch detector: {cfg['launch_detector']}s"); pause()
            elif c == "5":
                v = input("  Cooldown (minutes): ").strip()
                if v.isdigit():
                    cfg["cooldown_hop"] = int(v) * 60; save_config(cfg); ok(f"Cooldown: {v}min")
                    pause()
            elif c == "6":
                v = input("  Fail limit (max 50): ").strip()
                if v.isdigit():
                    cfg["fail_limit"] = min(int(v), 50); save_config(cfg)
                    ok(f"Fail limit: {cfg['fail_limit']}"); pause()
            elif c == "7":
                webhook_menu(cfg)
            elif c == "8":
                server_manager_menu(cfg)
            elif c == "9":
                layout_menu(cfg)
            elif c == "p":
                package_menu(cfg)
            elif c == "q":
                inf("Test start — opening Roblox for 5s")
                pkg = get_package(cfg); adb(f"am start -n {pkg}/{pkg}.ActivitySplash")
                time.sleep(5); kill_roblox(cfg); ok("Test done — Roblox closed")
                pause()  # Bug 15 fix
            elif c == "t":
                inf("Sending test webhook...")
                send_webhook(cfg, "Test Webhook", f"Saturnity Hopper v{VERSION} webhook working.", "cyan", [
                    {"name": "Status", "value": "OK"},
                    {"name": "Time",   "value": datetime.now().strftime("%H:%M:%S")},
                ])
                time.sleep(1); ok("Test webhook sent")
                pause()  # Bug 15 fix
            elif c == "l":
                view_log()
            elif c == "0":
                break
        except Exception as e:
            log_error("settings_menu", e)

def webhook_menu(cfg):
    while True:
        clear_screen()
        banner(cfg)
        print()
        divider(cfg)
        print(f"{GR}  WEBHOOK{R}")
        divider(cfg)
        url_display = cfg['webhook_url'][:40] + "..." if len(cfg['webhook_url']) > 40 else cfg['webhook_url'] or "not set"
        print(f"{GR}  1. Set webhook URL    {DIM}{url_display}{R}")
        print(f"{GR}  2. Set webhook name   {DIM}{cfg['webhook_message']}{R}")
        print(f"{GR}  0. Back{R}")
        print()
        try:
            c = input(f"{C}webhook{GR} > {R}").strip()
        except (EOFError, OSError):
            break
        if not c:  # Bug 4 fix
            continue
        if c == "1":
            url = input("  Webhook URL: ").strip()
            if url:
                cfg["webhook_url"] = url; save_config(cfg); ok("Webhook URL saved")
                pause()
        elif c == "2":
            msg = input("  Webhook name: ").strip()
            if msg:
                cfg["webhook_message"] = msg; save_config(cfg); ok("Webhook name saved")
                pause()
        elif c == "0":
            break

def server_manager_menu(cfg):
    while True:
        clear_screen()
        banner(cfg)
        print()
        divider(cfg)
        ps     = load_ps_file()
        ps_str = f" {DIM}(private_servers.txt: {len(ps)} — takes priority){R}" if ps else ""
        print(f"{GR}  SERVERS ({len(cfg['servers'])} in config){ps_str}{R}")
        divider(cfg)
        for i, s in enumerate(cfg["servers"], 1):
            short = s[:55] + "..." if len(s) > 55 else s
            print(f"{GR}  {i}. {DIM}{short}{R}")
        print(f"{GR}  a. Add server{R}")
        print(f"{GR}  d. Delete server{R}")
        print(f"{GR}  p. Show private_servers.txt path{R}")
        print(f"{GR}  0. Back{R}")
        print()
        try:
            c = input(f"{C}servers{GR} > {R}").strip().lower()
        except (EOFError, OSError):
            break
        if not c:  # Bug 5 fix
            continue
        if c == "a":
            link = input("  Server link: ").strip()
            if link.startswith("http"):
                cfg["servers"].append(link); save_config(cfg)
                ok(f"Added server {len(cfg['servers'])}"); pause()
            elif link:
                wrn("Invalid link — must start with http"); pause()
        elif c == "d":
            v = input("  Delete server number: ").strip()
            if v.isdigit():
                idx = int(v) - 1
                if 0 <= idx < len(cfg["servers"]):
                    cfg["servers"].pop(idx); save_config(cfg)
                    ok("Server removed"); pause()
                else:
                    wrn("Invalid number"); pause()
        elif c == "p":
            print()
            inf(f"Create/edit: {PS_FILE}")
            inf("One link per line. Lines starting with # are ignored.")
            pause()  # Bug 17 fix
        elif c == "0":
            break

def package_menu(cfg):
    while True:
        clear_screen()
        banner(cfg)
        print()
        divider(cfg)
        print(f"{GR}  ROBLOX PACKAGE{R}")
        divider(cfg)
        print(f"{GR}  current: {C}{get_package(cfg)}{R}")
        print()
        print(f"{GR}  1. Search by prefix{R}")
        print(f"{GR}  2. Enter manually{R}")
        print(f"{GR}  0. Back{R}")
        print()
        try:
            c = input(f"{C}package{GR} > {R}").strip()
        except (EOFError, OSError):
            break
        if not c:
            continue
        if c == "1":
            try:
                prefix = input("  Type prefix (e.g. com.roblox.): ").strip()
            except (EOFError, OSError):
                continue
            if not prefix:
                continue
            inf(f"Searching for '{prefix}'...")
            pkgs = search_packages(prefix)
            if not pkgs:
                wrn(f"No packages found matching '{prefix}'")
                pause()
                continue
            print()
            for i, p in enumerate(pkgs, 1):
                print(f"{GR}  {i}. {C}{p}{R}")
            print()
            try:
                sel = input("  Select number (or enter to cancel): ").strip()
            except (EOFError, OSError):
                continue
            if sel.isdigit():
                idx = int(sel) - 1
                if 0 <= idx < len(pkgs):
                    cfg["roblox_package"] = pkgs[idx]
                    save_config(cfg)
                    ok(f"Package set: {pkgs[idx]}")
                    pause()
        elif c == "2":
            try:
                pkg = input("  Package name: ").strip()
            except (EOFError, OSError):
                continue
            if pkg:
                cfg["roblox_package"] = pkg
                save_config(cfg)
                ok(f"Package set: {pkg}")
                pause()
        elif c == "0":
            break

def layout_menu(cfg):
    while True:
        clear_screen()
        banner(cfg)
        print()
        divider(cfg)
        print(f"{GR}  LAYOUT{R}")
        divider(cfg)
        cur = cfg.get("term_width", 0)
        print(f"{GR}  1. Set by px            {DIM}e.g. 1080px → ~108 chars{R}")
        print(f"{GR}  2. Set by characters    {DIM}current: {'auto' if cur == 0 else cur}{R}")
        print(f"{GR}  3. Reset to auto{R}")
        print(f"{GR}  0. Back{R}")
        print()
        try:
            c = input(f"{C}layout{GR} > {R}").strip()
        except (EOFError, OSError):
            break
        if not c:  # Bug 6 fix
            continue
        if c == "1":
            v = input("  Width in px (e.g. 1080): ").strip()
            if v.isdigit():
                # Bug 8 fix — save and actually use term_width
                cfg["term_width"] = int(int(v) / 10)
                save_config(cfg); ok(f"Layout: ~{cfg['term_width']} chars"); pause()
        elif c == "2":
            v = input("  Characters per line (e.g. 60): ").strip()
            if v.isdigit():
                cfg["term_width"] = int(v)
                save_config(cfg); ok(f"Layout: {v} chars"); pause()
        elif c == "3":
            cfg["term_width"] = 0
            save_config(cfg); ok("Layout reset to auto"); pause()
        elif c == "0":
            break

# ── HOP LOOP ──────────────────────────────────────
def hop_loop(cfg, refresh_mode):
    global _input_running

    try:
        servers = resolve_servers(cfg)
    except Exception as e:
        log_error("resolve_servers", e)
        return

    if not servers:
        err("No servers — aborting")
        return

    total         = len(servers)
    cycle         = 1
    session_hops  = 0
    session_fails = 0
    session_idle  = 0
    session_start = time.time()
    stop_ref      = [False]
    ref_int       = 30 if refresh_mode == 1 else 60

    log_file(f"[~] Hop loop | servers: {total} | hop_delay: {cfg['hop_delay']}s | refresh: {ref_int}s")

    # Bug 12 fix — clear stale input before starting
    clear_input_queue()

    _input_running = True
    threading.Thread(target=_input_worker, daemon=True).start()

    try:
        while not stop_ref[0]:
            for idx, link in enumerate(servers):
                if stop_ref[0]:
                    break

                s_num = idx + 1
                fails = 0

                while fails < cfg["fail_limit"] and not stop_ref[0]:
                    try:
                        print()
                        divider(cfg)
                        hop_log(f"Server {s_num}/{total} — launching Roblox")

                        kill_roblox(cfg)
                        time.sleep(cfg["launch_delay"])
                        launch_roblox(link, cfg)

                        # launch detector
                        inf(f"Launch detector | timeout: {cfg['launch_detector']}s")
                        launched = False
                        for _ in range(cfg["launch_detector"]):
                            time.sleep(1)
                            if is_roblox_running(cfg):
                                ok("Roblox detected")
                                launched = True
                                break

                        if not launched:
                            fails += 1; session_fails += 1
                            err(f"Roblox did not launch | fail: {fails}/{cfg['fail_limit']}")
                            wrn("Fail limit hit — skipping server" if fails >= cfg["fail_limit"] else "Retrying...")
                            continue

                        # heartbeat
                        inf(f"Heartbeat armed | timeout: {cfg['heartbeat_delay']}s")
                        joined = False
                        for _ in range(cfg["heartbeat_delay"]):
                            time.sleep(1)
                            if is_in_private_server(cfg):
                                ok(f"Joined private server — Server {s_num}/{total}")
                                joined = True
                                send_webhook(cfg, "Joined Private Server",
                                    f"Joined server {s_num}/{total}.", "green", [
                                        {"name": "Server", "value": f"{s_num} / {total}"},
                                        {"name": "Cycle",  "value": str(cycle)},
                                        {"name": "Hop In", "value": fmt_time(cfg["hop_delay"])},
                                    ])
                                break

                        if not joined:
                            fails += 1; session_fails += 1
                            err(f"Heartbeat timeout | fail: {fails}/{cfg['fail_limit']}")
                            send_webhook(cfg, "Heartbeat Timeout", f"Failed to join server {s_num}.", "red", [
                                {"name": "Server", "value": f"{s_num}/{total}"},
                                {"name": "Fail",   "value": f"{fails}/{cfg['fail_limit']}"},
                            ])
                            kill_roblox(cfg)
                            wrn("Fail limit hit — skipping server" if fails >= cfg["fail_limit"] else "Retrying...")
                            continue

                        # hop timer
                        hop_end  = [time.time() + cfg["hop_delay"]]
                        extra    = [0]
                        skip_ref = [False]
                        hop_done = False
                        last_ref = time.time()

                        while not hop_done and not stop_ref[0]:
                            time.sleep(1)
                            now     = time.time()
                            hop_rem = (hop_end[0] + extra[0]) - now

                            # Bug 16 fix — robust hop.flag handling
                            if os.path.exists(HOP_FLAG):
                                reason = "idle_timeout"
                                try:
                                    with open(HOP_FLAG, "r") as hf:
                                        reason = hf.read().strip() or "idle_timeout"
                                except:
                                    pass
                                try:
                                    os.remove(HOP_FLAG)
                                except:
                                    # rename to prevent re-trigger if remove fails
                                    try:
                                        os.rename(HOP_FLAG, HOP_FLAG + ".done")
                                    except:
                                        pass
                                wrn(f"hop.flag | reason: {reason}")
                                session_idle += 1
                                send_webhook(cfg, "Idle Detected — Hopping",
                                    f"No gift on server {s_num}.", "yellow", [
                                        {"name": "Server", "value": f"{s_num}/{total}"},
                                        {"name": "Reason", "value": reason},
                                        {"name": "Cycle",  "value": str(cycle)},
                                    ])
                                err("Killing Roblox...")
                                kill_roblox(cfg)
                                ok("Roblox killed | hop.flag cleared")
                                hop_done = True; session_hops += 1
                                break

                            if skip_ref[0]:
                                err("Killing Roblox...")
                                kill_roblox(cfg)
                                ok("Roblox killed")
                                hop_done = True; session_hops += 1
                                break

                            if hop_rem <= 0:
                                wrn("Hop timer reached")
                                send_webhook(cfg, "Hopping to Next Server",
                                    f"Timer on server {s_num}.", "purple", [
                                        {"name": "From",   "value": f"Server {s_num}"},
                                        {"name": "To",     "value": f"Server {(idx+1)%total+1}"},
                                        {"name": "Reason", "value": "Timer"},
                                    ])
                                err("Killing Roblox...")
                                kill_roblox(cfg)
                                ok("Roblox killed")
                                hop_done = True; session_hops += 1
                                break

                            if refresh_mode in (1, 2) and now - last_ref >= ref_int:
                                last_ref = now
                                print_status(s_num, total, hop_rem, fails, cfg["fail_limit"], cycle, cfg)
                                print_commands(refresh_mode)

                            ui = get_input()
                            if ui:
                                handle_hop_input(ui, refresh_mode, hop_end, extra, stop_ref,
                                                 skip_ref, s_num, total, hop_rem, fails, cfg["fail_limit"], cycle)
                                if stop_ref[0]:
                                    err("Stop triggered — killing Roblox")
                                    kill_roblox(cfg); ok("Roblox killed")
                                    hop_done = True

                    except Exception as e:
                        log_error(f"server {s_num} cycle {cycle}", e)
                        fails += 1; session_fails += 1
                        wrn(f"Unexpected error | fail: {fails}/{cfg['fail_limit']}")
                        try:
                            kill_roblox(cfg)
                        except:
                            pass
                        continue

                    if stop_ref[0]: break
                    break

            if stop_ref[0]: break

            ok(f"All {total}/{total} servers done — cycle {cycle} complete")
            send_webhook(cfg, "All Servers Done", f"Cycle {cycle} complete.", "cyan", [
                {"name": "Servers",  "value": f"{total}/{total}"},
                {"name": "Fails",    "value": str(session_fails)},
                {"name": "Cooldown", "value": fmt_time(cfg["cooldown_hop"])},
                {"name": "Resume",   "value": (datetime.now() + timedelta(seconds=cfg["cooldown_hop"])).strftime("%H:%M")},
            ])

            inf(f"Cooldown {fmt_time(cfg['cooldown_hop'])} | resume at {(datetime.now() + timedelta(seconds=cfg['cooldown_hop'])).strftime('%H:%M:%S')}")
            cd_end   = time.time() + cfg["cooldown_hop"]
            last_ref = time.time()

            while time.time() < cd_end and not stop_ref[0]:
                time.sleep(1)
                now = time.time()
                rem = cd_end - now
                if refresh_mode in (1, 2) and now - last_ref >= ref_int:
                    last_ref = now
                    print(f"\n{DIM}  [refresh {datetime.now().strftime('%H:%M:%S')}]{R}")
                    print(f"{C}[~]{R} COOLDOWN | resume in {Y}{fmt_time(rem)}{R} | cycle: {W}{cycle}{R}")
                    print_cooldown_commands(refresh_mode)
                ui = get_input()
                if ui:
                    if refresh_mode == 3:
                        if ui == "1":
                            print(f"\n{DIM}  [refresh {datetime.now().strftime('%H:%M:%S')}]{R}")
                            print(f"{C}[~]{R} COOLDOWN | resume in {Y}{fmt_time(rem)}{R} | cycle: {W}{cycle}{R}")
                            print_cooldown_commands(refresh_mode)
                        elif ui == "2": inf("Skipping cooldown"); break
                        elif ui == "3": stop_ref[0] = True
                    else:
                        if ui == "1": inf("Skipping cooldown"); break
                        elif ui == "2": stop_ref[0] = True

            if not stop_ref[0]:
                cycle += 1
                inf(f"Cooldown done | cycle {cycle} starting")

    except KeyboardInterrupt:
        wrn("KeyboardInterrupt")
        log_file("[!] KeyboardInterrupt")
    except Exception as e:
        log_error("hop_loop", e)
    finally:
        _input_running = False
        try:
            kill_roblox(cfg)
        except:
            pass

    # session summary
    runtime = int(time.time() - session_start)
    print()
    w    = get_term_width(cfg)
    line = "+" + "-" * (w - 2) + "+"
    print(f"{DIM}{line}{R}")
    print(f"{GR}  servers: {G}{total}{R}  |  hops: {G}{session_hops}{R}  |  fails: {Y}{session_fails}{R}")
    print(f"{GR}  idle triggers: {Y}{session_idle}{R}  |  runtime: {W}{fmt_time(runtime)}{R}")
    print(f"{DIM}{line}{R}")
    print()
    inf("Session complete")
    log_file(f"SESSION END | runtime: {fmt_time(runtime)} | hops: {session_hops} | fails: {session_fails} | idle: {session_idle}")
    log_file("=" * 50)
    send_webhook(cfg, "Hopper Stopped", "Session ended.", "gray", [
        {"name": "Runtime", "value": fmt_time(runtime)},
        {"name": "Hops",    "value": str(session_hops)},
        {"name": "Fails",   "value": str(session_fails)},
    ])

# ── MAIN ──────────────────────────────────────────
def main():
    # Bug 7 fix — loop instead of recurse
    while True:
        try:
            clear_screen()
            cfg = load_config()
            banner(cfg)
            print()
            log_session_start()

            ps = load_ps_file()
            if ps:
                sys_log(f"private_servers.txt detected | {len(ps)} servers")
            elif cfg["servers"]:
                sys_log(f"config servers: {len(cfg['servers'])}")

            print()
            print(f"{GR}  1. Start Hop{R}")
            print(f"{GR}  2. Settings{R}")
            print(f"{GR}  3. Exit{R}")
            print()
            try:
                c = input(f"{C}hopper{GR} > {R}").strip()
            except (EOFError, OSError):
                inf("Exiting")
                sys.exit(0)

            if not c:  # Bug 7 / empty input guard
                continue

            if c == "1":
                print()
                print(f"{GR}  Refresh interval:{R}")
                print(f"{GR}  1. Every 30s{R}")
                print(f"{GR}  2. Every 60s{R}")
                print(f"{GR}  3. Manual{R}")
                print()
                r = input(f"{C}hopper{GR} > {R}").strip()
                refresh_mode = int(r) if r in ("1", "2", "3") else 1
                print()
                sys_log(f"hop: {fmt_time(cfg['hop_delay'])} | heartbeat: {cfg['heartbeat_delay']}s | fail: {cfg['fail_limit']}")
                sys_log(f"launch: {cfg['launch_detector']}s | cooldown: {fmt_time(cfg['cooldown_hop'])} | refresh: {['30s','60s','manual'][refresh_mode-1]}")
                print()
                hop_loop(cfg, refresh_mode)
                # Bug 11 fix — return to menu after hop ends, not exit
                pause("  session ended — press enter to return to menu...")

            elif c == "2":
                settings_menu(cfg)
                # Bug 7 fix — loop back naturally, no recursion

            elif c == "3":
                inf("Exiting")
                sys.exit(0)

        except KeyboardInterrupt:
            print()
            inf("Exiting")
            sys.exit(0)
        except Exception as e:
            log_error("main", e)
            print()
            err(f"Fatal error — check log: {LOG_FILE}")
            pause()

if __name__ == "__main__":
    main()
