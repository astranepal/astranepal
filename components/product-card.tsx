import Link from "next/link";
import Image from "next/image";
import type { Product } from "@/lib/types";
import { formatNpr } from "@/lib/utils";
import { WishlistButton } from "@/components/wishlist-button";

export function ProductCard({ product }: { product: Product }) {
  return (
    <article className="card">
      <div className="card-image">
        <Link href={"/products/" + product.slug} aria-label={"View " + product.name}>
          {product.images[0] && (
            <Image
              src={product.images[0]}
              alt={product.name}
              fill
              sizes="(max-width:520px) 50vw,(max-width:760px) 33vw,(max-width:1080px) 33vw,25vw"
            />
          )}
        </Link>
        {product.discount > 0 && <span className="badge">-{product.discount}%</span>}
        <WishlistButton productId={product.id} />
      </div>

      <div className="card-info">
        <div className="meta">
          {product.category?.name || "ASTRA MEN"} · {product.collection?.name || "Collection"}
        </div>
        <div className="card-top" style={{ marginTop: 5 }}>
          <Link href={"/products/" + product.slug} className="card-name">
            {product.name}
          </Link>
        </div>

        <Link href={"/products/" + product.slug}>
          <div className="price">
            {formatNpr(product.price)}
            {product.original_price && (
              <span className="old">{formatNpr(product.original_price)}</span>
            )}
          </div>
          <div className="meta">
            ★ {Number(product.rating).toFixed(1)} · {product.review_count} reviews
          </div>
        </Link>

        <div className="card-actions">
          <Link className="mini-button" href={"/products/" + product.slug}>
            View details
          </Link>
        </div>
      </div>
    </article>
  );
}
