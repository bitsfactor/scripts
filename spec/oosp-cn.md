# OOSP 规范 (Object-Oriented Standardized Programming)

## 核心原则
- 一文件一类，禁止继承用组合
- 类和函数必须有注释
- 第三方库需包装成类

## 命名空间
`{分层}.{类名}` → 文件路径
例：`data.database` → `src/data/database.js`

## 目录结构
```
.env          # 环境变量, 不能上传的数据比如key, 管理员密码, 服务器账号等. 禁止放到git中. 
scripts/      # shell工具脚本.
├── setup.sh         # 交互式安装脚本. 包括子命令: 安装,配置,部署,更新仓库等. 
test/         # 测试目录
├── business/        # 业务逻辑层单测目录
src/          # 源代码目录
├── web/             # UI层 - Web界面
├── cli/             # UI层 - 命令行
├── api/             # UI层 - 对外服务接口
├── business/        # 业务逻辑层
├── data/            # 数据访问层
├── model/           # 模型层
├── common/          # 公共层
└── config/          # 配置
```

## 分层调用
```
web/cli/api → business → data
                 ↓        ↙
          model / common / config
```

## 强调
- 使用中文（注释、对话）
- 禁止继承，用组合
- Model层只存数据，不含行为函数
- business层的类的公共函数, 必须有单元测试. 下层不需要单测. 上层不强制单测.
