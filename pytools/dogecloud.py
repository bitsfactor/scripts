#!/usr/bin/env python3
"""
多吉云 CDN 上传工具
================

将本地文件或文件夹上传到多吉云 CDN（通过多吉云 API 换取腾讯云 COS 临时凭证，再用 S3 协议上传）。

用法示例：
    # 首次运行（触发配置引导）
    python3 dogecloud.py

    # 重置配置
    python3 dogecloud.py --reset-config

    # 或加可执行权限后直接运行
    chmod +x dogecloud.py
    ./dogecloud.py
"""

import sys

# 检测依赖
missing = []
try:
    import requests
except ImportError:
    missing.append("requests")

try:
    import boto3
except ImportError:
    missing.append("boto3")

if missing:
    print(f"缺少依赖库：{', '.join(missing)}")
    print("请执行以下命令安装：")
    print("  pip install requests boto3")
    sys.exit(1)

import os
import json
import hmac
import hashlib
import mimetypes
import argparse
from pathlib import Path
from botocore.config import Config


# ============================================================
# dogecloud_config — 配置读写，首次运行引导输入
# ============================================================
class dogecloud_config:
    """
    配置管理类，负责读写 ~/pytools/dogecloud-config.json。

    用法示例：
        cfg = dogecloud_config()
        config = cfg.get()           # 返回配置 dict，不存在则触发引导
        config = cfg.get(reset=True) # 强制重新输入配置

    配置字段说明：
        access_key       多吉云 AccessKey
        secret_key       多吉云 SecretKey
        dogecloud_bucket 多吉云桶名（如 api-01）
        cdn_domain       CDN 域名（如 https://image.ic.work）
    """

    # 配置文件存放在工具同目录下
    _config_path = Path(__file__).parent / "dogecloud-config.json"

    def load(self):
        """
        读取配置文件。

        示例：
            cfg = dogecloud_config()
            config = cfg.load()  # 返回 dict 或 None
        """
        if not self._config_path.exists():
            return None
        try:
            with open(self._config_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            print(f"读取配置文件失败：{e}")
            return None

    def save(self, cfg):
        """
        将配置写入文件。

        示例：
            cfg = dogecloud_config()
            cfg.save({"access_key": "xxx", ...})
        """
        self._config_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self._config_path, "w", encoding="utf-8") as f:
            json.dump(cfg, f, ensure_ascii=False, indent=2)

    def prompt_setup(self):
        """
        终端引导用户逐项输入配置，保存后返回配置 dict。

        示例：
            cfg = dogecloud_config()
            config = cfg.prompt_setup()
        """
        print("\n[首次运行] 未检测到配置，请输入以下信息：")

        def _input(prompt, default=None):
            """带默认值的输入辅助函数。"""
            if default:
                value = input(f"  {prompt} [{default}]: ").strip()
                return value if value else default
            else:
                while True:
                    value = input(f"  {prompt}: ").strip()
                    if value:
                        return value
                    print("  此项不能为空，请重新输入。")

        config = {
            "access_key":       _input("多吉云 AccessKey"),
            "secret_key":       _input("多吉云 SecretKey"),
            "dogecloud_bucket": _input("多吉云桶名"),
            "cdn_domain":       _input("CDN 域名", "https://image.ic.work"),
        }

        # 去除 cdn_domain 末尾斜杠
        config["cdn_domain"] = config["cdn_domain"].rstrip("/")

        self.save(config)
        print(f"配置已保存到 {self._config_path}")
        return config

    def get(self, reset=False):
        """
        获取配置，若已有配置则直接返回；否则先调 prompt_setup。
        reset=True 时强制重新引导输入（覆盖旧配置）。

        示例：
            cfg = dogecloud_config()
            config = cfg.get()           # 正常获取
            config = cfg.get(reset=True) # 强制重置
        """
        if not reset:
            config = self.load()
            if config:
                return config
        return self.prompt_setup()


# ============================================================
# dogecloud_auth — 多吉云 API 签名 + 获取临时凭证
# ============================================================
class dogecloud_auth:
    """
    多吉云 API 鉴权类，负责 HMAC-SHA1 签名并获取腾讯云 COS 临时凭证。

    用法示例：
        auth = dogecloud_auth("your_access_key", "your_secret_key")
        tmp_cred = auth.get_tmp_credentials("api-01")
        # 返回 {access_key_id, secret_access_key, session_token, s3_bucket, s3_endpoint}

    API 文档：https://docs.dogecloud.com/oss/api-tmp-token
    """

    _api_base = "https://api.dogecloud.com"

    def __init__(self, access_key, secret_key):
        """
        初始化鉴权客户端。

        示例：
            auth = dogecloud_auth("ak_xxx", "sk_xxx")
        """
        self._access_key = access_key
        self._secret_key = secret_key

    def _sign(self, path, body):
        """
        HMAC-SHA1 签名。

        签名规则：
            待签字符串 = "{path}\n{body}"
            Signature  = hex(HMAC-SHA1(secret_key, 待签字符串))

        示例：
            sig = auth._sign("/oss/tmp/token.json", "bucket=api-01")
        """
        string_to_sign = f"{path}\n{body}"
        return hmac.new(
            self._secret_key.encode("utf-8"),
            string_to_sign.encode("utf-8"),
            hashlib.sha1,
        ).hexdigest()

    def get_tmp_credentials(self, bucket):
        """
        调用多吉云 API 获取腾讯云 COS 临时凭证。

        参数：
            bucket  多吉云桶名（如 api-01），用于从响应的 Buckets 数组中匹配对应桶信息

        返回：
            dict {access_key_id, secret_access_key, session_token, s3_bucket, s3_endpoint}

        示例：
            cred = auth.get_tmp_credentials("api-01")
        """
        path = "/auth/tmp_token.json"
        payload = json.dumps({"channel": "OSS_FULL", "scopes": ["*"]})
        signature = self._sign(path, payload)

        url = f"{self._api_base}{path}"
        headers = {
            "Authorization": f"TOKEN {self._access_key}:{signature}",
            "Content-Type": "application/json",
        }

        resp = requests.post(url, data=payload, headers=headers, timeout=15)
        resp.raise_for_status()

        data = resp.json()
        if data.get("code") != 200:
            raise RuntimeError(f"多吉云 API 错误：code={data.get('code')}，msg={data.get('msg')}")

        cred = data["data"]["Credentials"]
        bucket_info = next(
            (b for b in data["data"].get("Buckets", []) if b["name"] == bucket),
            None,
        )
        if bucket_info is None:
            raise RuntimeError(f"多吉云桶 '{bucket}' 未找到，请检查 dogecloud_bucket 配置")
        return {
            "access_key_id":     cred["accessKeyId"],
            "secret_access_key": cred["secretAccessKey"],
            "session_token":     cred["sessionToken"],
            "s3_bucket":         bucket_info["s3Bucket"],
            "s3_endpoint":       bucket_info["s3Endpoint"],
        }


# ============================================================
# dogecloud_uploader — boto3 S3 客户端，执行文件上传
# ============================================================
class dogecloud_uploader:
    """
    基于 boto3 的 S3 上传类，使用多吉云临时凭证将文件上传到腾讯云 COS。

    用法示例：
        uploader = dogecloud_uploader(config, tmp_cred)
        uploader.upload_file("/local/path/a.jpg", "articles/2024/a.jpg")
    """

    def __init__(self, cfg, tmp_cred):
        """
        初始化 boto3 S3 客户端。

        参数：
            cfg       配置 dict（含 region，可选，默认 ap-chengdu）
            tmp_cred  临时凭证 dict（含 access_key_id、secret_access_key、session_token、s3_bucket、s3_endpoint）

        示例：
            uploader = dogecloud_uploader(cfg, cred)
        """
        self._bucket = tmp_cred["s3_bucket"]
        self._client = boto3.client(
            "s3",
            endpoint_url=tmp_cred["s3_endpoint"],
            region_name=cfg.get("region", "ap-chengdu"),
            aws_access_key_id=tmp_cred["access_key_id"],
            aws_secret_access_key=tmp_cred["secret_access_key"],
            aws_session_token=tmp_cred["session_token"],
            config=Config(s3={"addressing_style": "virtual"}),
        )

    def upload_file(self, local_path, cdn_key):
        """
        上传单个文件到 CDN，自动推断 Content-Type。

        参数：
            local_path  本地文件绝对路径
            cdn_key     CDN 上的 key（如 articles/2024/a.jpg）

        示例：
            uploader.upload_file("/tmp/a.jpg", "articles/2024/a.jpg")
        """
        content_type, _ = mimetypes.guess_type(local_path)
        if not content_type:
            content_type = "application/octet-stream"

        extra_args = {"ContentType": content_type}

        self._client.upload_file(
            Filename=local_path,
            Bucket=self._bucket,
            Key=cdn_key,
            ExtraArgs=extra_args,
        )


# ============================================================
# dogecloud_tool — 主交互流程（入口）
# ============================================================
class dogecloud_tool:
    """
    多吉云 CDN 上传工具主类，负责协调配置、鉴权、上传的完整交互流程。

    用法示例：
        tool = dogecloud_tool()
        tool.run()

    命令行参数：
        --reset-config  强制重新输入并覆盖旧配置
    """

    def __init__(self):
        """
        初始化工具，解析命令行参数。

        示例：
            tool = dogecloud_tool()
        """
        parser = argparse.ArgumentParser(
            description="多吉云 CDN 上传工具",
            add_help=True,
        )
        parser.add_argument(
            "--reset-config",
            action="store_true",
            help="强制重新输入配置（覆盖旧配置）",
        )
        self._args = parser.parse_args()

    def run(self):
        """
        主流程入口：加载配置 → 输入路径 → 预览 → 确认 → 获取凭证 → 上传。

        示例：
            tool = dogecloud_tool()
            tool.run()
        """
        print("=== 多吉云 CDN 上传工具 ===\n")

        # 1. 加载配置
        cfg_mgr = dogecloud_config()
        cfg = cfg_mgr.get(reset=self._args.reset_config)

        # 2. 输入路径
        local_path, cdn_dir = self._prompt_path()

        # 3. 构建上传列表
        upload_list = self._build_list(local_path, cdn_dir)
        if not upload_list:
            print("未找到任何文件，退出。")
            return

        # 4. 预览
        self._show_preview(upload_list, cfg)

        # 5. 确认
        confirm = input("\n确认上传? (y/n): ").strip().lower()
        if confirm != "y":
            print("已取消。")
            return

        # 6. 获取临时凭证
        print("\n正在获取临时凭证...")
        auth = dogecloud_auth(cfg["access_key"], cfg["secret_key"])
        tmp_cred = auth.get_tmp_credentials(cfg["dogecloud_bucket"])

        # 7. 上传
        self._do_upload(upload_list, cfg, tmp_cred)

    def _prompt_path(self):
        """
        交互式输入本地路径和 CDN 目标目录。

        返回：
            (local_path: str, cdn_dir: str)

        示例：
            local_path, cdn_dir = tool._prompt_path()
        """
        while True:
            local_path = input("本地文件/文件夹路径: ").strip()
            # 展开 ~ 和相对路径
            local_path = os.path.expanduser(local_path)
            local_path = os.path.abspath(local_path)
            if os.path.exists(local_path):
                break
            print(f"路径不存在：{local_path}，请重新输入。")

        cdn_dir = input("CDN 目标目录 (如 articles/2024): ").strip().strip("/")
        return local_path, cdn_dir

    def _build_list(self, local_path, cdn_dir):
        """
        构建上传文件列表。

        路径映射规则：
            单文件：{cdn_dir}/{文件名}
            文件夹：{cdn_dir}/{相对于文件夹的子路径}（递归扫描所有文件）

        参数：
            local_path  本地绝对路径（文件或文件夹）
            cdn_dir     CDN 目标目录（已去除末尾斜杠）

        返回：
            list of (本地绝对路径, CDN key)

        示例：
            items = tool._build_list("/tmp/images", "articles/2024")
        """
        upload_list = []

        if os.path.isfile(local_path):
            filename = os.path.basename(local_path)
            cdn_key = f"{cdn_dir}/{filename}" if cdn_dir else filename
            upload_list.append((local_path, cdn_key))

        elif os.path.isdir(local_path):
            base_dir = local_path
            for root, _dirs, files in os.walk(base_dir):
                for filename in sorted(files):
                    abs_path = os.path.join(root, filename)
                    rel_path = os.path.relpath(abs_path, base_dir)
                    # 统一使用正斜杠
                    rel_path = rel_path.replace(os.sep, "/")
                    cdn_key = f"{cdn_dir}/{rel_path}" if cdn_dir else rel_path
                    upload_list.append((abs_path, cdn_key))

        return upload_list

    def _show_preview(self, upload_list, cfg):
        """
        打印上传预览表格。

        示例：
            tool._show_preview(upload_list, cfg)
        """
        cdn_domain = cfg["cdn_domain"].rstrip("/")
        total = len(upload_list)
        print(f"\n上传预览 (共 {total} 个文件):")

        # 计算对齐宽度
        max_name_len = max(len(os.path.basename(p)) for p, _ in upload_list)
        max_key_len  = max(len(k) for _, k in upload_list)

        for local_path, cdn_key in upload_list:
            name = os.path.basename(local_path)
            cdn_url = f"{cdn_domain}/{cdn_key}"
            print(
                f"  {name:<{max_name_len}}"
                f"  →  {cdn_key:<{max_key_len}}"
                f"  →  {cdn_url}"
            )

    def _do_upload(self, upload_list, cfg, tmp_cred):
        """
        逐文件上传，打印进度。

        参数：
            upload_list  [(本地绝对路径, CDN key), ...]
            cfg          配置 dict
            tmp_cred     临时凭证 dict

        示例：
            tool._do_upload(upload_list, cfg, tmp_cred)
        """
        uploader = dogecloud_uploader(cfg, tmp_cred)
        total = len(upload_list)
        failed = []

        for idx, (local_path, cdn_key) in enumerate(upload_list, start=1):
            name = os.path.basename(local_path)
            try:
                uploader.upload_file(local_path, cdn_key)
                print(f"  [{idx}/{total}] {name}   ✓")
            except Exception as e:
                print(f"  [{idx}/{total}] {name}   ✗  ({e})")
                failed.append((local_path, cdn_key, str(e)))

        if failed:
            print(f"\n上传完成，{len(failed)} 个文件失败：")
            for local_path, cdn_key, err in failed:
                print(f"  {local_path}  →  {cdn_key}  ({err})")
        else:
            print("\n上传完成！")


# ============================================================
# 入口
# ============================================================
if __name__ == "__main__":
    tool = dogecloud_tool()
    tool.run()
