import { createHmac, timingSafeEqual } from "crypto";
import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export async function POST(req: Request) {
  const raw = await req.text();
  const signature = req.headers.get("x-paystack-signature") || "";
  const secret = process.env.PAYSTACK_SECRET_KEY;

  if (!secret) {
    return NextResponse.json(
      { error: "Webhook unavailable" },
      { status: 503 }
    );
  }

  const expected = createHmac("sha512", secret)
    .update(raw)
    .digest("hex");

  if (
    signature.length !== expected.length ||
    !timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
  ) {
    return NextResponse.json(
      { error: "Invalid signature" },
      { status: 401 }
    );
  }

  const event = JSON.parse(raw);

  if (event.event === "charge.success") {
    const reference = event.data?.reference;

    if (reference) {
      const sb = await createClient();

      await sb
        .from("payments")
        .update({
          status: "success",
          paid_at: new Date().toISOString(),
        })
        .eq("reference", reference);
    }
  }

  return NextResponse.json({ received: true });
}
