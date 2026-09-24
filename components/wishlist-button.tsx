"use client";

import { type MouseEvent, useEffect, useState } from "react";

type WishlistButtonProps = {
  productId: string;
  initial?: boolean;
  floating?: boolean;
};

export function WishlistButton({
  productId,
  initial = false,
  floating = true,
}: WishlistButtonProps) {
  const [saved, setSaved] = useState(initial);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let active = true;

    fetch("/api/wishlist?product_id=" + encodeURIComponent(productId))
      .then((response) => response.json())
      .then((data) => {
        if (active) setSaved(Boolean(data.saved));
      })
      .catch(() => {});

    return () => {
      active = false;
    };
  }, [productId]);

  async function toggle(event: MouseEvent<HTMLButtonElement>) {
    event.preventDefault();
    event.stopPropagation();
    if (busy) return;

    setBusy(true);
    try {
      const response = await fetch("/api/wishlist", {
        method: saved ? "DELETE" : "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ product_id: productId }),
      });

      if (response.status === 401) {
        window.location.href = "/login";
        return;
      }

      if (response.ok) {
        setSaved((current) => !current);
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <button
      className={floating ? "wishlist-float" : "icon-btn"}
      aria-label={saved ? "Remove from wishlist" : "Add to wishlist"}
      aria-pressed={saved}
      disabled={busy}
      onClick={toggle}
      type="button"
    >
      {saved ? "♥" : "♡"}
    </button>
  );
}
