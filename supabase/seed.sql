-- ============================================================
-- REC LIVESTOCK & AGRO FARMS — Seed data (DEMO / starter data)
-- Run after schema.sql.
-- NOTE: prices/stock below are SAMPLE starter data. Replace real
-- values from the Admin panel → Products once the business pricing
-- is finalised.
-- ============================================================

-- ---------- Categories ----------
insert into public.categories (name, slug, description, image, sort_order) values
  ('Poultry', 'poultry', 'Broilers, layers, cockerels, day-old chicks, turkeys, ducks and guinea fowl.', 'assets/images/roosters.jpg', 1),
  ('Eggs', 'eggs', 'Table eggs, fertile eggs and hatching eggs from healthy layers.', 'assets/images/eggs.jpg', 2),
  ('Livestock', 'livestock', 'Goats, rams, sheep, cattle and pigs raised with proper care.', 'assets/images/goat.png', 3),
  ('Fish', 'fish', 'Catfish, tilapia and fingerlings from clean well-managed ponds.', 'assets/images/category-fish.svg', 4),
  ('Farm Supplies', 'farm-supplies', 'Feed, vitamins and equipment for farmers and farm businesses.', 'assets/images/category-supplies.svg', 5)
on conflict (slug) do nothing;

-- ---------- Sample products ----------
insert into public.products
  (category_id, name, slug, description, price, unit, image_url, stock_quantity, minimum_order_quantity, online_orderable, featured, active, breed, age, sex, weight, delivery_info, size)
select c.id, p.name, p.slug, p.description, p.price, p.unit, p.image, p.stock, p.moq, p.online, p.featured, p.active, p.breed, p.age, p.sex, p.weight, p.delivery, p.size
from (values
  ('poultry', 'Day-old Broiler Chicks', 'day-old-broiler-chicks',
   'Healthy, fast-growing day-old broiler chicks from well-managed parent stock. Ideal for commercial and backyard broiler production.',
   42500, 'per 50 chicks', 'assets/images/day-old-chicks.jpg', 24, 1, true, true, true, 'Broiler (Cobb/Arbor Acres)', 'Day-old', 'Straight run', null, 'Carefully packed for nationwide delivery.', null),
  ('poultry', 'Day-old Layer Chicks', 'day-old-layer-chicks',
   'High-yield layer chicks raised for excellent egg production and strong liveability.',
   40000, 'per 50 chicks', 'assets/images/poultry-barn.jpg', 18, 1, true, true, true, 'Layer (Isa Brown)', 'Day-old', 'Female', null, 'Available for nationwide delivery.', null),
  ('farm-supplies', 'Poultry Feed (Top Feed)', 'poultry-feed-top-feed',
   'Balanced, high-quality poultry feed for broilers and layers at every growth stage.',
   12500, 'per 25kg bag', 'assets/images/category-supplies.svg', 220, 1, true, true, true, null, null, null, null, null, null),
  ('fish', 'Fresh Tilapia', 'fresh-tilapia',
   'Freshly harvested tilapia from clean, well-managed ponds.',
   2500, 'per kg', 'assets/images/category-fish.svg', 0, 2, true, true, true, null, null, null, null, null, null),
  ('livestock', 'Goat (Red Sokoto)', 'goat-red-sokoto',
   'Healthy goats for breeding or household use.',
   85000, 'per goat', 'assets/images/goat.png', 14, 1, true, true, true, 'Red Sokoto', '6–12 months', 'Mixed', '15–25 kg', 'Farm pickup or arranged delivery.', null),
  ('eggs', 'Table Eggs – Large (Crate)', 'table-eggs-large-crate',
   'Large-size fresh table eggs collected daily from healthy layers. 30 eggs per crate.',
   6500, 'per crate (30)', 'assets/images/eggs.jpg', 60, 1, true, true, true, null, null, null, null, null, 'Large'),
  ('eggs', 'Table Eggs – Medium (Crate)', 'table-eggs-medium-crate',
   'Medium-size fresh table eggs collected daily from healthy layers. 30 eggs per crate.',
   6000, 'per crate (30)', 'assets/images/eggs.jpg', 40, 1, true, false, true, null, null, null, null, null, 'Medium'),
  ('eggs', 'Table Eggs – Small (Crate)', 'table-eggs-small-crate',
   'Small-size fresh table eggs collected daily from healthy layers. 30 eggs per crate.',
   5500, 'per crate (30)', 'assets/images/eggs.jpg', 40, 1, true, false, true, null, null, null, null, null, 'Small'),
  ('eggs', 'Hatching Eggs', 'hatching-eggs',
   'Fertile eggs for incubation from proven parent stock.',
   950, 'per egg', 'assets/images/eggs.jpg', 0, 30, true, false, false, null, null, null, null, null, null),
  ('poultry', 'Broilers Meat (Visit Farm)', 'broilers-meat-visit-farm',
   'Fresh broiler meat — currently available for purchase directly at the farm location only.',
   7500, 'per bird', 'assets/images/fowl-local.png', 40, 1, false, false, true, 'Broiler', 'Mature', 'Mixed', '2–3 kg', 'Visit the farm to purchase.', null),
  ('livestock', 'Pigs (Visit Farm)', 'pigs-visit-farm',
   'Healthy pigs — currently available for purchase directly at the farm location only.',
   65000, 'per pig', 'assets/images/pigs.jpg', 8, 1, false, false, true, null, 'Weaner', 'Mixed', null, 'Visit the farm to purchase.', null),
  ('fish', 'Catfish (Live)', 'catfish-live',
   'Live, healthy catfish ready for delivery or pickup.',
   3200, 'per kg', 'assets/images/category-fish.svg', 150, 2, true, false, true, null, null, null, null, null, null),
  ('farm-supplies', 'Fish Feed', 'fish-feed',
   'Quality floating fish feed for growth and health.',
   16500, 'per 15kg bag', 'assets/images/category-supplies.svg', 80, 1, true, false, true, null, null, null, null, null, null),
  ('poultry', 'Turkey (Live)', 'turkey-live',
   'Healthy, well-fed turkeys for rearing, slaughter or festive seasons. Order ahead to reserve yours.',
   45000, 'per turkey', 'assets/images/turkeys.jpg', 25, 1, true, false, true, 'Turkey (Broad-breasted White)', 'Mature', null, null, 'Available for nationwide delivery.', null),
  ('poultry', 'Israel Fowl (Live)', 'israel-fowl-live',
   'Strong, fast-growing Israel fowls for meat or breeding. Raised with proper feeding and care.',
   25000, 'per fowl', 'assets/images/fowl-israel.png', 30, 1, true, false, true, 'Israel Fowl', 'Mature', 'Mixed', null, 'Available for nationwide delivery.', null),
  ('poultry', 'Local Fowl (Free-range)', 'local-fowl-free-range',
   'Free-range local fowls raised on the farm — hardy birds, great for traditional recipes.',
   15000, 'per fowl', 'assets/images/fowl-local.png', 40, 1, true, false, true, 'Local (Free-range)', 'Mature', 'Mixed', null, 'Available for nationwide delivery.', null)
) as p(slug_cat, name, slug, description, price, unit, image, stock, moq, online, featured, active, breed, age, sex, weight, delivery, size)
join public.categories c on c.slug = p.slug_cat
on conflict (slug) do nothing;

-- inventory rows are auto-created by insert trigger

-- ---------- Site settings ----------
insert into public.site_settings
  (id, business_name, motto, phone, whatsapp, email, address, delivery_note,
   social_facebook, social_instagram, social_tiktok,
   whatsapp_channel, whatsapp_group, telegram_channel, telegram_group)
values (1, 'REC Livestock & Agro Farms Enterprises', 'Growing Excellence, Feeding the Future.',
        '+234 813 504 2997', '+2347071850599', 'reclivestockagrofarms@gmail.com', 'Lagos, Nigeria',
        'We deliver across all 36 states of Nigeria and the FCT.',
        'https://www.facebook.com/share/1D56jsdGSk/', 'https://www.instagram.com/recfarms1864',
        'https://www.tiktok.com/@rec.livestock.agr',
        'https://whatsapp.com/channel/0029VbEHZXE7YScuHR7ebE1W',
        'https://chat.whatsapp.com/Gmhomh6VOHtAoaYpx6TlQC?s=cl&p=a&mlu=4&ilr=4',
        'https://t.me/recfarms/yourchannel', NULL)
on conflict (id) do nothing;

-- ---------- Delivery zones (starter; nationwide default fee 0 to be set by admin) ----------
insert into public.delivery_zones (state, delivery_fee, estimated_days, active, special_notes)
select s, 0, 3, true, 'Fee is confirmed at checkout — being updated by the REC team.'
from unnest(array[
  'Abia','Adamawa','Akwa Ibom','Anambra','Bauchi','Bayelsa','Benue','Borno',
  'Cross River','Delta','Ebonyi','Edo','Ekiti','Enugu','FCT - Abuja','Gombe',
  'Imo','Jigawa','Kaduna','Kano','Katsina','Kebbi','Kogi','Kwara','Lagos',
  'Nasarawa','Niger','Ogun','Ondo','Osun','Oyo','Plateau','Rivers','Sokoto',
  'Taraba','Yobe','Zamfara'
]) as s
on conflict do nothing;

-- ---------- Pickup stations (starter; admin can add/remove anytime) ----------
insert into public.pickup_stations (name, state, city, address, contact_phone, operating_hours, pickup_fee, notes, active, sort_order) values
  ('REC Head Office — Umuahia', 'Abia', 'Umuahia', 'REC Livestock & Agro Farms, Umuahia, Abia State', '+2348135042997', 'Mon–Sat, 8am – 6pm', 1000, 'Main farm pickup point. Call ahead to confirm your order is ready.', true, 1),
  ('Abuja — Wuse Market Pickup', 'FCT - Abuja', 'Wuse', 'Wuse Market, Abuja FCT (near the main entrance gate)', '+2348135042997', 'Tue & Sat, 9am – 4pm', 1500, 'Available on market days only.', true, 2),
  ('Lagos — Ikeja Pickup', 'Lagos', 'Ikeja', 'Ikeja, Lagos State (address confirmed on WhatsApp after order)', '+2348135042997', 'Mon–Fri, 10am – 5pm', 1500, 'Bring your order reference number.', true, 3),
  ('Port Harcourt — Mile 1 Pickup', 'Rivers', 'Port Harcourt', 'Mile 1, Port Harcourt, Rivers State (address confirmed on WhatsApp)', '+2348135042997', 'Wed & Sun, 9am – 3pm', 1500, 'Available on market days only.', true, 4)
 on conflict (name) do nothing;

-- ---------- Sample blog posts ----------
insert into public.blog_posts (slug, title, excerpt, content, image, category, author, published, published_at) values
  ('starting-a-poultry-farm-in-nigeria',
   'Starting a Poultry Farm in Nigeria: A Practical Guide',
   'What you need to know about housing, feeding, day-old chicks and the first 8 weeks on a broiler farm.',
   'Starting a poultry farm is one of the most accessible agricultural businesses in Nigeria.\n\nBegin with a clear plan: housing that protects your birds from weather and predators, good ventilation, clean water and quality feed. When you buy day-old chicks, insist on healthy stock from reputable sources and follow the vaccination schedule your supplier recommends.\n\nFor the first eight weeks, keep brooding temperatures steady, observe your birds daily, and keep records of feed intake and any losses. Consistency in feeding and cleanliness is what separates thriving farms from those that struggle.\n\nFinally, plan your market early. Know where you will sell before your broilers are ready, so that healthy birds grow into profit instead of pressure.',
   'assets/images/broiler-chick.jpg', 'Poultry', 'REC Farm Team', true, now() - interval '60 days'),
  ('feeding-your-layers-for-more-eggs',
   'Feeding Your Layers for Maximum Egg Production',
   'A breakdown of layer nutrition and simple management tips that keep your hens laying consistently.',
   'Layers are delicate in one important way: their feed must match their stage. A pullet, a point-of-lay bird and a producing hen all have different nutrient needs.\n\nUse quality layer feed and make sure clean drinking water is always available. Sudden changes in feed, stress, noise or lighting can reduce egg production overnight, so keep routines predictable.\n\nCollect eggs regularly to avoid breakage and keep the laying house clean to reduce disease pressure. Good record keeping helps you notice problems early and correct them fast.',
   'assets/images/eggs.jpg', 'Poultry', 'REC Farm Team', true, now() - interval '30 days'),
  ('catfish-farming-essentials',
   'Catfish Farming Essentials for Beginners',
   'Pond setup, stocking rates, feeding and water quality basics for a successful catfish venture.',
   'Catfish farming starts with good water and ends with good markets. A well-excavated pond, proper stocking density and quality floating feed are the essentials.\n\nCheck your water regularly; clear water with good oxygen levels reduces stress and disease. Start with fingerlings from a trusted farm and feed them consistently without overfeeding.\n\nMany beginners lose fish to poor water quality or sudden temperature changes. Simple daily observation and weekly testing go a long way. And like every farm venture, secure your market before your fish reach table size.',
   'assets/images/category-fish.svg', 'Fish', 'REC Farm Team', true, now() - interval '14 days')
on conflict (slug) do nothing;