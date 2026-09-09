# -*- coding: utf-8 -*-
"""NetIPv4Doctor の exe 版エントリポイント。

Run-NetIPv4Doctor.bat / Check-NetIPv4.bat と同じことを 1 本の exe で行う。

    NetIPv4Doctor.exe            管理者権限に昇格して Fix-Ipv4Tunnel.ps1 を実行
    NetIPv4Doctor.exe --check    昇格せず Check-Ipv4Health.ps1 だけ実行
    NetIPv4Doctor.exe --silent   無人実行（ブラウザもダイアログも出さない）

PowerShell 本体は同梱しない。exe には .ps1 だけを埋め込み、実行時に取り出して
Windows の powershell.exe へ渡す。

.ps1 は `$here\\logs` にログを書くので、取り出し先はプロセスごとの一時ディレクトリ
ではなく %LOCALAPPDATA% 配下の固定パスにする。exe の隣に .ps1 が揃っている場合
（ソースツリーから起動した場合）は、そちらを優先して従来どおりの場所へ記録する。
"""
from __future__ import annotations

import ctypes
import os
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPTS = ("Ipv4HealthCore.ps1", "Check-Ipv4Health.ps1", "Fix-Ipv4Tunnel.ps1")


def bundle_dir() -> Path:
    """同梱データの置き場。凍結時は PyInstaller の展開先。"""
    base = getattr(sys, "_MEIPASS", None)
    return Path(base) if base else Path(__file__).resolve().parent


def exe_dir() -> Path:
    """exe（または .py）が置かれているディレクトリ。"""
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def script_dir() -> Path:
    """.ps1 を実行するディレクトリを決め、必要なら取り出す。"""
    beside = exe_dir()
    if all((beside / name).is_file() for name in SCRIPTS):
        return beside

    work = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "NetIPv4Doctor" / "scripts"
    work.mkdir(parents=True, exist_ok=True)
    src = bundle_dir()
    for name in SCRIPTS:
        origin = src / name
        if not origin.is_file():
            raise SystemExit(f"同梱スクリプトが見つからない: {name}")
        target = work / name
        # 内容が変わっていなければ触らない（更新時だけ書き戻す）
        if not target.is_file() or target.read_bytes() != origin.read_bytes():
            shutil.copyfile(origin, target)
    return work


def powershell() -> str:
    system32 = Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32"
    candidate = system32 / "WindowsPowerShell" / "v1.0" / "powershell.exe"
    return str(candidate) if candidate.is_file() else "powershell.exe"


def is_admin() -> bool:
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:  # noqa: BLE001
        return False


def run_here(ps1: Path, extra: list[str]) -> int:
    """昇格せず、この場のコンソールでスクリプトを実行する。"""
    cmd = [powershell(), "-NoProfile", "-ExecutionPolicy", "Bypass",
           "-File", str(ps1), *extra]
    return subprocess.call(cmd)


def run_elevated(ps1: Path, extra: list[str], keep_open: bool) -> int:
    """UAC を 1 回出して、別ウィンドウで管理者として実行する。"""
    args = ["-NoProfile", "-ExecutionPolicy", "Bypass"]
    if keep_open:
        args.append("-NoExit")
    args += ["-File", f'"{ps1}"', *extra]

    rc = ctypes.windll.shell32.ShellExecuteW(
        None, "runas", powershell(), " ".join(args), str(ps1.parent), 1
    )
    # ShellExecuteW は成功時に 32 より大きい値を返す
    if rc <= 32:
        if rc == 5:  # SE_ERR_ACCESSDENIED = UAC を拒否された
            print("管理者権限が許可されなかったため中止した。")
        else:
            print(f"PowerShell の起動に失敗した (ShellExecuteW={rc})。")
        return 1
    return 0


def main(argv: list[str]) -> int:
    flags = {a.lower() for a in argv}
    here = script_dir()

    if "--check" in flags or "-check" in flags or "/check" in flags:
        rc = run_here(here / "Check-Ipv4Health.ps1", [])
        input("\n続けるには Enter を押してください . . . ")
        return rc

    extra: list[str] = []
    silent = "--silent" in flags or "-silent" in flags or "/silent" in flags
    if silent:
        extra.append("-Silent")
    if "--no-open-router-page" in flags:
        extra.append("-NoOpenRouterPage")

    fix = here / "Fix-Ipv4Tunnel.ps1"
    if is_admin():
        # 既に管理者。別ウィンドウを開かずそのまま走らせる。
        return run_here(fix, extra)
    return run_elevated(fix, extra, keep_open=not silent)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
