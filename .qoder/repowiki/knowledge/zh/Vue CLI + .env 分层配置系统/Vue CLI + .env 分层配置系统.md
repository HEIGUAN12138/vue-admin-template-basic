---
kind: configuration_system
name: Vue CLI + .env 分层配置系统
category: configuration_system
scope:
    - '**'
source_files:
    - .env.development
    - .env.production
    - .env.staging
    - src/settings.js
    - vue.config.js
    - src/utils/request.js
    - mock/mock-server.js
---

## 1. 使用的系统与工具

- **构建框架**: Vue CLI (通过 `vue.config.js` 暴露 webpack 配置)。
- **环境变量加载**: 由 Vue CLI 内置的 dotenv 机制自动读取根目录下的 `.env*` 文件，并以 `VUE_APP_` 前缀注入到客户端 `process.env`。
- **运行时应用配置**: 通过 `src/settings.js` 以普通 JS 模块导出静态常量，被 `vue.config.js`、Vuex store 等消费。
- **Mock 服务配置**: `mock/mock-server.js` 作为 devServer 钩子挂载，提供开发期 API 模拟。

## 2. 关键文件与包

- `.env.development` — 开发环境标志 `ENV = 'development'` 与 `VUE_APP_BASE_API = '/dev-api'`。
- `.env.production` — 生产环境标志 `ENV = 'production'` 与 `VUE_APP_BASE_API = '/prod-api'`。
- `.env.staging` — 预发布环境，显式设置 `NODE_ENV = production`，`ENV = 'staging'`，`VUE_APP_BASE_API = '/stage-api'`。
- `src/settings.js` — 应用级静态配置（`title`、`fixedHeader`、`sidebarLogo`）。
- `vue.config.js` — 构建期配置入口，读取 `defaultSettings.title` 并注入 webpack；同时从 `process.env.port` / `npm_config_port` 取 dev server 端口。
- `src/utils/request.js` — 运行时使用 `process.env.VUE_APP_BASE_API` 作为 axios baseURL。
- `mock/mock-server.js` — 在 `vue.config.js` 的 `devServer.before` 中挂载。

## 3. 架构与约定

### 3.1 三层配置来源

| 层级 | 载体 | 作用域 | 读取方式 |
|---|---|---|---|
| 构建期环境变量 | `.env.*` | 仅构建/开发时可用 | Vue CLI 注入 `process.env.VUE_APP_*` |
| 应用静态配置 | `src/settings.js` | 打包后随应用分发 | `require('./src/settings.js')` 或 ES import |
| 运行时动态状态 | Vuex store (`store/modules/settings.js`) | 运行期可修改 | `this.$store.state.settings` |

### 3.2 环境变量命名约定

- 所有需要暴露给浏览器端的环境变量必须带 `VUE_APP_` 前缀（如 `VUE_APP_BASE_API`），这是 Vue CLI 对 dotenv 的强制约束：只有该前缀的变量会被注入到客户端 `process.env`。`request.js` 正是通过 `process.env.VUE_APP_BASE_API` 取得 axios 的 baseURL。
- 每个环境文件都定义一个自定义 `ENV` 字段（值为字符串 `'development'` / `'production'` / `'staging'`），用于业务代码区分环境分支。
- staging 环境额外显式设置 `NODE_ENV = production`，使构建产物走生产模式优化路径。

### 3.3 构建期配置 (`vue.config.js`)

- 从 `src/settings.js` 导入 `defaultSettings`，用其 `title` 作为 webpack 的 `name`，并在注释中说明“页面标题由此注入”。
- dev server 端口优先级：`process.env.port` > `process.env.npm_config_port` > 默认值 `9528`。
- `devServer.before` 同步 require `./mock/mock-server.js`，将 Mock Express 应用挂载到开发服务器。
- 非 development 环境下启用 `ScriptExtHtmlWebpackPlugin` inline runtime chunk、拆分 `chunk-libs` / `chunk-elementUI` / `chunk-commons` 并开启 `runtimeChunk('single')`。

### 3.4 应用静态配置 (`src/settings.js`)

- 以 CommonJS `module.exports` 导出对象，包含 `title`、`fixedHeader`、`sidebarLogo` 三个布尔开关。
- JSDoc 注释标注了类型与用途，供 IDE 提示。

### 3.5 运行时请求基地址

- `src/utils/request.js` 创建 axios 实例时直接读取 `process.env.VUE_APP_BASE_API` 作为 baseURL，因此切换 `.env.*` 即可切换后端 API 根路径。

## 4. 观察到的约定与约束

- **约定**：前端可访问的环境变量统一以 `VUE_APP_` 为前缀，并在 `.env.development` / `.env.production` / `.env.staging` 三套文件中分别声明 `ENV` 与 `VUE_APP_BASE_API`。
- **约定**：构建期行为差异通过 `process.env.NODE_ENV !== 'development'` 判断（见 `vue.config.js` chainWebpack 分支），而非通过自定义 `ENV` 变量。
- **约定**：应用 UI 相关开关集中在 `src/settings.js`，并通过 `vue.config.js` 中的 `defaultSettings.title` 消费，形成“单一配置源”模式。
- **约束**：Vue CLI 只把 `VUE_APP_*` 前缀的环境变量注入到客户端 bundle，其他 `.env` 变量（如 `NODE_ENV`）仅在 Node 侧可用；`request.js` 若引用不带前缀的变量将无法在浏览器端获取。
- **约束**：`.env.staging` 显式设置 `NODE_ENV = production`，否则 staging 构建不会走生产优化分支（由 `vue.config.js` 的 `when(process.env.NODE_ENV !== 'development', ...)` 决定）。
- **约束**：Mock 服务通过 `devServer.before: require('./mock/mock-server.js')` 同步挂载，不能在异步回调中返回 Promise，否则会破坏 devServer 启动流程。
- **约束**：dev server 端口只能从 `process.env.port` 或 `--port` npm 参数覆盖，不能通过 `.env` 中的 `PORT` 变量生效（因为 `vue.config.js` 未读取 `process.env.PORT`）。