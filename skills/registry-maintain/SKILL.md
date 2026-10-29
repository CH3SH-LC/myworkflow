---
name: 专项注册表维护
description: Use when 需要更新专项任务注册表（config/special-skills.json）、添加或移除专项 skill、或回答"有哪些专项技能/专项 skill"时调用
---
# 专项注册表维护

## 定位

本技能维护 **DSH 技能 catalog**（现行 15 个技能），也是「这个包有哪些技能」的唯一答案来源：答案取自 `src/registry.js` 的 `listSkills()` / `REGISTRY.skills`，而不是任何手写清单。

- **维护对象**：`components/<name>/component.json` 与 `parts/`、`components/<name>.js` 薄模块、`cordis.patch.yml` 行、`locale/{zh,en}.json` 技能键、`src/registry.js` 运行时注册表。
- **旧的单一「专项注册表」文件已不存在**：现行清单由上面五处共同决定，漏改任何一处都会让某条断言 FAIL。
- **本技能只负责清单与一致性验证**（新增 / 改名 / 下线后核对），不改写其它技能的方法论正文。
- **触发**：要增删改技能、要核对技能名旧引用残留、或要回答「有哪些技能 / 现在多少个技能」时。

前置事实：`src/registry.js` 在模块求值时静态收集 15 个组件 → 校验（kebab-case 名称、五个字段非空、正文非空、无重名）→ 按 name 排序导出冻结列表；校验失败不静默，`REGISTRY.errors` 保留全部问题，只对外提供通过校验的技能。
## 文件结构

```
components/<name>/component.json   元数据：name/displayName/description/whenToUse/summary/parts[]/派生字段
components/<name>/parts/NN-slug.md 正文分片；头部只有 title/summary，正文与派生值由拼结算出
components/<name>.js               薄模块：assembleComponent(import.meta.url)，不含正文
cordis.patch.yml                   每技能一行：id: skill-<短名> / name: @local/dsh-myworkflow-skills/skill /
                                   config.skill = 全名 / config.summary = component.json 的 summary
locale/{zh,en}.json                skills 键集 = 15 个技能名；中文值 = component.displayName
src/registry.js                    运行时注册表：静态 import 15 个组件 → 校验 → 排序 → 冻结列表（listSkills）
src/shared.js buildCatalog()       启动段把 REGISTRY.skills 映射成 catalog 行（summary/parts/指纹/detailCount）
```

三处必须同源，改完逐处核：

1. `component.json.summary` == 该技能在 `cordis.patch.yml` 那一行的 `config.summary`。
2. `locale/zh.json` 的技能中文值 == `component.json.displayName`（改显示名必须同时改 locale）。
3. `component.json.parts[]` 的 `title` / `summary` == 各 part 文件头部的同名字段；`path` 必须形如 `parts/NN-slug.md`。

catalog 只读线路：`buildCatalog()` 的结果经 `/plugin/myworkflow-skills/catalog` 只读暴露（只接受 GET/HEAD，其它方法返回 `METHOD_NOT_ALLOWED`）。这是派生快照——可以读来核对，不能当输入手改。
## 更新流程

**新增技能**

1. 建 `components/<name>/`：`component.json`（`name` 与目录名一致，`parts[]` 含 `id/title/summary/path/tier`）+ `parts/NN-slug.md`（头部 title/summary）。
2. 建薄模块 `components/<name>.js`：`export const skill = assembleComponent(import.meta.url);`。
3. `src/registry.js`：加静态 `import` 并把模块放进 `MODULES`（静态收集，漏登记等于技能不存在）。
4. `cordis.patch.yml`：加一行 `id: skill-<短名>`（短名 = 全名去掉 `myworkflow-`），`config.skill` = 全名，`config.summary` 照抄 `component.json.summary`。
5. `locale/zh.json`、`locale/en.json`：各加同名技能键，中文值 = `displayName`。

**改名**：目录名、`component.json.name`、薄模块文件名、`registry.js` 的 import 与 `MODULES`、patch 行的 `id` 与 `config.skill`、两个 locale 键——七处同改，旧名 grep 必须 0 命中。

**下线**：反向执行上面五步（删目录、删模块、删 registry 登记、删 patch 行、删 locale 键）。

**改完必做**

1. **重算派生字段**：`bodyChars` / `bodySha256` / `injectedChars` / `injectedSha256` / `detailCount` 不许手写，必须用 `src/assemble.js` 的 `partitionParts` / `composeBody` / `injectedFingerprint` 同口径重算（全部 parts 为 core 时注入正文 = 全量拼接，无细节索引）。
2. **门禁**（cwd = 包根目录，三条都要真实退出码）：`node src/selfcheck.js` 必须 PASS；`node .migration/verify-tier-model.mjs --all` 必须 PASS；`node --test` 必须全过。
3. **残留检查**：对旧技能名与旧文件路径 grep，命中数必须是 0。
4. **汇报**：新增 / 改名 / 下线各几条 + 每条门禁的输出与退出码；没跑过的命令不能写成通过。
## 自动刷新

**现行没有任何 hooks 扫描脚本，也没有「会话启动时自动改写清单」的机制。** catalog 的来源是代码，不是被扫描出来的文件：

1. `src/registry.js` 在模块求值时完成收集 → 校验 → 排序，`REGISTRY` 是启动时求值一次的冻结常量。
2. `src/shared.js` 启动段 `beginBoot()` 调一次 `buildCatalog()`，把 `REGISTRY.skills` 映射成 catalog 行并冻结；`whenReady()` 与 `catalog()` 回放的也是这份结果。
3. 因此「刷新」= **改文件 → 重跑门禁 → 重启宿主**，重启后由原生 catalog 重新装载生效；没有「不重启就被扫描进表」的路径。

**不要手改自动生成或派生的视图**：`/plugin/myworkflow-skills/catalog` 只是 `buildCatalog()` 结果的 JSON 快照（只接受 GET/HEAD）。可以读它核对 `count`、`complete`、`validation.ok`、每行 `injectedSha256`；不能拿它当输入，也不能手工改。

核对是否真的生效：重启后读该线路，`count` 应为 15、`validation.ok` 应为 true、`complete` 应为 true。任一项不对，说明 `REGISTRY.errors` 非空或某处清单漏改，按更新流程逐处回查（先看 `src/registry.js` 的组件登记，再看 `cordis.patch.yml` 与 `locale/` 键集）。
## 与其它 skill 的关系

- `myworkflow-task-router`：负责**路由**——请求类型不明、要判断该加载哪个技能时先找它。本技能不做路由，只回答「有哪些技能」并保证清单自洽。
- `myworkflow-agent-dev-loop`、`myworkflow-real-world-verify`：改完清单后按它们的验收标准取证（门禁命令 + 真实输出 + 退出码），不接受「文件写了就算完成」。
- `myworkflow-project-maintain`：项目文档同步归它；本技能只动技能 catalog 的载体，两者不交叉改同一份文件。
- 固定分工：任何「有哪些技能 / 多少个技能」的问题，都以 `src/registry.js` 的 `listSkills()` 输出为准，不凭记忆、不凭旧文档或旧清单回答。
- 修改 catalog 属于影响全包加载面的动作：先看清影响面（patch 行 / locale 键 / registry 登记三处是否同改），再有备份地小步改、逐条跑门禁。
