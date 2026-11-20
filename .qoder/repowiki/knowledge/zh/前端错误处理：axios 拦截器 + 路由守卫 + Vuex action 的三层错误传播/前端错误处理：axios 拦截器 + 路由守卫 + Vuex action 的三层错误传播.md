---
kind: error_handling
name: 前端错误处理：axios 拦截器 + 路由守卫 + Vuex action 的三层错误传播
category: error_handling
scope:
    - '**'
source_files:
    - src/utils/request.js
    - src/permission.js
    - src/store/modules/user.js
    - src/api/user.js
    - mock/mock-server.js
---

## 1. 使用的系统与方案

该仓库是一个基于 Vue 2 + Element UI 的前端工程，没有后端服务（`mock/` 目录下的 Express 仅用于开发期 Mock），因此错误处理集中在浏览器端，围绕三个层次组织：

- **HTTP 层**：`src/utils/request.js` 基于 `axios.create()` 创建实例，通过 `interceptors.request` / `interceptors.response` 统一注入 Token、校验业务码、展示全局提示。
- **路由层**：`src/permission.js` 使用 `router.beforeEach` 作为权限守卫，在获取用户信息失败时清理 token 并跳转到登录页。
- **状态层**：`src/store/modules/user.js` 将 API 调用包装为 Vuex actions，用 Promise 透传错误给组件或守卫。

Mock 服务器 `mock/mock-server.js` 仅在热重载 mock 文件时捕获异常并通过 `console.log(chalk.redBright(error))` 输出，不对外暴露结构化错误。

## 2. 关键文件与包

| 文件 | 职责 |
|---|---|
| `src/utils/request.js` | axios 实例、请求/响应拦截器、业务码校验、Token 过期分支 |
| `src/permission.js` | 路由守卫、白名单、获取用户信息失败时的错误处理 |
| `src/store/modules/user.js` | login/getInfo/logout/resetToken 等 action，Promise reject 透传错误 |
| `src/api/user.js` | 薄封装，直接返回 `request(...)` 的 Promise |
| `mock/mock-server.js` | 开发期 Mock 服务器的热重载异常捕获 |

依赖库：`axios`、`element-ui`（`Message`、`MessageBox`）、`nprogress`、`vue-router`、Vuex。

## 3. 架构与约定

### 3.1 HTTP 响应拦截器是统一的错误入口

`src/utils/request.js` 中，响应拦截器对 `response.data.code` 做判断：

- 当 `res.code !== 20000` 时，视为业务错误：弹出 `Message({ type: 'error' })`，然后 `return Promise.reject(new Error(res.message || 'Error'))`。
- 当 `res.code` 为 `50008`、`50012`、`50014` 时，额外触发登出流程：弹出 `MessageBox.confirm('You have been logged out...')`，确认后 dispatch `user/resetToken` 并 `location.reload()`。
- 网络层错误进入响应拦截器的 `error` 回调，同样弹出 `Message({ message: error.message, type: 'error' })` 并 `Promise.reject(error)`。

这意味着所有通过 `@/utils/request` 发起的请求，其错误最终都会以 `Promise.reject(Error)` 的形式向上传播，调用方需要 `.catch` 或 `try/catch` 处理。

### 3.2 业务层只负责透传，不吞掉错误

`src/store/modules/user.js` 中的 `login`、`getInfo`、`logout` 都是 `new Promise((resolve, reject) => { ... }).catch(error => reject(error))` 的模式——即把 axios 的错误原样向上 reject。`getInfo` 还有一处显式拒绝：当后端未返回 data 时 `reject('Verification failed, please Login again.')`（注意这里 reject 的是字符串而非 Error 对象）。

`src/api/user.js` 只是薄封装，直接 return `request(...)`，不做任何 try/catch，保证错误能一路冒泡到调用方。

### 3.3 路由守卫是认证错误的消费点之一

`src/permission.js` 在 `router.beforeEach` 中尝试 `store.dispatch('user/getInfo')`，如果失败：

1. `await store.dispatch('user/resetToken')` 清除本地 token；
2. `Message.error(error || 'Has Error')` 给用户反馈；
3. `next(\`/login?redirect=${to.path}\`)` 重定向到登录页；
4. `NProgress.done()` 结束进度条。

同时，已登录用户访问 `/login` 会被重定向到 `/`，未登录且不在白名单（`whiteList = ['/login']`）的用户也会被重定向到 `/login?redirect=...`。

### 3.4 无自定义错误类型体系

仓库中没有定义专门的错误类或错误码常量文件。业务错误码硬编码在 `src/utils/request.js` 中（`20000` 表示成功，`50008/50012/50014` 表示 Token 相关错误）。没有统一的 `errors/` 目录、`ErrorCode` 枚举或 `CustomError` 类。

### 3.5 调试日志模式

请求拦截器和响应拦截器的错误分支都保留了 `console.log(error)` / `console.log('err' + error)` 的调试输出，注释标注了 `// for debug`。Mock 服务器的热重载异常也通过 `console.log(chalk.redBright(error))` 输出。

## 4. 观察到的约定与约束

- **约定：所有 HTTP 请求必须通过 `@/utils/request` 发起**。`src/api/*.js` 全部 import 该模块，没有直接使用 `axios` 的地方，保证了拦截器逻辑的统一性。
- **约定：业务成功码固定为 `20000`**。`src/utils/request.js` 中 `if (res.code !== 20000)` 是唯一的业务成功判定条件，其他值一律走错误分支。
- **约定：Token 相关错误码集中处理**。`50008`（非法 token）、`50012`（其他客户端登录）、`50014`（token 过期）在响应拦截器中被特殊对待，触发重新登录确认弹窗。
- **约定：Vuex action 不吞错误**。`user.js` 中每个 action 的 `.catch` 分支只做 `reject(error)`，让调用方决定如何处理。
- **约束：路由守卫中异步获取用户信息失败会强制跳转登录页**。这是由 `permission.js` 的 `catch` 分支实现的硬性行为，不是可选项。
- **约束：白名单外的未登录访问一律重定向到 `/login`**。`whiteList = ['/login']` 是唯一例外路径。
- **约束：Mock 服务器热重载期间抛出的异常被静默捕获并打印**，不会中断 dev server，但也不会阻断后续注册流程（见 `mock/mock-server.js` L64-L79 的 try/catch）。

## 5. 缺失的部分

- 没有全局错误边界（如 `Vue.config.errorHandler`）。
- 没有统一的错误码常量文件或自定义错误类型。
- 没有针对 4xx/5xx HTTP 状态码的分类处理（当前只依赖业务 `code`）。
- 没有 Sentry 或其他错误上报集成。
- 单元测试中未见针对错误路径的覆盖（`tests/unit/` 主要覆盖工具函数和简单组件）。