import { createOpenAI } from "@ai-sdk/openai";
import {
  customProvider,
  extractReasoningMiddleware,
  wrapLanguageModel,
} from "ai";
import { isTestEnvironment } from "../constants";

// 处理 baseURL：确保格式正确
const getBaseURL = () => {
  const url = process.env.OPENAI_API_URL;
  if (!url) {
    return;
  }

  // 规范化：去除多余的结尾斜杠
  const baseURL = url.replace(/\/+$/, "");

  // 调试日志（仅在开发环境）
  if (process.env.NODE_ENV === "development") {
    console.log("[OpenAI Provider] BaseURL:", baseURL);
  }

  return baseURL;
};

const openai = createOpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  baseURL: getBaseURL(),
});

// 可配置的模型名称，支持通过环境变量覆盖
const chatModelName = process.env.OPENAI_CHAT_MODEL || "gpt-4o";
const reasoningModelName = process.env.OPENAI_REASONING_MODEL || "gpt-4o-mini";
const titleModelName = process.env.OPENAI_TITLE_MODEL || "gpt-4o-mini";
const artifactModelName = process.env.OPENAI_ARTIFACT_MODEL || "gpt-4o";

export const myProvider = isTestEnvironment
  ? (() => {
      const {
        artifactModel,
        chatModel,
        reasoningModel,
        titleModel,
      } = require("./models.mock");
      return customProvider({
        languageModels: {
          "chat-model": chatModel,
          "chat-model-reasoning": reasoningModel,
          "title-model": titleModel,
          "artifact-model": artifactModel,
        },
      });
    })()
  : customProvider({
      languageModels: {
        "chat-model": openai.chat(chatModelName),
        "chat-model-reasoning": wrapLanguageModel({
          model: openai.chat(reasoningModelName),
          middleware: extractReasoningMiddleware({ tagName: "think" }),
        }),
        "title-model": openai.chat(titleModelName),
        "artifact-model": openai.chat(artifactModelName),
      },
    });
