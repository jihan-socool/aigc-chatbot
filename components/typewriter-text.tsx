"use client";

import { useEffect, useRef, useState } from "react";

type TypewriterTextProps = {
  text: string;
  isStreaming: boolean;
  enableAnimation?: boolean;
  children?: (value: string) => React.ReactNode;
};

export function TypewriterText({
  text,
  isStreaming,
  enableAnimation = true,
  children,
}: TypewriterTextProps) {
  const [displayText, setDisplayText] = useState(() =>
    isStreaming ? text : ""
  );
  const displayedRef = useRef(displayText);

  useEffect(() => {
    displayedRef.current = displayText;
  }, [displayText]);

  useEffect(() => {
    if (!enableAnimation) {
      setDisplayText(text);
      return;
    }

    if (isStreaming) {
      setDisplayText(text);
      return;
    }

    if (text === displayedRef.current) {
      return;
    }

    const startLength = displayedRef.current.length;
    const targetLength = text.length;

    if (targetLength <= startLength) {
      setDisplayText(text);
      return;
    }

    let currentIndex = startLength;
    const step = Math.max(1, Math.floor(targetLength / 45));

    const interval = window.setInterval(() => {
      currentIndex = Math.min(targetLength, currentIndex + step);
      setDisplayText(text.slice(0, currentIndex));

      if (currentIndex >= targetLength) {
        window.clearInterval(interval);
      }
    }, 20);

    return () => {
      window.clearInterval(interval);
    };
  }, [text, isStreaming, enableAnimation]);

  useEffect(() => {
    if (isStreaming) {
      setDisplayText(text);
    }
  }, [isStreaming, text]);

  if (children) {
    return <>{children(displayText)}</>;
  }

  return <>{displayText}</>;
}

