#!/usr/bin/env python3
"""
xsync-sqlite — SQLite 同步工具
==============================

基于 Litestream 的 SQLite 数据库同步工具，支持 Cloudflare R2 存储。
提供 push（持续复制到 R2）和 pull（从 R2 恢复）两种模式。

用法示例：
    # 交互式菜单
    python3 xsync-sqlite.py

    # 直接执行安装
    python3 xsync-sqlite.py --install

    # 查看状态
    python3 xsync-sqlite.py --status

    # 手动同步
    python3 xsync-sqlite.py --sync

    # 启动 pull 定时循环（供 systemd 调用）
    python3 xsync-sqlite.py --pull-daemon

    # 重置配置
    python3 xsync-sqlite.py --reset-config
"""

import os
import sys
import json
import time
import shutil
import sqlite3
import platform
import argparse
import textwrap
import subprocess
from getpass import getuser
from pathlib import Path


LITESTREAM_VERSION = "0.3.13"


# ============================================================
# xsync_config — 配置管理（R2 凭证 + 数据库路径 + 模式）
# ============================================================
class xsync_config:
    """
    配置管理类，负责读写 ~/pytools/xsync-sqlite-config.json。

    配置字段：
        r2_endpoint       R2 Endpoint URL
        r2_access_key     Access Key ID
        r2_secret_key     Secret Access Key
        r2_bucket         Bucket 名称
        r2_path_prefix    路径前缀（可选）
        db_path           数据库文件绝对路径
        mode              同步模式（push / pull）
        sync_interval     同步间隔秒数（默认 3600）
    """

    _config_path = Path(__file__).parent / "xsync-sqlite-config.json"

    def load(self):
        """读取配置文件，返回 dict 或 None。"""
        if not self._config_path.exists():
            return None
        try:
            with open(self._config_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            print(f"读取配置文件失败：{e}")
            return None

    def save(self, cfg):
        """将配置写入文件。"""
        self._config_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self._config_path, "w", encoding="utf-8") as f:
            json.dump(cfg, f, ensure_ascii=False, indent=2)


# ============================================================
# xsync_litestream — Litestream 安装 / 配置 / 执行
# ============================================================
class xsync_litestream:
    """
    Litestream 二进制管理和配置生成。

    负责：
        - 检测 / 安装 Litestream
        - 生成 litestream.yml 配置文件
        - 执行 replicate / restore 命令
    """

    yml_path = Path(__file__).parent / "xsync-sqlite-litestream.yml"

    @staticmethod
    def is_installed():
        """检测 litestream 是否已安装。"""
        return shutil.which("litestream") is not None

    @staticmethod
    def get_version():
        """获取已安装的 litestream 版本号。"""
        try:
            result = subprocess.run(
                ["litestream", "version"],
                capture_output=True, text=True, timeout=5,
            )
            return result.stdout.strip() or result.stderr.strip()
        except Exception:
            return "unknown"

    @staticmethod
    def install():
        """
        自动安装 Litestream。
        macOS: brew install
        Linux: 从 GitHub releases 下载 .deb
        """
        system = platform.system()

        if system == "Darwin":
            print("  正在通过 Homebrew 安装 Litestream...")
            if not shutil.which("brew"):
                print("  [错误] 未找到 Homebrew，请先安装 Homebrew。")
                return False
            ret = subprocess.run(
                ["brew", "install", "benbjohnson/litestream/litestream"],
                capture_output=False,
            )
            return ret.returncode == 0

        elif system == "Linux":
            arch = platform.machine()
            if arch == "x86_64":
                deb_arch = "amd64"
            elif arch == "aarch64":
                deb_arch = "arm64"
            else:
                print(f"  [错误] 不支持的架构：{arch}")
                return False

            deb_name = f"litestream-v{LITESTREAM_VERSION}-linux-{deb_arch}.deb"
            url = (
                f"https://github.com/benbjohnson/litestream/releases/download/"
                f"v{LITESTREAM_VERSION}/{deb_name}"
            )
            tmp_path = f"/tmp/{deb_name}"

            print(f"  正在下载 {deb_name}...")
            ret = subprocess.run(
                ["curl", "-fsSL", "-o", tmp_path, url],
                capture_output=False,
            )
            if ret.returncode != 0:
                print("  [错误] 下载失败。")
                return False

            print("  正在安装 .deb 包...")
            sudo = [] if os.geteuid() == 0 else ["sudo"]
            ret = subprocess.run(
                [*sudo, "dpkg", "-i", tmp_path],
                capture_output=False,
            )
            os.remove(tmp_path)
            return ret.returncode == 0

        else:
            print(f"  [错误] 不支持的系统：{system}")
            return False

    def generate_yml(self, cfg):
        """根据配置生成 litestream.yml 文件。"""
        db_path = cfg["db_path"]
        bucket = cfg["r2_bucket"]
        endpoint = cfg["r2_endpoint"]
        access_key = cfg["r2_access_key"]
        secret_key = cfg["r2_secret_key"]
        prefix = cfg.get("r2_path_prefix", "")
        interval = cfg.get("sync_interval", 3600)

        # 构建 replica path
        db_filename = Path(db_path).name
        replica_path = f"{prefix}/{db_filename}" if prefix else db_filename

        yml_content = textwrap.dedent(f"""\
            dbs:
              - path: "{db_path}"
                replicas:
                  - type: s3
                    bucket: "{bucket}"
                    path: "{replica_path}"
                    endpoint: "{endpoint}"
                    region: auto
                    access-key-id: "{access_key}"
                    secret-access-key: "{secret_key}"
                    force-path-style: true
                    sync-interval: {interval}s
        """)

        self.yml_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.yml_path, "w", encoding="utf-8") as f:
            f.write(yml_content)
        return str(self.yml_path)

    def replicate_once(self):
        """执行一次性 push 同步（初始快照完成后退出）。"""
        print("  正在执行 push 同步...")
        ret = subprocess.run(
            ["litestream", "replicate", "-config", str(self.yml_path),
             "-exec", "sleep 10"],
            capture_output=False,
        )
        return ret.returncode == 0

    def restore(self, db_path):
        """从 R2 恢复数据库。若目标文件已存在则先备份。"""
        target = Path(db_path)
        if target.exists():
            bak = target.with_suffix(target.suffix + ".bak")
            print(f"  数据库已存在，备份为 {bak.name}...")
            shutil.copy2(str(target), str(bak))
            target.unlink()

        print("  正在从 R2 恢复数据库...")
        ret = subprocess.run(
            ["litestream", "restore", "-config", str(self.yml_path),
             "-o", db_path, db_path],
            capture_output=False,
        )
        return ret.returncode == 0

    def restore_loop(self, db_path, interval=3600):
        """定时循环从 R2 恢复数据库。"""
        print(f"  启动定时 pull（间隔 {interval} 秒）...")
        try:
            while True:
                timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
                print(f"  [{timestamp}] 正在 pull...")
                self.restore(db_path)
                time.sleep(interval)
        except KeyboardInterrupt:
            print("\n  定时 pull 已停止。")


# ============================================================
# xsync_service — systemd 服务管理（仅 Linux）
# ============================================================
class xsync_service:
    """
    systemd 服务管理（仅 Linux）。

    服务名：xsync-sqlite
    路径：/etc/systemd/system/xsync-sqlite.service
    """

    _service_name = "xsync-sqlite"
    _service_path = Path("/etc/systemd/system/xsync-sqlite.service")

    def create(self, yml_path, mode="push", script_path=None):
        """创建 systemd 服务文件并启动。"""
        if mode == "push":
            litestream_path = shutil.which("litestream")
            if not litestream_path:
                print("  [错误] 未找到 litestream 可执行文件。")
                return False
            exec_start = f"{litestream_path} replicate -config {yml_path}"
            description = "xsync-sqlite Litestream Replication"
        else:  # pull
            exec_start = f"python3 {script_path} --pull-daemon"
            description = "xsync-sqlite Pull Daemon"

        unit_content = textwrap.dedent(f"""\
            [Unit]
            Description={description}
            After=network.target

            [Service]
            Type=simple
            User={getuser()}
            ExecStart={exec_start}
            Restart=on-failure
            RestartSec=5s

            [Install]
            WantedBy=multi-user.target
        """)

        sudo = [] if os.geteuid() == 0 else ["sudo"]

        # 写入 service 文件
        tmp_path = "/tmp/xsync-sqlite.service"
        with open(tmp_path, "w", encoding="utf-8") as f:
            f.write(unit_content)

        ret = subprocess.run(
            [*sudo, "cp", tmp_path, str(self._service_path)],
            capture_output=False,
        )
        os.remove(tmp_path)
        if ret.returncode != 0:
            print("  [错误] 写入 service 文件失败。")
            return False

        # daemon-reload + enable + start
        for cmd_desc, cmd_args in [
            ("daemon-reload", [*sudo, "systemctl", "daemon-reload"]),
            ("enable",        [*sudo, "systemctl", "enable", self._service_name]),
            ("start",         [*sudo, "systemctl", "start", self._service_name]),
        ]:
            ret = subprocess.run(cmd_args, capture_output=False)
            if ret.returncode != 0:
                print(f"  [错误] systemctl {cmd_desc} 失败。")
                return False

        return True

    def status(self):
        """打印 systemd 服务状态。"""
        subprocess.run(
            ["systemctl", "status", self._service_name, "--no-pager"],
            capture_output=False,
        )


# ============================================================
# xsync_tool — 主编排（菜单 + 安装流水线）
# ============================================================
class xsync_tool:
    """
    xsync-sqlite 主工具类，负责菜单交互和安装流水线。
    """

    def __init__(self):
        parser = argparse.ArgumentParser(
            description="xsync-sqlite — SQLite 同步工具（基于 Litestream + Cloudflare R2）",
            add_help=True,
        )
        parser.add_argument(
            "--reset-config", action="store_true",
            help="重新输入配置",
        )
        parser.add_argument(
            "--install", action="store_true",
            help="直接执行安装（跳过菜单）",
        )
        parser.add_argument(
            "--status", action="store_true",
            help="直接查看状态",
        )
        parser.add_argument(
            "--sync", action="store_true",
            help="直接执行手动同步",
        )
        parser.add_argument(
            "--pull-daemon", action="store_true",
            help="启动 pull 定时循环（内部用，供 systemd 调用）",
        )
        self._args = parser.parse_args()
        self._cfg_mgr = xsync_config()
        self._ls = xsync_litestream()
        self._svc = xsync_service()

    def run(self):
        """主入口：根据 CLI 参数决定执行路径，或显示交互式菜单。"""
        if self._args.reset_config:
            self._do_install(reset=True)
            return
        if self._args.install:
            self._do_install()
            return
        if self._args.status:
            self._do_status()
            return
        if self._args.sync:
            self._do_sync()
            return
        if self._args.pull_daemon:
            self._do_pull_daemon()
            return

        self._menu()

    def _menu(self):
        """交互式菜单。"""
        print("=== xsync-sqlite — SQLite 同步工具 ===\n")
        print("请选择操作：")
        print("  1) 安装配置")
        print("  2) 查看服务状态")
        print("  3) 手动同步")
        print("  0) 退出")
        print()

        choice = input("请输入选项 (0/1/2/3): ").strip()
        if choice == "1":
            self._do_install()
        elif choice == "2":
            self._do_status()
        elif choice == "3":
            self._do_sync()
        elif choice in ("0", ""):
            print("已退出。")
        else:
            print(f"[错误] 无效选项：{choice}")
            sys.exit(1)

    # ---- 安装流水线 ----

    def _do_install(self, reset=False):
        """7 步安装流水线。"""
        print("\n=== 安装配置 ===\n")

        # Step 1/7: 检查 Litestream
        print("[Step 1/7] 检查 Litestream...")
        if xsync_litestream.is_installed():
            version = xsync_litestream.get_version()
            print(f"  ✓ Litestream 已安装（{version}）")
        else:
            print("  未检测到 Litestream，正在安装...")
            if not xsync_litestream.install():
                print("[错误] Litestream 安装失败。")
                sys.exit(1)
            print("  ✓ Litestream 安装成功")

        # Step 2/7: 配置 Cloudflare R2
        print("\n[Step 2/7] 配置 Cloudflare R2...")
        existing = None if reset else self._cfg_mgr.load()
        if existing:
            print(f"  已有配置（Bucket: {existing.get('r2_bucket', 'N/A')}）")
            reuse = input("  使用现有配置？(Y/n): ").strip().lower()
            if reuse not in ("n", "no"):
                r2_cfg = {
                    "r2_endpoint": existing["r2_endpoint"],
                    "r2_access_key": existing["r2_access_key"],
                    "r2_secret_key": existing["r2_secret_key"],
                    "r2_bucket": existing["r2_bucket"],
                    "r2_path_prefix": existing.get("r2_path_prefix", ""),
                }
            else:
                r2_cfg = self._prompt_r2()
        else:
            r2_cfg = self._prompt_r2()

        # Step 3/7: 指定数据库文件路径
        print("\n[Step 3/7] 指定数据库文件路径...")
        db_path = self._prompt_db_path()

        # Step 4/7: 选择同步模式（先选模式，再检查 WAL）
        print("\n[Step 4/7] 选择同步模式...")
        mode = self._prompt_mode()

        # Step 5/7: 设置同步间隔
        print("\n[Step 5/7] 设置同步间隔...")
        sync_interval = self._prompt_sync_interval()

        # Step 6/7: 检查 WAL 模式
        print("\n[Step 6/7] 检查 WAL 模式...")
        self._check_wal(db_path, mode)

        # Step 7/7: 生成配置 & 启动服务
        print("\n[Step 7/7] 生成配置 & 启动服务...")
        cfg = {
            **r2_cfg,
            "db_path": db_path,
            "mode": mode,
            "sync_interval": sync_interval,
        }

        # 生成 litestream.yml
        yml_path = self._ls.generate_yml(cfg)
        print(f"  ✓ 配置文件：{yml_path}")

        # 保存 JSON 配置
        self._cfg_mgr.save(cfg)
        print("  ✓ 配置已保存")

        # 根据模式和平台执行
        system = platform.system()
        script_path = str(Path(__file__).resolve())

        if mode == "push":
            if system == "Linux":
                print("  正在创建 systemd 服务...")
                if self._svc.create(yml_path, mode="push"):
                    print("  ✓ systemd 服务已创建并启动（xsync-sqlite）")
                else:
                    print("  [错误] 服务创建失败，可手动执行：")
                    print(f"    litestream replicate -config {yml_path}")
            else:
                print("  macOS 不支持 systemd，执行一次性同步...")
                if self._ls.replicate_once():
                    print("  ✓ 一次性 push 同步完成")
                else:
                    print("  [错误] 同步失败。")
        else:  # pull
            if self._ls.restore(db_path):
                print(f"  ✓ 数据库已恢复到 {db_path}")
            else:
                print("  [错误] 恢复失败。")
            if system == "Linux":
                print("  正在创建 systemd 定时 pull 服务...")
                if self._svc.create(yml_path, mode="pull", script_path=script_path):
                    print("  ✓ systemd 服务已创建并启动（xsync-sqlite）")
                else:
                    print("  [错误] 服务创建失败，可手动执行：")
                    print(f"    python3 {script_path} --pull-daemon")

        print("\n[完成] 安装配置结束。")

    def _prompt_r2(self):
        """交互式输入 R2 配置。"""
        print("  格式提示：Endpoint 为 https://<account-id>.r2.cloudflarestorage.com")

        def _input(prompt, required=True):
            while True:
                value = input(f"  {prompt}: ").strip()
                if value or not required:
                    return value
                print("  此项不能为空，请重新输入。")

        endpoint = _input("R2 Endpoint URL")
        access_key = _input("Access Key ID")
        secret_key = _input("Secret Access Key")
        bucket = _input("Bucket 名称")
        prefix = _input("路径前缀（可选，回车跳过）", required=False)

        return {
            "r2_endpoint": endpoint.rstrip("/"),
            "r2_access_key": access_key,
            "r2_secret_key": secret_key,
            "r2_bucket": bucket,
            "r2_path_prefix": prefix,
        }

    def _prompt_db_path(self):
        """交互式输入数据库文件路径。"""
        while True:
            raw = input("  数据库文件绝对路径: ").strip()
            if not raw:
                print("  路径不能为空，请重新输入。")
                continue
            path = os.path.expanduser(raw)
            path = os.path.abspath(path)
            # 接受存在或不存在的路径（pull 模式可能还未恢复）
            return path

    def _prompt_mode(self):
        """交互式选择同步模式。"""
        print("  push — 本地 → R2（持续复制）")
        print("  pull — R2 → 本地（恢复数据库）")
        while True:
            mode = input("  请选择模式 (push/pull): ").strip().lower()
            if mode in ("push", "pull"):
                return mode
            print("  请输入 push 或 pull。")

    def _prompt_sync_interval(self):
        """交互式输入同步间隔秒数。"""
        raw = input("  同步间隔（秒，默认 3600）: ").strip()
        if not raw:
            print("  使用默认值 3600 秒")
            return 3600
        try:
            val = int(raw)
            if val <= 0:
                print("  [警告] 间隔必须大于 0，使用默认值 3600 秒")
                return 3600
            return val
        except ValueError:
            print("  [警告] 输入无效，使用默认值 3600 秒")
            return 3600

    def _check_wal(self, db_path, mode):
        """检查并可选切换 WAL 模式。"""
        if mode == "pull" or not os.path.exists(db_path):
            print("  [跳过] pull 模式或数据库文件不存在，无需检查。")
            return

        conn = None
        try:
            conn = sqlite3.connect(db_path)
            journal = conn.execute("PRAGMA journal_mode;").fetchone()[0]
            if journal.lower() == "wal":
                print("  ✓ 当前已是 WAL 模式")
            else:
                print(f"  当前 journal_mode = {journal}")
                switch = input("  是否切换到 WAL 模式？(Y/n): ").strip().lower()
                if switch not in ("n", "no"):
                    conn.execute("PRAGMA journal_mode=WAL;")
                    print("  ✓ 已切换到 WAL 模式")
                else:
                    print("  [跳过] 保持当前模式（Litestream 建议使用 WAL）")
        except Exception as e:
            print(f"  [警告] 无法检查 WAL 模式：{e}")
        finally:
            if conn:
                conn.close()

    # ---- 查看状态 ----

    def _do_status(self):
        """查看服务状态。"""
        print("\n=== 服务状态 ===\n")

        cfg = self._cfg_mgr.load()
        if not cfg:
            print("未找到配置，请先执行安装配置。")
            return

        # 配置摘要
        print(f"  数据库路径：{cfg.get('db_path', 'N/A')}")
        print(f"  同步模式：  {cfg.get('mode', 'N/A')}")
        print(f"  同步间隔：  {cfg.get('sync_interval', 3600)} 秒")
        print(f"  R2 Bucket： {cfg.get('r2_bucket', 'N/A')}")
        prefix = cfg.get("r2_path_prefix", "")
        if prefix:
            print(f"  路径前缀：  {prefix}")
        print()

        # Litestream 版本
        if xsync_litestream.is_installed():
            print(f"  Litestream：{xsync_litestream.get_version()}")
        else:
            print("  Litestream：未安装")
        print()

        # 服务状态
        system = platform.system()
        if system == "Linux":
            self._svc.status()
        else:
            print("  macOS 不支持 systemd 服务，请使用手动同步。")

    # ---- 手动同步 ----

    def _do_sync(self):
        """手动执行同步。"""
        print("\n=== 手动同步 ===\n")

        cfg = self._cfg_mgr.load()
        if not cfg:
            print("未找到配置，请先执行安装配置。")
            return

        yml_path = self._ls.yml_path
        if not yml_path.exists():
            print("未找到 litestream.yml，请先执行安装配置。")
            return

        mode = cfg.get("mode", "push")
        db_path = cfg.get("db_path", "")

        print(f"  模式：{mode}")
        print(f"  数据库：{db_path}")
        print()

        if mode == "push":
            if self._ls.replicate_once():
                print("\n  ✓ push 同步完成")
            else:
                print("\n  [错误] push 同步失败。")
        else:
            if self._ls.restore(db_path):
                print(f"\n  ✓ 数据库已恢复到 {db_path}")
                if platform.system() == "Linux":
                    script_path = str(Path(__file__).resolve())
                    print("  提示：可通过 systemd 服务实现定时拉取：")
                    print(f"    python3 {script_path} --install")
            else:
                print("\n  [错误] 恢复失败。")

    # ---- pull 守护模式 ----

    def _do_pull_daemon(self):
        """pull 定时循环，供 systemd 服务调用。"""
        cfg = self._cfg_mgr.load()
        if not cfg:
            print("未找到配置，请先执行安装配置。")
            sys.exit(1)

        if not self._ls.yml_path.exists():
            print("未找到 litestream.yml，请先执行安装配置。")
            sys.exit(1)

        db_path = cfg.get("db_path", "")
        interval = cfg.get("sync_interval", 3600)
        self._ls.restore_loop(db_path, interval)


# ============================================================
# 入口
# ============================================================
if __name__ == "__main__":
    tool = xsync_tool()
    tool.run()
