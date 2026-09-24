-- Final taxonomy + contact security hardening for ASTRA MEN
insert into public.categories(name,slug,description) values
('Hoodies','hoodies','Soft brushed layers for off-duty days.'),
('Jackets','jackets','City-ready outer layers with clean structure.'),
('Jeans','jeans','Easy denim fits made for repeat wear.'),
('Trousers','trousers','Tailored-relaxed trousers for everyday rotation.'),
('Shorts','shorts','Relaxed summer silhouettes.'),
('Sweaters','sweaters','Textured knit layers for cooler days.'),
('Polos','polos','Elevated everyday collars and clean lines.'),
('Accessories','accessories','Small details that finish the look.')
on conflict(slug) do nothing;
update public.products p set category_id=(select id from public.categories where slug='t-shirts') where slug='premium-oversized-tee';
update public.products p set category_id=(select id from public.categories where slug='shirts') where slug='everyday-oxford-shirt';
update public.products p set category_id=(select id from public.categories where slug='trousers') where slug='relaxed-taper-chino';
update public.products p set category_id=(select id from public.categories where slug='hoodies') where slug='studio-zip-hoodie';
update public.products p set category_id=(select id from public.categories where slug='jackets') where slug in ('utility-overshirt','lightweight-coach-jacket');
update public.products p set category_id=(select id from public.categories where slug='jeans') where slug='straight-selvedge-denim';
update public.products p set category_id=(select id from public.categories where slug='polos') where slug='merino-knit-polo';
grant insert on public.contact_messages to anon,authenticated;
drop policy if exists contact_no_read on public.contact_messages;
create policy contact_no_read on public.contact_messages for select to anon,authenticated using(false);
drop policy if exists contact_insert_public on public.contact_messages;
create policy contact_insert_public on public.contact_messages for insert to anon,authenticated with check(true);
revoke execute on function public.save_contact_message(text,text,text,text) from public;
grant execute on function public.save_contact_message(text,text,text,text) to anon,authenticated;