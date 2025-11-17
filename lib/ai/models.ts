export const DEFAULT_CHAT_MODEL: string = "chat-model";

export type ChatModel = {
  id: string;
  name: string;
  description: string;
};

// 可配置的模型显示名称，支持通过环境变量覆盖
// 使用 NEXT_PUBLIC_ 前缀以支持客户端组件访问
const chatModelDisplayName = 
  process.env.NEXT_PUBLIC_OPENAI_CHAT_MODEL_DISPLAY_NAME || 
  process.env.OPENAI_CHAT_MODEL_DISPLAY_NAME || 
  "GPT-4o";
const reasoningModelDisplayName = 
  process.env.NEXT_PUBLIC_OPENAI_REASONING_MODEL_DISPLAY_NAME || 
  process.env.OPENAI_REASONING_MODEL_DISPLAY_NAME || 
  "GPT-4o Mini";

export const chatModels: ChatModel[] = [
  {
    id: "chat-model",
    name: chatModelDisplayName,
    description: "Advanced multimodal model with vision and text capabilities",
  },
  {
    id: "chat-model-reasoning",
    name: reasoningModelDisplayName,
    description:
      "Fast and efficient model with advanced reasoning capabilities",
  },
];
