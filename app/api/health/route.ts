import { NextResponse } from "next/server";

// Lightweight liveness/readiness: does not require DB.
export const dynamic = "force-static";

export function GET() {
  return NextResponse.json(
    { status: "ok" },
    { status: 200, headers: { "cache-control": "no-store" } },
  );
}
