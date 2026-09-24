import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { signOut, saveProfile } from "./actions";

export default async function Account() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const [{ data: profile }, { data: orders, error: ordersError }] =
    await Promise.all([
      supabase
        .from("profiles")
        .select("*")
        .eq("id", user.id)
        .maybeSingle(),
      supabase
        .from("orders")
        .select("id,total,status,created_at")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(20),
    ]);

  if (ordersError) {
    throw new Error(ordersError.message);
  }

  return (
    <main className="account-page">
      <span className="eyebrow">Account</span>
      <h1>Your account.</h1>

      <div className="cart-layout">
        <section>
          <div className="info-card">
            <h3>Profile & delivery</h3>

            <form action={saveProfile} className="form-grid">
              <label className="field">
                <span>Full name</span>
                <input
                  name="full_name"
                  defaultValue={profile?.full_name ?? ""}
                  required
                />
              </label>

              <label className="field">
                <span>Phone</span>
                <input
                  name="phone"
                  defaultValue={profile?.phone ?? ""}
                />
              </label>

              <label className="field">
                <span>Province</span>
                <input
                  name="province"
                  defaultValue={profile?.province ?? ""}
                />
              </label>

              <label className="field">
                <span>City</span>
                <input
                  name="city"
                  defaultValue={profile?.city ?? ""}
                />
              </label>

              <label className="field full-span">
                <span>Delivery address</span>
                <textarea
                  name="delivery_address"
                  rows={3}
                  defaultValue={profile?.delivery_address ?? ""}
                />
              </label>

              <label className="field full-span">
                <span>Delivery notes</span>
                <textarea
                  name="delivery_notes"
                  rows={2}
                  defaultValue={profile?.delivery_notes ?? ""}
                />
              </label>

              <div>
                <button className="button blue" type="submit">
                  Save profile
                </button>
              </div>
            </form>
          </div>
        </section>

        <aside className="summary">
          <strong>{user.email}</strong>
          <p className="meta">
            Account security and sign-in are handled by Supabase Auth.
          </p>
          <form action={signOut}>
            <button className="button full" type="submit">
              Sign out
            </button>
          </form>
        </aside>
      </div>

      <section style={{ marginTop: 54 }}>
        <h2>Order history</h2>

        {orders?.length ? (
          orders.map((order) => (
            <div className="cart-item" key={order.id}>
              <div>
                <strong>#{order.id.slice(0, 8).toUpperCase()}</strong>
                <div className="meta">
                  {new Date(order.created_at).toLocaleDateString()} · {order.status}
                </div>
              </div>
              <strong>Rs. {Number(order.total).toLocaleString()}</strong>
            </div>
          ))
        ) : (
          <div className="empty">No orders yet.</div>
        )}
      </section>
    </main>
  );
}
