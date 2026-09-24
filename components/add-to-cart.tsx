"use client";

import { useMemo, useState } from "react";
import type { Product } from "@/lib/types";
import { useCart } from "@/components/cart-provider";

export function AddToCart({ product }: { product: Product }) {
  const variants = product.product_variants ?? [];

  const sizes = useMemo(
    () => [...new Set(variants.map((variant) => variant.size))],
    [variants],
  );

  const colors = useMemo(
    () => [...new Set(variants.map((variant) => variant.color))],
    [variants],
  );

  const firstAvailable = useMemo(
    () => variants.find((variant) => variant.stock > 0),
    [variants],
  );

  const [size, setSize] = useState(firstAvailable?.size ?? sizes[0] ?? "");
  const [color, setColor] = useState(firstAvailable?.color ?? colors[0] ?? "");
  const [qty, setQty] = useState(1);
  const [msg, setMsg] = useState("");

  const { addItem } = useCart();

  const selected = variants.find(
    (variant) =>
      variant.size === size &&
      variant.color === color &&
      variant.stock > 0,
  );

  function add(buy = false) {
    if (!selected) return;

    addItem({
      productId: product.id,
      variantId: selected.id,
      slug: product.slug,
      name: product.name,
      size: selected.size,
      color: selected.color,
      price: Number(product.price),
      image: product.images[0] ?? "",
      quantity: Math.min(qty, selected.stock),
      maxStock: selected.stock,
    });

    setMsg("Added to bag.");

    if (buy) {
      window.location.href = "/checkout";
    }
  }

  return (
    <div>
      <div className="option-group">
        <span className="eyebrow">Size</span>
        <div className="option-row">
          {sizes.map((optionSize) => {
            const available = variants.some(
              (variant) =>
                variant.size === optionSize && variant.stock > 0,
            );

            return (
              <button
                key={optionSize}
                type="button"
                disabled={!available}
                className={`option ${optionSize === size ? "selected" : ""}`}
                onClick={() => {
                  setSize(optionSize);

                  const matchingVariant = variants.find(
                    (variant) =>
                      variant.size === optionSize && variant.stock > 0,
                  );

                  if (matchingVariant) {
                    setColor(matchingVariant.color);
                  }
                }}
              >
                {optionSize}
              </button>
            );
          })}
        </div>
      </div>

      <div className="option-group">
        <span className="eyebrow">Color</span>
        <div className="option-row">
          {colors.map((optionColor) => {
            const available = variants.some(
              (variant) =>
                variant.size === size &&
                variant.color === optionColor &&
                variant.stock > 0,
            );

            return (
              <button
                key={optionColor}
                type="button"
                disabled={!available}
                className={`option ${optionColor === color ? "selected" : ""}`}
                onClick={() => setColor(optionColor)}
              >
                {optionColor}
              </button>
            );
          })}
        </div>
      </div>

      <div className="availability">
        {selected ? `${selected.stock} available` : "This variant is sold out"}
      </div>

      <div className="qty">
        <button
          type="button"
          aria-label="Decrease quantity"
          onClick={() => setQty((current) => Math.max(1, current - 1))}
        >
          −
        </button>
        <strong>{qty}</strong>
        <button
          type="button"
          aria-label="Increase quantity"
          onClick={() =>
            setQty((current) => Math.min(selected?.stock ?? 1, current + 1))
          }
        >
          +
        </button>
      </div>

      <div style={{ height: 16 }} />

      <div className="purchase-actions">
        <button
          className="button blue"
          disabled={!selected}
          onClick={() => add(false)}
        >
          Add to Cart
        </button>
        <button
          className="button"
          disabled={!selected}
          onClick={() => add(true)}
        >
          Buy Now
        </button>
      </div>

      {msg && <div className="inline-message meta">{msg}</div>}
    </div>
  );
}
