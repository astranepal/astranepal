"use client";

import { createContext, useContext, useEffect, useMemo, useState } from "react";
import type { CartItem } from "@/lib/types";

type CartContext = {
  items: CartItem[];
  count: number;
  subtotal: number;
  addItem: (item: CartItem) => void;
  updateQuantity: (id: string, quantity: number) => void;
  removeItem: (id: string) => void;
  clearCart: () => void;
};

const CartCtx = createContext<CartContext | null>(null);
const KEY = "astra-cart-v1";

export function CartProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = useState<CartItem[]>([]);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as unknown;
        if (Array.isArray(parsed)) {
          setItems(parsed as CartItem[]);
        }
      }
    } catch {
      window.localStorage.removeItem(KEY);
    } finally {
      setHydrated(true);
    }
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    try {
      window.localStorage.setItem(KEY, JSON.stringify(items));
    } catch {
      // Local storage can be unavailable in private or restricted browser contexts.
    }
  }, [items, hydrated]);

  const value = useMemo<CartContext>(
    () => ({
      items,
      count: items.reduce((total, item) => total + item.quantity, 0),
      subtotal: items.reduce((total, item) => total + item.quantity * item.price, 0),
      addItem: (item) =>
        setItems((current) => {
          const index = current.findIndex((existing) => existing.variantId === item.variantId);
          if (index < 0) return [...current, item];

          const next = [...current];
          next[index] = {
            ...next[index],
            quantity: Math.min(next[index].quantity + item.quantity, next[index].maxStock),
          };
          return next;
        }),
      updateQuantity: (id, quantity) =>
        setItems((current) =>
          current.map((item) =>
            item.variantId === id
              ? { ...item, quantity: Math.max(1, Math.min(quantity, item.maxStock)) }
              : item,
          ),
        ),
      removeItem: (id) =>
        setItems((current) => current.filter((item) => item.variantId !== id)),
      clearCart: () => setItems([]),
    }),
    [items],
  );

  return <CartCtx.Provider value={value}>{children}</CartCtx.Provider>;
}

export const useCart = () => {
  const context = useContext(CartCtx);
  if (!context) throw new Error("CartProvider missing");
  return context;
};
