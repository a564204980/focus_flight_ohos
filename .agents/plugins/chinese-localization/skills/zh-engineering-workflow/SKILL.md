---
name: zh-engineering-workflow
description: Antigravity 中文工程研发流、文档规范与结案复盘标准指南。用于规范 implementation_plan.md 实施方案与 walkthrough.md 结案总结的中文结构与质量。
---

# Antigravity 中文工程研发流与文档规范指南

本规范用于指导 Agent 在进行复杂工程设计与交付时，生成结构严谨、逻辑清晰、易于审阅的中文工程文档。

---

## 一、 实施方案文档规范 (`implementation_plan.md`)

当任务需要重大架构改造、多文件重构或涉及关键决策时，必须先编写中文实施方案并提请用户审核。

### 标准结构模板

```markdown
# [方案名称 / 核心目标]

简明扼要地描述背景、根因及本次方案达成的核心目标。

## 用户审核关键点 (User Review Required)
> [!IMPORTANT]
> 列出任何涉及重大技术选型、破坏性改动（Breaking Changes）或需要用户决策的关键事项。

## 疑点澄清与开放问题 (Open Questions)
> [!NOTE]
> 若有模糊需求或待确认前提，在此集中列出。

## 拟修改文件与改动分解 (Proposed Changes)

### [模块/组件分类名称]
#### [MODIFY] [文件名](file:///绝对路径)
- 说明具体修改点、设计考量与最小改动原则。

#### [NEW] [文件名](file:///绝对路径)
- 说明新建文件的职责与定位。

## 验证与验收计划 (Verification Plan)
### 自动化构建与测试 (Automated Verification)
- 运行测试用例、编译打包指令（如 `hvigorw assembleHap`、`npm test` 等）。

### 手动验收与视觉校验 (Manual Verification)
- 界面视觉核对、特定边界交互复现、回归验证清单。
```

---

## 二、 结案复盘文档规范 (`walkthrough.md`)

任务完成后，必须生成中文结案文档，供用户一目了然地审阅成果与验证证据。

### 标准结构模板

```markdown
# [任务完成 / 修复结案总结]

## 变更概述
简短总结本次任务解决了什么问题、实现了哪些功能。

## 核心改动对比 / 技术亮点
- 以 Markdown 表格或结构化列表对比修改前后的关键逻辑、性能或参数差异。

## 修改的文件清单
- 逐一附带文件超链接 `[文件名](file:///...)` 并简述改动要点。

## 验证与测试结果
- 构建编译输出证据（如 `BUILD SUCCESSFUL`）；
- 核心算法数值计算验证；
- 截图/动效/UI 效果确认。
```
