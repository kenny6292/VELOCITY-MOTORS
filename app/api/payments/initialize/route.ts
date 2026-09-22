import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { initializePaystackPayment } from "@/lib/paystack";
import { randomUUID } from "crypto";

export async function POST(req: Request) {
  try {
    const sb = await createClient();
    const { data: { user } } = await sb.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: "Authentication required" }, { status: 401 });
    }

    const body = await req.json();
    const amount = Number(body.amount);
    const purpose = String(body.purpose || "vehicle");

    if (!Number.isFinite(amount) || amount <= 0 || amount > 1000000000) {
      return NextResponse.json({ error: "Invalid amount" }, { status: 400 });
    }

    const reference = `VM-${randomUUID()}`;

    const { error } = await sb.from("payments").insert({
      user_id: user.id,
      reference,
      amount,
      purpose,
      metadata: body.metadata || {}
    });

    if (error) throw error;

    const result = await initializePaystackPayment({
      email: user.email!,
      amount,
      reference,
      callback_url: `${process.env.NEXT_PUBLIC_SITE_URL}/api/payments/verify?reference=${reference}`,
      metadata: { purpose, ...(body.metadata || {}) }
    });

    return NextResponse.json(result.data);
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "Payment initialization failed" },
      { status: 500 }
    );
  }
}