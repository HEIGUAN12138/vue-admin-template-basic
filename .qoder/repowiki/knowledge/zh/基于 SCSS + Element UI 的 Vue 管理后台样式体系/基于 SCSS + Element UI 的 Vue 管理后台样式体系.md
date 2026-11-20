---
kind: frontend_style
name: 基于 SCSS + Element UI 的 Vue 管理后台样式体系
category: frontend_style
scope:
    - '**'
source_files:
    - src/styles/index.scss
    - src/styles/variables.scss
    - src/styles/mixin.scss
    - src/styles/sidebar.scss
    - src/styles/element-ui.scss
    - src/styles/transition.scss
    - package.json
---

## 1. 系统与方法论

本项目采用 **Vue 2 + Element UI 2.13** 作为 UI 基础，样式方案为 **SCSS（Sass）**，通过 `@vue/cli-service` 与 `sass-loader`（1.26.8）编译。没有使用 CSS Modules、CSS-in-JS、Tailwind 或 PostCSS 自定义主题变量机制；Element UI 的主题覆盖通过全局 SCSS 文件直接覆盖其类名实现。

- 组件库：`element-ui`（依赖版本 2.13.2），所有 Element 组件样式通过 `src/styles/element-ui.scss` 进行局部覆盖。
- 样式预处理：SCSS，使用 Sass 变量与 mixin。
- 图标：自托管 SVG sprite，通过 `svg-sprite-loader` 在构建时注入，由 `SvgIcon` 组件渲染。
- 动画：基于 Vue `<transition>` 的过渡类（`fade`、`fade-transform`、`breadcrumb-*`），定义在 `transition.scss`。
- 响应式：无媒体查询断点，通过 JS 动态给 `#app` 添加 `.mobile` / `.hideSidebar` 等 class（见 `layout/mixin/ResizeHandler.js`），SCSS 中仅针对这些 class 做布局调整。
- 浏览器兼容：`browserslist` 配置为 `"> 1%, last 2 versions"`，配合 `autoprefixer`（9.5.1）自动补前缀。

## 2. 关键文件

| 文件 | 作用 |
|---|---|
| `src/styles/index.scss` | 样式入口，按顺序引入 variables/mixin/transition/element-ui/sidebar，并定义 body/html/#app 全局重置 |
| `src/styles/variables.scss` | 设计令牌集中地：侧边栏颜色、宽度等 SCSS 变量，并通过 `:export` 暴露给 JS（Webpack magic） |
| `src/styles/mixin.scss` | 可复用 mixin：`clearfix`、`scrollBar`、`relative` |
| `src/styles/sidebar.scss` | 侧边栏主样式，含展开/收起、移动端滑出、菜单 hover 态 |
| `src/styles/element-ui.scss` | Element UI 组件样式补丁（面包屑、上传、对话框、下拉菜单、日期选择器） |
| `src/styles/transition.scss` | 全局 Vue transition 动画类 |
| `package.json` | 声明 `element-ui`、`normalize.css`、`sass`、`sass-loader`、`autoprefixer`、`svg-sprite-loader`、`svgo` 等样式相关依赖 |
| `src/icons/svgo.yml` | SVG 压缩配置，配合 `npm run svgo` 命令 |

## 3. 架构与约定

### 3.1 样式组织
所有全局样式集中在 `src/styles/`，由 `index.scss` 单点聚合导入，组件内部不单独维护独立样式入口。结构分层清晰：

```
src/styles/
├── index.scss          # 入口，按依赖顺序 import
├── variables.scss      # 设计令牌（SCSS 变量）
├── mixin.scss          # 通用 mixin
├── transition.scss     # 全局 transition 动画
├── element-ui.scss     # 覆盖 Element UI 默认样式
└── sidebar.scss        # 布局级样式（侧边栏）
```

### 3.2 设计令牌（Design Tokens）
`variables.scss` 是唯一的视觉常量来源，包括：

- 文本色：`$menuText`、`$menuActiveText`、`$subMenuActiveText`
- 背景色：`$menuBg`、`$menuHover`、`$subMenuBg`、`$subMenuHover`
- 尺寸：`$sideBarWidth: 210px`

这些变量通过 SCSS `:export` 语法导出，供 JS 读取（注释引用了 bluematador 博客说明）。目前被 `settings.js` 和布局逻辑用于动态生成主题色。

### 3.3 Element UI 覆盖策略
项目不通过 Element UI 官方主题工具（如 `element-theme`）定制，而是直接在 `element-ui.scss` 中以 SCSS 类名覆盖默认样式，例如：

- 面包屑字体权重设为 400
- 隐藏原生 file input
- 修复对话框定位问题（GitHub issue #2461）
- 统一上传拖拽区域宽高
- 修正 `el-range-separator` 的 box-sizing

### 3.4 全局重置与基线
`index.scss` 定义了应用基线：

- `body` 设置高度 100%、抗锯齿字体平滑、中文字体栈（PingFang SC、Microsoft YaHei 等）
- `html` 与 `*` 启用 `box-sizing: border-box`
- 链接去除 outline、hover 下划线
- 提供 `.clearfix` 与 `.app-container`（padding 20px）两个全局辅助类

### 3.5 侧边栏布局模式
`sidebar.scss` 围绕 `#app` 根节点组织，核心布局类：

- `.main-container`：内容区，初始 `margin-left: $sideBarWidth`
- `.sidebar-container`：固定定位左侧，宽 `$sideBarWidth`，深色背景
- `.hideSidebar`：收起态，侧边栏缩至 54px，内容区 margin 同步缩小
- `.mobile`：移动端模式，侧边栏改为 transform 滑出
- `.withoutAnimation`：禁用过渡动画

### 3.6 滚动条样式
通过 `mixin.scss` 中的 `@mixin scrollBar` 统一自定义 Webkit 滚动条（轨道 `#d3dce6`、滑块 `#99a9bf`、圆角 20px、宽 6px），并在 `sidebar.scss` 的子菜单弹出层中重复定义相同样式以保持一致。

### 3.7 SVG 图标管线
- 所有图标以原始 SVG 存放在 `src/icons/svg/`（dashboard、example、eye、form、table 等）
- 构建时通过 `svg-sprite-loader` 将 SVG 注入为 sprite
- `src/icons/index.js` 注册到全局 `SvgIcon` 组件
- 通过 `npm run svgo` 调用 `svgo`（1.2.2）批量压缩 SVG，配置文件为 `src/icons/svgo.yml`

## 4. 约定与约束

### 观察到的约定
- 所有全局样式必须从 `src/styles/index.scss` 引入，该文件是唯一的样式聚合入口。
- 设计令牌（颜色、尺寸）只允许在 `variables.scss` 中声明，其他 SCSS 文件通过变量引用而非硬编码值。
- Element UI 组件样式覆盖放在 `element-ui.scss`，避免散落在业务组件中。
- 侧边栏相关样式全部集中在 `sidebar.scss`，并通过 `.hideSidebar` / `.mobile` 等 class 切换状态。
- 动画类统一命名为 `.fade-*`、`.breadcrumb-*` 形式，对应 Vue `<transition>` 的生命周期钩子。
- 图标统一走 SVG sprite 管线，不在业务代码中直接写 `<svg>` 标签。

### 明确约束（有工具链强制）
- 样式文件后缀为 `.scss`，由 `sass-loader` 编译（`package.json` devDependencies 中声明）。
- 浏览器前缀由 `autoprefixer` 根据 `browserslist` 配置自动生成。
- SVG 资源需经 `svgo` 压缩（`npm run svgo` 脚本绑定 `src/icons/svgo.yml`）。
- 样式变量对 JS 的可见性由 `:export` 语法保证（Webpack 支持），这是 JS 读取主题色的唯一通道。

### 未采用的方案
- 无 CSS Modules、无 CSS-in-JS、无 Tailwind、无 styled-components。
- 无媒体查询断点（响应式通过 JS class 切换）。
- 不使用 Element UI 官方主题构建工具，而是直接覆盖类名。
- 无独立的 theme.js / design-tokens.js 等运行时主题系统，主题色来自 SCSS 变量 + `:export`。
