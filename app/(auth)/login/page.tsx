"use client";

import Form from "next/form";
import { useRouter, useSearchParams } from "next/navigation";
import { useSession } from "next-auth/react";
import { useActionState, useEffect, useState } from "react";

import { SubmitButton } from "@/components/submit-button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "@/components/toast";
import { type LoginActionState, login } from "../actions";

export default function Page() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectUrl = searchParams.get("redirectUrl") ?? "/";
  const { update: updateSession, status } = useSession();

  const [username, setUsername] = useState("");
  const [isSuccessful, setIsSuccessful] = useState(false);

  const [state, formAction] = useActionState<LoginActionState, FormData>(
    login,
    {
      status: "idle",
    }
  );

  useEffect(() => {
    if (status === "authenticated") {
      router.replace(redirectUrl);
    }
  }, [status, redirectUrl, router]);

  useEffect(() => {
    if (state.status === "failed") {
      toast({
        type: "error",
        description: "无法登录，请重试。",
      });
    } else if (state.status === "invalid_data") {
      toast({
        type: "error",
        description: "请输入有效的用户名。",
      });
    } else if (state.status === "success") {
      setIsSuccessful(true);
      updateSession();
      router.replace(redirectUrl);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.status]);

  const handleSubmit = (formData: FormData) => {
    setUsername((formData.get("username") as string) ?? "");
    formAction(formData);
  };

  return (
    <div className="flex h-dvh w-screen items-start justify-center bg-background pt-12 md:items-center md:pt-0">
      <div className="flex w-full max-w-md flex-col gap-12 overflow-hidden rounded-2xl">
        <div className="flex flex-col items-center justify-center gap-2 px-4 text-center sm:px-16">
          <h3 className="font-semibold text-xl dark:text-zinc-50">欢迎使用</h3>
          <p className="text-gray-500 text-sm dark:text-zinc-400">
            请输入一个用户名开始聊天。
          </p>
        </div>
        <Form action={handleSubmit} className="flex flex-col gap-4 px-4 sm:px-16">
          <div className="flex flex-col gap-2">
            <Label
              className="font-normal text-zinc-600 dark:text-zinc-400"
              htmlFor="username"
            >
              用户名
            </Label>
            <Input
              autoComplete="username"
              autoFocus
              className="bg-muted"
              defaultValue={username}
              id="username"
              name="username"
              placeholder="例如：小明"
              required
              type="text"
            />
          </div>

          <input name="redirectUrl" type="hidden" value={redirectUrl} />

          <SubmitButton isSuccessful={isSuccessful}>进入对话</SubmitButton>
        </Form>
      </div>
    </div>
  );
}
