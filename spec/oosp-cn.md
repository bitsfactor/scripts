# OOSP 规范 (Object-Oriented Standardized Programming)

## 核心原则
- 一文件一类，禁止继承用组合
- 命名：全小写下划线（如 `user_service`）
- 类和函数必须有中文注释
- 第三方库需包装成类

## 命名空间
`{项目}.{分层}.{类名}` → 文件路径
例：`demo.data.database` → `demo/data/database.js`

## 目录结构
```
{project}/
├── app/web/cli/    # UI层
├── api/            # API层 (http/ws/rpc)
├── business/       # 业务逻辑层
├── data/           # 数据访问层
├── model/          # 模型层
├── common/         # 公共层
└── config/         # 配置
```

## 分层调用
```
UI → API → Business → Data
      ↘      ↓      ↙
      Model / Common
```

## 分层职责
- **API层**：按协议组织，多协议共用抽到Business层
- **Data层**：数据获取与清洗，业务逻辑放Business层

## 强调
- 使用中文（注释、对话）
- 禁止继承，用组合
- Model层只存数据，不含行为函数
