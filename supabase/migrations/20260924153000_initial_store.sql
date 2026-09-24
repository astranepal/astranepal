-- ASTRA MEN initial store migration
create extension if not exists "pgcrypto";

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(), name text not null unique, slug text not null unique,
  description text not null default '', image text, created_at timestamptz not null default now()
);
create table if not exists public.collections (
  id uuid primary key default gen_random_uuid(), name text not null unique, slug text not null unique,
  description text not null default '', image text, created_at timestamptz not null default now()
);
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(), name text not null, slug text not null unique,
  description text not null default '', category_id uuid not null references public.categories(id) on delete restrict,
  collection_id uuid not null references public.collections(id) on delete restrict, price numeric(12,2) not null check(price>=0),
  original_price numeric(12,2) check(original_price is null or original_price>=price),
  discount integer not null default 0 check(discount between 0 and 100), rating numeric(2,1) not null default 0 check(rating between 0 and 5),
  review_count integer not null default 0 check(review_count>=0), stock integer not null default 0 check(stock>=0),
  featured boolean not null default false, images text[] not null default '{}', created_at timestamptz not null default now()
);
create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete cascade,
  size text not null, color text not null, stock integer not null default 0 check(stock>=0), sku text not null unique,
  created_at timestamptz not null default now(), unique(product_id,size,color)
);
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade, full_name text not null default '', phone text not null default '',
  province text not null default '', city text not null default '', delivery_address text not null default '',
  delivery_notes text not null default '', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.wishlists (
  user_id uuid not null references auth.users(id) on delete cascade, product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(user_id,product_id)
);
create table if not exists public.discounts (
  id uuid primary key default gen_random_uuid(), code text not null unique, discount_type text not null check(discount_type in('percentage','fixed')),
  value numeric(12,2) not null check(value>0), max_discount numeric(12,2), minimum_subtotal numeric(12,2) not null default 0,
  usage_limit integer, usage_count integer not null default 0, active boolean not null default true,
  starts_at timestamptz not null default now(), ends_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete set null,
  customer_name text not null, email text not null, phone text not null, province text not null, city text not null,
  delivery_address text not null, delivery_notes text not null default '', subtotal numeric(12,2) not null check(subtotal>=0),
  delivery_fee numeric(12,2) not null check(delivery_fee>=0), discount numeric(12,2) not null default 0 check(discount>=0),
  total numeric(12,2) not null check(total>=0), discount_code text,
  status text not null default 'pending' check(status in('pending','confirmed','packed','shipped','delivered','cancelled')),
  created_at timestamptz not null default now()
);
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict, product_name_snapshot text not null,
  selected_size text not null, selected_color text not null, quantity integer not null check(quantity>0),
  unit_price numeric(12,2) not null check(unit_price>=0), created_at timestamptz not null default now()
);

create index if not exists products_category_idx on public.products(category_id);
create index if not exists products_collection_idx on public.products(collection_id);
create index if not exists products_featured_idx on public.products(featured) where featured=true;
create index if not exists product_variants_product_idx on public.product_variants(product_id);
create index if not exists orders_user_idx on public.orders(user_id,created_at desc);
create index if not exists order_items_order_idx on public.order_items(order_id);

create or replace function public.set_updated_at() returns trigger language plpgsql set search_path=public,pg_catalog as $$
begin new.updated_at=now(); return new; end; $$;
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','')) on conflict(id) do nothing; return new; end; $$;
revoke execute on function public.handle_new_user() from public,anon,authenticated;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.sync_product_stock(p_product_id uuid) returns void language sql set search_path=public,pg_catalog as $$
update public.products p set stock=coalesce((select sum(v.stock) from public.product_variants v where v.product_id=p.id),0) where p.id=p_product_id; $$;
create or replace function public.on_variant_stock_change() returns trigger language plpgsql set search_path=public,pg_catalog as $$
begin perform public.sync_product_stock(coalesce(new.product_id,old.product_id)); if TG_OP='DELETE' then return old; else return new; end if; end; $$;
drop trigger if exists product_variants_sync_product_stock on public.product_variants;
create trigger product_variants_sync_product_stock after insert or update or delete on public.product_variants for each row execute function public.on_variant_stock_change();

create or replace function public.place_order(
  p_customer_name text,p_email text,p_phone text,p_province text,p_city text,p_delivery_address text,p_delivery_notes text,
  p_items jsonb,p_discount_code text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_catalog as $$
declare
  v_user_id uuid:=auth.uid(); v_order_id uuid; v_subtotal numeric(12,2):=0; v_delivery_fee numeric(12,2):=0; v_discount numeric(12,2):=0; v_total numeric(12,2):=0;
  v_discount_code text:=nullif(upper(trim(coalesce(p_discount_code,''))),''); v_discount_id uuid; v_discount_type text; v_discount_value numeric(12,2);
  v_max_discount numeric(12,2); v_minimum_subtotal numeric(12,2); v_usage_limit integer; v_usage_count integer; item jsonb;
  v_product_id uuid; v_variant_id uuid; v_quantity integer; v_name text; v_size text; v_color text; v_unit_price numeric(12,2); v_stock integer;
begin
  if length(trim(coalesce(p_customer_name,'')))<2 then raise exception 'Please provide your full name'; end if;
  if p_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Please provide a valid email'; end if;
  if length(trim(coalesce(p_phone,'')))<7 then raise exception 'Please provide a valid phone number'; end if;
  if length(trim(coalesce(p_province,'')))<2 then raise exception 'Please provide your province'; end if;
  if length(trim(coalesce(p_city,'')))<2 then raise exception 'Please provide your city'; end if;
  if length(trim(coalesce(p_delivery_address,'')))<5 then raise exception 'Please provide your delivery address'; end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Your cart is empty'; end if;
  if jsonb_array_length(p_items)>50 then raise exception 'Too many different items in one order'; end if;

  for item in select value from jsonb_array_elements(p_items) loop
    v_product_id:=nullif(item->>'product_id','')::uuid; v_variant_id:=nullif(item->>'variant_id','')::uuid; v_quantity:=(item->>'quantity')::integer;
    if v_quantity is null or v_quantity<1 or v_quantity>20 then raise exception 'Invalid item quantity'; end if;
    select p.name,p.price,pv.stock,pv.size,pv.color into v_name,v_unit_price,v_stock,v_size,v_color
    from public.product_variants pv join public.products p on p.id=pv.product_id where pv.id=v_variant_id and pv.product_id=v_product_id for update of pv;
    if not found then raise exception 'One of the selected product variants no longer exists'; end if;
    if v_stock<v_quantity then raise exception '% / % is no longer available in the requested quantity',v_name,v_color; end if;
    v_subtotal:=v_subtotal+(v_unit_price*v_quantity);
  end loop;

  if v_discount_code is not null then
    select id,discount_type,value,max_discount,minimum_subtotal,usage_limit,usage_count into v_discount_id,v_discount_type,v_discount_value,v_max_discount,v_minimum_subtotal,v_usage_limit,v_usage_count
    from public.discounts where code=v_discount_code and active=true and starts_at<=now() and (ends_at is null or ends_at>now()) for update;
    if not found then raise exception 'That discount code is invalid or expired'; end if;
    if v_usage_limit is not null and v_usage_count>=v_usage_limit then raise exception 'That discount code has reached its usage limit'; end if;
    if v_subtotal<v_minimum_subtotal then raise exception 'Add more items to use discount %',v_discount_code; end if;
    if v_discount_type='percentage' then v_discount:=round(v_subtotal*v_discount_value/100,2); else v_discount:=least(v_subtotal,v_discount_value); end if;
    if v_max_discount is not null then v_discount:=least(v_discount,v_max_discount); end if;
    update public.discounts set usage_count=usage_count+1 where id=v_discount_id;
  end if;

  v_delivery_fee:=case when v_subtotal>=3000 then 0 else 120 end; v_total:=greatest(v_subtotal+v_delivery_fee-v_discount,0);
  insert into public.orders(user_id,customer_name,email,phone,province,city,delivery_address,delivery_notes,subtotal,delivery_fee,discount,total,discount_code)
  values(v_user_id,trim(p_customer_name),lower(trim(p_email)),trim(p_phone),trim(p_province),trim(p_city),trim(p_delivery_address),coalesce(trim(p_delivery_notes),''),v_subtotal,v_delivery_fee,v_discount,v_total,v_discount_code)
  returning id into v_order_id;

  for item in select value from jsonb_array_elements(p_items) loop
    v_product_id:=nullif(item->>'product_id','')::uuid; v_variant_id:=nullif(item->>'variant_id','')::uuid; v_quantity:=(item->>'quantity')::integer;
    select p.name,p.price,pv.size,pv.color into v_name,v_unit_price,v_size,v_color from public.product_variants pv join public.products p on p.id=pv.product_id where pv.id=v_variant_id and pv.product_id=v_product_id;
    insert into public.order_items(order_id,product_id,product_name_snapshot,selected_size,selected_color,quantity,unit_price) values(v_order_id,v_product_id,v_name,v_size,v_color,v_quantity,v_unit_price);
    update public.product_variants set stock=stock-v_quantity where id=v_variant_id and product_id=v_product_id and stock>=v_quantity;
    if not found then raise exception 'Stock changed while placing the order; please try again'; end if;
  end loop;
  return jsonb_build_object('id',v_order_id,'subtotal',v_subtotal,'delivery_fee',v_delivery_fee,'discount',v_discount,'total',v_total,'status','pending');
end; $$;

revoke all on table public.order_items from anon,authenticated;
revoke all on table public.orders from anon,authenticated;
grant select on public.products,public.product_variants,public.categories,public.collections to anon,authenticated;
grant select on public.profiles,public.wishlists,public.orders,public.order_items to authenticated;
grant insert,update on public.profiles to authenticated;
grant select,insert,delete on public.wishlists to authenticated;
revoke all on public.discounts from anon,authenticated;
grant execute on function public.place_order(text,text,text,text,text,text,text,jsonb,text) to anon,authenticated;

alter table public.categories enable row level security;
alter table public.collections enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.profiles enable row level security;
alter table public.wishlists enable row level security;
alter table public.discounts enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists categories_public_read on public.categories; create policy categories_public_read on public.categories for select to anon,authenticated using(true);
drop policy if exists collections_public_read on public.collections; create policy collections_public_read on public.collections for select to anon,authenticated using(true);
drop policy if exists products_public_read on public.products; create policy products_public_read on public.products for select to anon,authenticated using(true);
drop policy if exists variants_public_read on public.product_variants; create policy variants_public_read on public.product_variants for select to anon,authenticated using(true);
drop policy if exists profiles_select_own on public.profiles; create policy profiles_select_own on public.profiles for select to authenticated using((select auth.uid())=id);
drop policy if exists profiles_insert_own on public.profiles; create policy profiles_insert_own on public.profiles for insert to authenticated with check((select auth.uid())=id);
drop policy if exists profiles_update_own on public.profiles; create policy profiles_update_own on public.profiles for update to authenticated using((select auth.uid())=id) with check((select auth.uid())=id);
drop policy if exists wishlist_select_own on public.wishlists; create policy wishlist_select_own on public.wishlists for select to authenticated using((select auth.uid())=user_id);
drop policy if exists wishlist_insert_own on public.wishlists; create policy wishlist_insert_own on public.wishlists for insert to authenticated with check((select auth.uid())=user_id);
drop policy if exists wishlist_delete_own on public.wishlists; create policy wishlist_delete_own on public.wishlists for delete to authenticated using((select auth.uid())=user_id);
drop policy if exists orders_select_own on public.orders; create policy orders_select_own on public.orders for select to authenticated using((select auth.uid())=user_id);
drop policy if exists order_items_select_own on public.order_items; create policy order_items_select_own on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_items.order_id and o.user_id=(select auth.uid())));
drop policy if exists discounts_no_api_read on public.discounts; create policy discounts_no_api_read on public.discounts for select to anon,authenticated using(false);

insert into storage.buckets(id,name,public) values('product-images','product-images',true),('category-images','category-images',true),('collection-images','collection-images',true) on conflict(id) do update set public=excluded.public;
drop policy if exists store_images_public_read on storage.objects; create policy store_images_public_read on storage.objects for select to anon,authenticated using(bucket_id in('product-images','category-images','collection-images'));

insert into public.categories(name,slug,description,image) values
('T-Shirts','t-shirts','Heavyweight tees, clean graphics and everyday essentials.','https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=82'),
('Shirts','shirts','Refined shirts cut for a modern everyday wardrobe.','https://images.unsplash.com/photo-1516826957135-700dedea698c?auto=format&fit=crop&w=1200&q=82'),
('Bottoms','bottoms','Relaxed trousers, denim and utility-first silhouettes.','https://images.unsplash.com/photo-1542272604-787c3835535d?auto=format&fit=crop&w=1200&q=82'),
('Outerwear','outerwear','Layering pieces built for cooler city days.','https://images.unsplash.com/photo-1490114538077-0a7f8cb49891?auto=format&fit=crop&w=1200&q=82'),
('Knitwear','knitwear','Soft structure and understated texture.','https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1200&q=82')
on conflict(slug) do nothing;

insert into public.collections(name,slug,description,image) values
('New Arrivals','new-arrivals','Fresh silhouettes and newly dropped essentials.','https://images.unsplash.com/photo-1525507119028-ed4c629a60a3?auto=format&fit=crop&w=1600&q=82'),
('Everyday Essentials','everyday-essentials','The core uniform, refined.','https://images.unsplash.com/photo-1523381294911-8d3cead13475?auto=format&fit=crop&w=1600&q=82'),
('Smart Casual','smart-casual','Clean lines for days that need a little more polish.','https://images.unsplash.com/photo-1496747611176-843222e1e57c?auto=format&fit=crop&w=1600&q=82'),
('Street Style','street-style','Relaxed proportions, city energy.','https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=1600&q=82'),
('Seasonal','seasonal','Limited-feel layers for changing weather.','https://images.unsplash.com/photo-1509631179647-0177331693ae?auto=format&fit=crop&w=1600&q=82')
on conflict(slug) do nothing;

insert into public.products(name,slug,description,category_id,collection_id,price,original_price,discount,rating,review_count,featured,images)
select s.name,s.slug,s.description,c.id,cl.id,s.price,s.original_price,s.discount,s.rating,s.review_count,s.featured,s.images
from (values
('Premium Oversized Tee','premium-oversized-tee','A dense 240gsm cotton tee with a boxy shoulder and a soft, structured drape.','t-shirts','everyday-essentials',1490,1690,12,4.8,128,true,ARRAY['https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=82']),
('Everyday Oxford Shirt','everyday-oxford-shirt','A crisp Oxford weave with a relaxed fit, clean collar and easy all-day structure.','shirts','smart-casual',2290,2490,8,4.7,76,true,ARRAY['https://images.unsplash.com/photo-1516826957135-700dedea698c?auto=format&fit=crop&w=1200&q=82']),
('Relaxed Taper Chino','relaxed-taper-chino','Mid-weight cotton twill with a relaxed upper block and softly tapered leg.','bottoms','everyday-essentials',2590,2890,10,4.8,91,true,ARRAY['https://images.unsplash.com/photo-1542272604-787c3835535d?auto=format&fit=crop&w=1200&q=82']),
('Studio Zip Hoodie','studio-zip-hoodie','Brushed fleece, clean hardware and a relaxed silhouette for everyday layering.','outerwear','street-style',3290,3690,11,4.9,54,true,ARRAY['https://images.unsplash.com/photo-1556821840-3a63f95609a7?auto=format&fit=crop&w=1200&q=82']),
('Utility Overshirt','utility-overshirt','A compact cotton overshirt with practical patch pockets and a straight fit.','outerwear','new-arrivals',3790,3990,5,4.7,38,true,ARRAY['https://images.unsplash.com/photo-1490114538077-0a7f8cb49891?auto=format&fit=crop&w=1200&q=82']),
('Straight Selvedge Denim','straight-selvedge-denim','Rigid-feel denim, classic five-pocket construction and an easy straight leg.','bottoms','street-style',4190,4490,7,4.9,67,false,ARRAY['https://images.unsplash.com/photo-1523381294911-8d3cead13475?auto=format&fit=crop&w=1200&q=82']),
('Merino Knit Polo','merino-knit-polo','Fine-gauge knit polo with a soft handfeel and a clean open collar.','knitwear','smart-casual',3490,3790,8,4.8,44,true,ARRAY['https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1200&q=82']),
('Lightweight Coach Jacket','lightweight-coach-jacket','Water-resistant outer layer with a minimalist snap front and adjustable hem.','outerwear','seasonal',3890,4290,9,4.6,23,false,ARRAY['https://images.unsplash.com/photo-1509631179647-0177331693ae?auto=format&fit=crop&w=1200&q=82'])
) s(name,slug,description,cat,col,price,original_price,discount,rating,review_count,featured,images)
join public.categories c on c.slug=s.cat join public.collections cl on cl.slug=s.col
on conflict(slug) do update set name=excluded.name,description=excluded.description,category_id=excluded.category_id,collection_id=excluded.collection_id,price=excluded.price,original_price=excluded.original_price,discount=excluded.discount,rating=excluded.rating,review_count=excluded.review_count,featured=excluded.featured,images=excluded.images;

insert into public.product_variants(product_id,size,color,stock,sku)
select p.id,s.size,s.color,s.stock,upper(replace(p.slug,'-',''))||'-'||upper(replace(s.size,' ',''))||'-'||upper(replace(s.color,' ',''))
from (values
('premium-oversized-tee','S','Black',8),('premium-oversized-tee','M','Black',12),('premium-oversized-tee','L','Black',9),('premium-oversized-tee','M','White',7),('premium-oversized-tee','L','White',6),
('everyday-oxford-shirt','M','White',8),('everyday-oxford-shirt','L','White',10),('everyday-oxford-shirt','M','Sky',7),('everyday-oxford-shirt','L','Sky',5),
('relaxed-taper-chino','30','Stone',7),('relaxed-taper-chino','32','Stone',10),('relaxed-taper-chino','34','Stone',6),('relaxed-taper-chino','32','Black',8),
('studio-zip-hoodie','M','Black',7),('studio-zip-hoodie','L','Black',10),('studio-zip-hoodie','XL','Black',5),('studio-zip-hoodie','L','Olive',6),
('utility-overshirt','M','Charcoal',5),('utility-overshirt','L','Charcoal',7),('utility-overshirt','M','Olive',6),('utility-overshirt','L','Olive',5),
('straight-selvedge-denim','30','Indigo',6),('straight-selvedge-denim','32','Indigo',9),('straight-selvedge-denim','34','Indigo',7),('straight-selvedge-denim','32','Black',5),
('merino-knit-polo','M','Oat',5),('merino-knit-polo','L','Oat',7),('merino-knit-polo','M','Black',6),('merino-knit-polo','L','Black',5),
('lightweight-coach-jacket','M','Navy',4),('lightweight-coach-jacket','L','Navy',6),('lightweight-coach-jacket','L','Sand',4),('lightweight-coach-jacket','XL','Sand',3)
) s(slug,size,color,stock) join public.products p on p.slug=s.slug
on conflict(product_id,size,color) do update set stock=excluded.stock,sku=excluded.sku;

insert into public.discounts(code,discount_type,value,max_discount,minimum_subtotal,usage_limit,active)
values('ASTRA10','percentage',10,500,2500,500,true)
on conflict(code) do update set active=true,value=excluded.value,max_discount=excluded.max_discount,minimum_subtotal=excluded.minimum_subtotal;

update public.products p set stock=coalesce((select sum(v.stock) from public.product_variants v where v.product_id=p.id),0);
revoke execute on function public.set_updated_at() from public,anon,authenticated;
revoke execute on function public.sync_product_stock(uuid) from public,anon,authenticated;
revoke execute on function public.on_variant_stock_change() from public,anon,authenticated;