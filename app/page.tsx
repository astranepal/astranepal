import Link from "next/link";
import Image from "next/image";
import { getFeaturedProducts, getCategories, getCollections } from "@/lib/data";
import { ProductCard } from "@/components/product-card";

const services = [
  ["↗", "Fast & reliable delivery", "Delivered across Nepal"],
  ["▣", "Secure checkout", "Protected payment flow"],
  ["↺", "Easy returns", "Simple, convenient support"],
  ["✦", "Premium quality", "Built for everyday wear"],
];

export default async function Home() {
  const [products, categories, collections] = await Promise.all([
    getFeaturedProducts(),
    getCategories(),
    getCollections(),
  ]);

  return (
    <main>
      <div className="hero-wrap shell">
        <section className="hero">
          <Image
            className="hero-image"
            src="https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=2400&q=86"
            alt="ASTRA MEN modern menswear"
            fill
            priority
            sizes="100vw"
          />
          <div className="hero-overlay" />
          <div className="hero-copy">
            <span className="eyebrow">ASTRA MEN · NEW SEASON</span>
            <h1>Style that moves with you.</h1>
            <p>
              Refined everyday menswear with a modern point of view. Clean
              silhouettes, easy layers, and pieces made for life in motion.
            </p>
            <div className="actions">
              <Link className="button blue" href="/products">
                Shop the collection
              </Link>
              <Link
                className="button white"
                href="/products?collection=new-arrivals"
              >
                New arrivals
              </Link>
            </div>
          </div>
          <div className="hero-note">
            <strong>Designed in Nepal</strong>
            <span>Easy essentials, considered details, and a wardrobe that keeps up.</span>
          </div>
        </section>
      </div>

      <section className="section shell">
        <div className="service-grid">
          {services.map(([icon, title, desc]) => (
            <div className="service-card" key={title}>
              <div className="service-icon">{icon}</div>
              <strong>{title}</strong>
              <p>{desc}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="section shell">
        <div className="section-heading">
          <div>
            <span className="eyebrow">Shop by category</span>
            <h2>Build the wardrobe.</h2>
          </div>
          <Link className="text-link" href="/products">
            View all →
          </Link>
        </div>
        <div className="category-grid">
          {categories.map((category) => (
            <Link
              className="category-card"
              href={"/products?category=" + category.slug}
              key={category.id}
            >
              <span>{category.name}</span>
              <small>Explore →</small>
            </Link>
          ))}
        </div>
      </section>

      <section className="section shell">
        <div className="section-heading">
          <div>
            <span className="eyebrow">The edit</span>
            <h2>Pieces worth repeating.</h2>
          </div>
          <Link className="text-link" href="/products">
            Shop all →
          </Link>
        </div>
        {products.length ? (
          <div className="product-grid">
            {products.slice(0, 8).map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        ) : (
          <div className="empty">Products are being prepared.</div>
        )}
      </section>

      <section className="shell collection-grid">
        {collections.slice(0, 4).map((collection) => (
          <Link
            href={"/products?collection=" + collection.slug}
            className="collection-tile"
            key={collection.id}
          >
            {collection.image && (
              <Image
                src={collection.image}
                alt={collection.name}
                fill
                sizes="(max-width:760px) 100vw, 50vw"
              />
            )}
            <div className="tile-copy">
              <span>{collection.name}</span>
              <small>Explore collection →</small>
            </div>
          </Link>
        ))}
      </section>

      <section className="quote-section">
        <span className="eyebrow">The ASTRA MEN point of view</span>
        <blockquote>Less noise. Better pieces. More room to be yourself.</blockquote>
        <p>Modern essentials for workdays, weekends, and everything between.</p>
      </section>
    </main>
  );
}
