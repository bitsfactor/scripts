# Shell 脚本开发质量规范

 开发 bash 脚本时，必须主动检查以下所有条目。

 ## 1. set -eo pipefail 下的函数与调用

 - 函数内统一用 `return 1` 报错，禁止在库函数中用 `exit 1`（exit 跳过调用方）
 - 只在顶层 main / 参数校验 / 真正致命的位置用 `exit 1`
 - 命令替换 `result=$(func)` 当 func 返回非零时，set -e 会在赋值处触发：
   - 若调用方可容忍失败：`result=$(func) || true`
   - 若需要区分成功/失败：`result=$(func) && do_success || handle_fail`
   - 切忌：成功的操作（写文件、重启服务）已完成后，仅因后续的"展示/缓存"步骤
     失败而触发 set -e，导致用户看到错误但操作其实已经成功

 ## 2. 临时文件与清理一致性

 - 每次 mktemp 后立即注册到清理数组，且 INT/TERM trap 要处理它
 - 函数内所有失败路径（包括 unzip、chmod、mv 等）都要调用同一个 cleanup 函数
 - 不能只在前几个 if ! cmd; then cleanup; return 1 处清理，
   后续步骤（解压、权限设置）同样要保护
 - 原子写入模式：mktemp → write → chmod → mv，三步都要有错误处理

 ## 3. URI / URL 构造

 - 出现在 URI fragment (#) 中的字段，所有非 unreserved 字符都必须 percent-encode
   - 空格 → %20，其他特殊字符同理：`${var// /%20}`
 - IPv6 地址在 URI 中必须用 [...] 包裹（RFC 3986）
 - 构造 URI 前，对每个插值字段做非空检查（server_ip、pub、sid 等）
   空值会生成 `vless://@:443` 形式的无效链接

 ## 4. 正则表达式（ERE in bash [[ =~ ]]）

 - 字符类 [...] 中的反斜杠是字面量，不是转义符
   - `[\ ]` 匹配反斜杠和空格，`[ ]` 才只匹配空格
 - 写完正则后用具体的边界用例验证：
   - 合法值能通过，非法值（特殊符号、反斜杠、空格）被正确拦截

 ## 5. 工具输出解析

 - `systemctl is-active` 失败时输出 "failed"/"inactive" 到 stdout，而非空字符串
   用 `|| true` 而不是 `|| echo "inactive"` 作回退，避免双重输出
 - `ss -tlnp "sport = :PORT"` 输出含 header 行，用 `grep -q 'LISTEN'` 而非 `grep -q .`
 - 解析 CLI 输出时，对关键字段做非空校验后再使用

 ## 6. printf vs echo

 - 在 bash 脚本中统一使用 printf，不用裸 echo（echo 在不同系统行为不一致）
   - 纯文本：`printf '%s\n' "$var"`
   - 带 ANSI 色彩的展示行：`echo -e "${COLOR}...${NC}"` 是可接受的例外
   - 空行：`printf '\n'`，不用 `echo ""`

 ## 7. 非原子操作 → 幂等性

 - 安装类操作要做到幂等：已存在的密钥、用户、端口等要复用，不要覆盖
 - 下载二进制/脚本到系统路径时，先写临时文件再 mv（避免部分写入）
 - 对 systemctl enable/disable 等可能静默失败的命令加 `|| warn`

 ## 8. 代码审查 Checklist（每次写完必过）

 □ 所有函数的错误路径是否都用 return 1（非 exit 1）？
 □ 所有 mktemp 创建的文件/目录，失败路径是否都有对应清理？
 □ 所有插入 URI/JSON/heredoc 的变量是否都经过格式校验或 encode？
 □ 所有工具输出的解析是否针对实际输出格式（含 header、多行、空值）？
 □ 所有在"成功操作"之后才调用的"次要操作"（如生成缓存链接）是否加了 || true？
 □ 正则中的字符类是否包含意外字符（尤其是反斜杠）？
 □ set -e 下的命令替换赋值，失败时调用方行为是否符合预期？