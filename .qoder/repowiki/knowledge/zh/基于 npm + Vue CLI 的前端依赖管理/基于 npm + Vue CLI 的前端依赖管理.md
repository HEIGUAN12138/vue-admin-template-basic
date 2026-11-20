---
kind: dependency_management
name: 基于 npm + Vue CLI 的前端依赖管理
category: dependency_management
scope:
    - '**'
source_files:
    - package.json
    - .gitignore
    - .tools/fetch-node.js
    - .tools/check.js
---

## 1. 使用的系统与工具

- **包管理器**: npm（`package.json` 声明依赖，无 `yarn.lock` / `pnpm-lock.yaml` / `npm-shrinkwrap.json`）。
- **构建/运行中枢**: `@vue/cli-service`（Vue CLI 4.4.4），通过 `scripts` 暴露 `dev`、`build:prod`、`build:stage`、`preview`、`svgo`、`lint`、`test:unit`、`test:ci` 等命令。
- **Node 版本约束**: `engines.node >= 8.9`，但项目根目录附带了 Node 16 绿色版（`.tools/node-v16.20.2-win-x64/`），并通过 `.tools/fetch-node.js` 从 `registry.npmmirror.com` 下载该版本，说明实际运行时期望 Node ≥ 16。CI（`.travis.yml`）未在此处展开分析。
- **私有仓库/镜像**: 未见 `.npmrc`；Node 二进制通过 npmmirror 镜像下载，但 npm registry 本身未显式配置，默认使用官方源。
- **锁文件策略**: `package-lock.json` 被 `.gitignore` 忽略，不纳入版本控制；`node_modules/` 同样被忽略，依赖安装由消费者自行完成。

## 2. 关键文件

- `package.json`：唯一依赖清单，分 `dependencies`（运行时）与 `devDependencies`（开发/构建/测试）两类。
- `.gitignore`：排除 `node_modules/`、`dist/`、`.tools/`、`package-lock.json` 等。
- `.tools/fetch-node.js`：从 npmmirror 拉取 Node v16.20.2 绿色版 zip 到本地 `.tools/`。
- `.tools/check.js`：启动后请求 `http://localhost:9528/` 校验 dev server 是否就绪。
- `mock/mock-server.js`：Mock.js + Express 的模拟 API 服务，作为开发期依赖（`mockjs` 在 `devDependencies`）。

## 3. 架构与约定

- **依赖分层**：所有第三方库按用途明确划分——运行时依赖（`axios`、`element-ui`、`vue`、`vue-router`、`vuex`、`core-js`、`js-cookie`、`normalize.css`、`nprogress`、`path-to-regexp`）与开发依赖（Vue CLI 全家桶、ESLint、Jest、Sass、SVGO、Mock.js 等）。没有将运行时依赖误放入 `devDependencies` 或反之。
- **版本锁定方式**：`package.json` 中每个依赖都写死了精确版本号（如 `"vue": "2.6.10"`、`"element-ui": "2.13.2"`、`"@vue/cli-service": "4.4.4"`），而非范围选择符（`^`、`~`），以此保证可重现构建。
- **Node 环境自包含**：项目自带 Node 16 绿色版并脚本化下载，配合 `.tools/check.js` 做健康检查，形成“先拉 Node → 再装依赖 → 再启动 dev server”的本地开发流程。
- **构建产物隔离**：`dist/` 与 `tests/**/coverage/` 均被忽略，仅源码与 `package.json` 提交。

## 4. 约定与约束

- **观察到的约定**：
  - 所有依赖在 `package.json` 中以精确语义化版本声明，不使用 `^`/`~` 前缀。
  - 运行时依赖与开发依赖严格分离到 `dependencies` 与 `devDependencies` 两个字段。
  - `node_modules/`、`package-lock.json`、`.tools/` 不进入版本控制。
  - Node 版本通过 `.tools/fetch-node.js` 固定为 `v16.20.2`，并从 `https://registry.npmmirror.com/-/binary/node/...` 下载。
- **明确的约束**：
  - `engines.node >= 8.9`、`engines.npm >= 3.0.0` 是 `package.json` 中声明的环境要求（npm 会据此给出警告）。
  - `.gitignore` 强制排除 `package-lock.json`，意味着本仓库不通过 lockfile 进行依赖版本同步。
  - `browserslist` 限定目标浏览器为 `"> 1%, last 2 versions"`，影响 `core-js` 与 CSS 前缀注入行为。
- **未发现**：私有 npm registry、`.npmrc`、`vendor/` 目录、Go module 文件或 GOPRIVATE 配置。