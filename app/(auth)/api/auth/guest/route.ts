import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const redirectUrl = url.searchParams.get("redirectUrl") ?? "/login";

  return NextResponse.redirect(new URL(`/login?redirectUrl=${encodeURIComponent(redirectUrl)}`, request.url));
}
