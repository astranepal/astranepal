"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { useCart } from "@/components/cart-provider";

export function Header() {
  const { count } = useCart();
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");

  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const query = q.trim();
    window.location.href = "/products" + (query ? "?q=" + encodeURIComponent(query) : "");
    setOpen(false);
  };

  return (
    <header className="header">
      <div className="announcement">Free delivery over Rs. 3,000 · Made for life in motion</div>
      <nav className="nav">
        <button
          className="icon-btn menu-toggle"
          aria-label={open ? "Close menu" : "Open menu"}
          onClick={() => setOpen((value) => !value)}
          type="button"
        >
          {open ? "×" : "☰"}
        </button>

        <Link href="/" className="brand" onClick={() => setOpen(false)}>
          ASTRA MEN
        </Link>

        <div className="navlinks">
          <Link href="/">Home</Link>
          <Link href="/products">Shop</Link>
          <Link href="/products?collection=new-arrivals">New Arrivals</Link>
          <Link href="/products?collection=street-style">Collections</Link>
          <Link href="/about">About</Link>
          <Link href="/contact">Contact</Link>
        </div>

        <form className="searchbar" onSubmit={submit}>
          <span aria-hidden="true">⌕</span>
          <input
            aria-label="Search products"
            placeholder="Search the collection"
            value={q}
            onChange={(event) => setQ(event.target.value)}
          />
          {q && (
            <button
              type="button"
              className="icon-btn"
              aria-label="Clear search"
              onClick={() => setQ("")}
            >
              ×
            </button>
          )}
        </form>

        <div className="nav-actions">
          <Link href="/account" className="account-link">
            Account
          </Link>
          <Link href="/wishlist" className="wish-link" aria-label="Wishlist">
            ♡
          </Link>
          <Link href="/cart" className="bag">
            Bag ({count})
          </Link>
        </div>
      </nav>

      {open && (
        <div className="mobile-menu">
          <form className="searchbar" onSubmit={submit}>
            <span aria-hidden="true">⌕</span>
            <input
              aria-label="Search products"
              placeholder="Search the collection"
              value={q}
              onChange={(event) => setQ(event.target.value)}
            />
          </form>
          <Link href="/" onClick={() => setOpen(false)}>Home</Link>
          <Link href="/products" onClick={() => setOpen(false)}>Shop</Link>
          <Link href="/products?collection=new-arrivals" onClick={() => setOpen(false)}>New Arrivals</Link>
          <Link href="/products?collection=street-style" onClick={() => setOpen(false)}>Collections</Link>
          <Link href="/about" onClick={() => setOpen(false)}>About</Link>
          <Link href="/contact" onClick={() => setOpen(false)}>Contact</Link>
          <Link href="/wishlist" onClick={() => setOpen(false)}>Wishlist</Link>
          <Link href="/account" onClick={() => setOpen(false)}>Account</Link>
        </div>
      )}
    </header>
  );
}
