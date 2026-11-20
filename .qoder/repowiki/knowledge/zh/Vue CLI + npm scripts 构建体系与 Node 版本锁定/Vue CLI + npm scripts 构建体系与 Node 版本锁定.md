---
kind: build_system
name: Vue CLI + npm scripts 构建体系与 Node 版本锁定
category: build_system
scope:
    - '**'
source_files:
    - package.json
    - vue.config.js
    - build/index.js
    - dev.cmd
    - .travis.yml
    - .env.development
    - .env.production
    - .env.staging
    - mock/mock-server.js
    - babel.config.js
    - jest.config.js
    - .eslintrc.js
---

## 1. 使用的系统与工具

- **构建中枢**：`@vue/cli-service`（Vue CLI 4.4.4），基于 webpack 4。
- **脚本编排**：`package.json` 的 `scripts` 字段，通过 `npm run <script>` 调用。
- **预览/报告**：自定义 `build/index.js`，使用 `runjs` 执行构建后用 `connect` + `serve-static` 在 9526 端口静态托管 `dist/`。
- **单元测试**：`jest --clearCache && vue-cli-service test:unit`，由 `@vue/cli-plugin-unit-jest` 驱动。
- **CI**：`.travis.yml`，Node 10 环境执行 `npm run test`。
- **Node 版本锁定**：`.tools/node-v16.20.2-win-x64/` 内嵌 Windows 二进制，由 `dev.cmd` 通过修改 `PATH` 强制使用；根目录还附带 `node-v16.20.2-win-x64.zip` 和 `.tools/fetch-node.js`、`.tools/check.js` 用于拉取/校验该运行时。

## 2. 关键文件

- `package.json` — 依赖声明、`scripts`、`engines.node >=8.9`、`browserslist`。
- `vue.config.js` — Vue CLI 配置入口，定义 `publicPath`、`outputDir: 'dist'`、`assetsDir: 'static'`、开发服务器、webpack chain（svg-sprite-loader、splitChunks、runtimeChunk 等）。
- `build/index.js` — `npm run preview` 的自定义构建+预览脚本。
- `dev.cmd` — Windows 启动器，强制 PATH 指向 `.tools/node-v16.20.2-win-x64`。
- `.travis.yml` — Travis CI 配置。
- `.env.development` / `.env.production` / `.env.staging` — 多环境变量模式（对应 `build:prod`、`build:stage`）。
- `mock/mock-server.js` — 开发时通过 `vue.config.js` 的 `devServer.before` 注入 Mock.js 服务。
- `babel.config.js`、`postcss.config.js`、`jest.config.js`、`.eslintrc.js` — 各工具的配置文件。

## 3. 架构与约定

- **单一 npm 工程**：前端应用、Mock 服务、测试套件全部位于同一仓库，通过 `package.json` 的 `scripts` 统一编排。
- **构建产物**：`vue-cli-service build` 输出到 `dist/`，静态资源放在 `dist/static/`。
- **多环境模式**：通过 `--mode staging` 切换 `.env.staging`，默认 `build:prod` 使用 `.env.production`。
- **Webpack chain 定制**：
  - 将 `src/icons` 下的 SVG 走 `svg-sprite-loader`，symbolId 为 `icon-[name]`。
  - 非 development 环境下启用 `ScriptExtHtmlWebpackPlugin` 内联 runtime chunk。
  - `splitChunks` 单独拆分 `element-ui`（chunk-elementUI）、第三方库（chunk-libs）、`src/components` 公共模块（chunk-commons，minChunks=3）。
  - 关闭 prefetch，仅保留 initial preload。
- **预览流程**：`npm run preview` → 先执行 `vue-cli-service build`，再用 connect 在 9526 端口提供 `./dist`，可选 `--report` 生成 report.html。
- **开发时 Mock**：`vue.config.js` 中 `devServer.before: require('./mock/mock-server.js')`，在 dev server 启动前挂载 Mock API。

## 4. 约定与约束

- **Node 版本兼容约束**：`dev.cmd` 注释明确说明“项目运行于 Vue CLI 4 / webpack 4，在 Node 17+ 上会因 OpenSSL 3 移除 md4 而崩溃（ERR_OSSL_EVP_UNSUPPORTED）”，因此 Windows 用户必须通过 `dev.cmd` 启动，强制使用 `.tools/node-v16.20.2-win-x64`。这是仓库内对 Node 版本的硬性约束来源。
- **`engines.node >=8.9`**：`package.json` 声明最低 Node 版本，但实际受限于 Vue CLI 4 与 webpack 4 的运行要求，真实下限更高（见 dev.cmd 注释）。
- **构建命令约定**：`npm run dev` 启动开发服务器，`npm run build:prod` 生产构建，`npm run build:stage` 预发构建，`npm run preview` 本地预览 dist，`npm run test:unit` 运行 Jest 单测，`npm run test:ci` 串行执行 lint + unit test。
- **CI 行为**：`.travis.yml` 固定 `node_js: 10`，执行 `npm run test`（注意 `package.json` 中未定义 `test` 脚本，Travis 会回退到默认的 `npm test`，可能失败——这是一个潜在的 CI 配置不一致点）。
- **浏览器兼容性**：`browserslist` 限定 `> 1%` 且 `last 2 versions`，决定 Babel/Autoprefixer 的转译范围。
- **部署路径**：`vue.config.js` 中 `publicPath: '/'`，注释说明若部署到子路径（如 GitHub Pages `foo.github.io/bar/`）需改为 `/bar/`。
- **SVG 图标规范**：所有 SVG 图标置于 `src/icons/svg/`，通过 `svgo` 压缩（`npm run svgo` 使用 `src/icons/svgo.yml`），构建期由 `svg-sprite-loader` 打包为 sprite。
- **环境变量命名**：通过 `.env.*` 文件区分环境，变量名遵循 `VUE_APP_*` 前缀（由 Vue CLI 注入）。