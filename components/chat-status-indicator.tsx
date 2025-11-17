"use client";

import type { ChatStatus } from "ai";
import { AnimatePresence, motion } from "framer-motion";
import { useEffect, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";

type ChatStatusIndicatorProps = {
  status: ChatStatus;
  isReasoningModel?: boolean;
};

export function ChatStatusIndicator({
  status,
  isReasoningModel = false,
}: ChatStatusIndicatorProps) {
  const shouldShow = status === "submitted" || status === "streaming";
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    if (!shouldShow) {
      setProgress(0);
      return;
    }

    let value = 12;
    setProgress(value);

    const interval = window.setInterval(() => {
      value = value >= 92 ? 12 : value + 8;
      setProgress(value);
    }, 320);

    return () => window.clearInterval(interval);
  }, [shouldShow]);

  const indicatorText = (() => {
    if (status === "submitted") {
      return isReasoningModel
        ? "模型正在深度思考，稍候即可给出答案"
        : "模型正在思考如何回应";
    }
    if (status === "streaming") {
      return isReasoningModel
        ? "推理完成，正在整理回答"
        : "模型正在生成回复";
    }
    return "";
  })();

  const title = status === "submitted" ? "思考中" : "生成中";

  return (
    <AnimatePresence initial={false}>
      {shouldShow && (
        <motion.div
          animate={{ opacity: 1, y: 0 }}
          className="border-b border-border/70 bg-background/80 backdrop-blur supports-[backdrop-filter]:bg-background/60"
          exit={{ opacity: 0, y: -8 }}
          initial={{ opacity: 0, y: -8 }}
          transition={{ duration: 0.18, ease: "easeInOut" }}
        >
          <div className="mx-auto flex w-full max-w-4xl flex-col gap-2 px-4 py-2">
            <div className="flex items-center gap-2 text-sm font-medium text-foreground">
              <span>{title}</span>
              {isReasoningModel && (
                <Badge
                  variant="outline"
                  className="border-primary/40 bg-primary/10 text-primary"
                >
                  深度推理
                </Badge>
              )}
            </div>
            <p className="text-xs text-muted-foreground">{indicatorText}</p>
            <Progress
              aria-label="chat status"
              className="h-[3px] overflow-hidden bg-muted"
              value={progress}
            />
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

