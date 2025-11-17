# 自定义 AI 聊天助手

基于 Next.js、AI SDK 与自定义 OpenAI 兼容接口打造的中文聊天应用。项目已针对私有部署进行了深度改造，支持自定义模型、中文界面、用户名快速登录以及一键清除用户数据等能力。

## 功能亮点

- **用户名即登录**：首次输入用户名会自动创建账号并记录聊天历史，无需邮箱或密码。
- **多模型支持**：可通过环境变量配置 OpenAI 兼容模型及自定义 Base URL，适配自建网关。
- **推理状态反馈**：顶栏展示思考/生成进度，推理模型会以“深度思考中”提示和打字机动画输出结果。
- **全中文界面**：主要操作提示、按钮与错误信息均改为中文，提升本地化体验。
- **数据可控**：提供 `pnpm clear-user <username>` 命令，快速删除指定用户及其全部聊天记录。

## 快速开始

```bash
pnpm install
# 调整数据库结构（见下方说明）
pnpm dev
```

访问 `http://localhost:3000`，输入任意用户名即可开始对话。

## 数据库调整

代码已经将 `User` 表改为 `id + username` 结构，如数据库仍是旧版本，请执行以下 SQL：

```sql
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "username" VARCHAR(64);
UPDATE "User" SET "username" = COALESCE("username", CONCAT('user_', SUBSTRING(id::text, 1, 8))) WHERE "username" IS NULL OR "username" = '';
ALTER TABLE "User" ALTER COLUMN "username" SET NOT NULL;
ALTER TABLE "User" DROP COLUMN IF EXISTS "email";
ALTER TABLE "User" DROP COLUMN IF EXISTS "password";
CREATE UNIQUE INDEX IF NOT EXISTS "User_username_unique" ON "User" ("username");
```

## 环境变量

在项目根目录创建 `.env.local`，至少配置以下项目：

```bash
OPENAI_API_KEY=你的API密钥
OPENAI_API_URL=https://你的网关域名/v1
OPENAI_CHAT_MODEL=自定义主模型ID
OPENAI_REASONING_MODEL=自定义推理模型ID
OPENAI_TITLE_MODEL=自定义标题模型ID
OPENAI_ARTIFACT_MODEL=自定义文档模型ID
NEXT_PUBLIC_OPENAI_CHAT_MODEL_DISPLAY_NAME=主模型显示名称
NEXT_PUBLIC_OPENAI_REASONING_MODEL_DISPLAY_NAME=推理模型显示名称
```

> 提示：`OPENAI_API_URL` 会自动补齐 `/v1`，填写时可带或不带，全局都会指向 `/v1/chat/completions`。

## 常用命令

| 命令 | 说明 |
| ---- | ---- |
| `pnpm dev` | 启动本地开发环境 |
| `pnpm clear-user <username>` | 删除指定用户名及其所有聊天记录 |
| `pnpm db:migrate` | 执行 Drizzle 迁移（如有需要） |

## 自定义说明

- 右上角及右下角的 Vercel 相关入口已移除，界面保持纯净。
- 所有默认文案改为中文，若需新增自定义提示，可在对应组件内直接修改字符串。
- `scripts/clear-user.ts` 支持一键清理用户，可在定期维护或自助操作时使用。

## 致谢

项目基于 [Next.js](https://nextjs.org)、[AI SDK](https://ai-sdk.dev)、[shadcn/ui](https://ui.shadcn.com) 等优秀开源生态构建，感谢原模板的启发与支持。
