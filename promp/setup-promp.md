 # setup.sh 生成提示词

 ## 质量规范（AI 必须遵守）

 **结构**
 - 顶部集中放配置变量，方便用户修改
 - 分区注释：配置变量 / 自动检测 / 颜色输出 / 工具函数 / 命令实现

 **工程模式**
 - 符号链接安全：解析 SCRIPT_DIR/PROJECT_DIR 时处理 symlink
 - 颜色输出：info / warn / error / title 四级
 - 幂等 install：可重复运行，不破坏已有状态
 - 原子构建：先构建到临时文件，成功后再替换
 - 幂等写 .env：awk+mktemp 更新已有变量，不存在则追加；.env 不进 git
 - 临时文件：mktemp 后立即 trap 清理
 - 敏感值（密码/Token/API Key）：写入 .env，不出现在命令行参数和 git 中
 - 双平台进程守护：Linux 注册为 systemd 服务（开机自启）；macOS 用 nohup 后台进程（不做系统服务）

 **标准子命令集**

 | 命令 | 职责 |
 |------|------|
 | install | 检查依赖 → 构建 → 注册服务（Linux）→ 启动 → 初始化凭据写 .env（幂等） |
 | uninstall | 列出删除清单 → 二次确认(y/N) → 清理；保留源码/数据库/.env |
 | rebuild | 重新构建并重启 |
 | restart | 仅重启服务，不重新构建（修改 .env 后使用） |
 | update | git pull origin → 询问是否立即 rebuild（日常同步） |
 | push | git push origin |
 | sync | 同步上游开源仓库（仅 fork 项目时包含） |
 | deploy | 输入远程服务器信息（host/user/port/key） → SSH 上传代码/配置 → 远程执行 install |
 | status | 服务状态（PID/端口/运行时长）+ 依赖服务状态 |
 | logs | Linux: journalctl -f；macOS: tail -f logs/ |

 **入口**：无参数显示交互式编号菜单，有参数直接执行子命令，支持 `--help`
