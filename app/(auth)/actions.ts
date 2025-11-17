"use server";

import { z } from "zod";

import { signIn } from "./auth";

const authFormSchema = z.object({
  username: z
    .string()
    .min(1, "Username is required")
    .max(64, "Username must be 64 characters or fewer"),
  redirectUrl: z.string().optional(),
});

export type LoginActionState = {
  status: "idle" | "in_progress" | "success" | "failed" | "invalid_data";
  redirectUrl?: string;
};

export const login = async (
  _: LoginActionState,
  formData: FormData
): Promise<LoginActionState> => {
  try {
    const validatedData = authFormSchema.parse({
      username: formData.get("username"),
      redirectUrl: formData.get("redirectUrl") ?? undefined,
    });

    await signIn("credentials", {
      username: validatedData.username,
      redirect: false,
    });

    return { status: "success" };
  } catch (error) {
    if (error instanceof z.ZodError) {
      return { status: "invalid_data" };
    }

    return { status: "failed" };
  }
};
