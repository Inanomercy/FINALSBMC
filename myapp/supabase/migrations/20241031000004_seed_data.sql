-- =============================================================================
-- Migration 04: Seed Data for OceanCart (Seafood Catalog)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. INSERT CATEGORIES
-- -----------------------------------------------------------------------------
INSERT INTO public.categories (id, name, description, image_url)
VALUES 
    (
        'c1000000-0000-0000-0000-000000000001',
        'Fresh Fish',
        'Wild-caught and farm-fresh prime fish fillets and whole cuts',
        'https://images.unsplash.com/photo-1534948216015-843149f72be3?auto=format&fit=crop&w=600&q=80'
    ),
    (
        'c1000000-0000-0000-0000-000000000002',
        'Shrimps & Prawns',
        'Succulent tiger prawns, white shrimps, and peeled prawn tails',
        'https://images.unsplash.com/photo-1559737558-245cbab6f8e7?auto=format&fit=crop&w=600&q=80'
    ),
    (
        'c1000000-0000-0000-0000-000000000003',
        'Crabs & Lobsters',
        'Fresh live mud crabs, blue swimming crabs, and premium spiny lobsters',
        'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?auto=format&fit=crop&w=600&q=80'
    ),
    (
        'c1000000-0000-0000-0000-000000000004',
        'Shellfish & Mollusks',
        'Scallops, green mussels (tahong), oysters, and sweet clams',
        'https://images.unsplash.com/photo-1628102491629-778571d893a3?auto=format&fit=crop&w=600&q=80'
    ),
    (
        'c1000000-0000-0000-0000-000000000005',
        'Squid & Octopus',
        'Tender giant squid tubes, calamari rings, and cleaned baby octopus',
        'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=600&q=80'
    )
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    image_url = EXCLUDED.image_url;

-- -----------------------------------------------------------------------------
-- 2. INSERT PRODUCTS
-- -----------------------------------------------------------------------------
INSERT INTO public.products (id, category_id, name, description, price, stock, image_url, is_active)
VALUES
    -- Fresh Fish
    (
        'a1000000-0000-0000-0000-000000000001',
        'c1000000-0000-0000-0000-000000000001',
        'Norwegian Atlantic Salmon Fillet',
        'Premium sashimi-grade salmon fillet with rich omega-3 fat marbling. Descaled, deboned, skin-on. Perfect for pan-searing or baking. 500g vacuum-sealed.',
        650.00,
        35,
        'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000002',
        'c1000000-0000-0000-0000-000000000001',
        'General Santos Yellowfin Tuna Loin',
        'Freshly caught Philippine deep-sea yellowfin tuna. Thick cut loin, vibrant ruby red meat, mild ocean flavor. 500g pack.',
        480.00,
        28,
        'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000011',
        'c1000000-0000-0000-0000-000000000001',
        'Dagupan Boneless Milkfish (Bangus)',
        'Fresh deboned Dagupan bangus marinated with garlic and vinegar. Famous fatty belly flavor, ready to fry or grill. 450g pack.',
        220.00,
        50,
        'https://images.unsplash.com/photo-1534948216015-843149f72be3?auto=format&fit=crop&w=600&q=80',
        true
    ),

    -- Shrimps & Prawns
    (
        'a1000000-0000-0000-0000-000000000003',
        'c1000000-0000-0000-0000-000000000002',
        'Jumbo Black Tiger Prawns (Sugpo)',
        'Large headless or whole black tiger prawns. Firm, juicy, and naturally sweet. Excellent for garlic butter, sinigang, or thermidor. 500g (approx 10-12 pcs).',
        580.00,
        45,
        'https://images.unsplash.com/photo-1559737558-245cbab6f8e7?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000004',
        'c1000000-0000-0000-0000-000000000002',
        'Fresh White Shrimp (Suahe)',
        'Daily catch fresh white shrimps with thin shell and succulent sweet meat. Ideal for halabos or tempura. 500g pack.',
        360.00,
        40,
        'https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?auto=format&fit=crop&w=600&q=80',
        true
    ),

    -- Crabs & Lobsters
    (
        'a1000000-0000-0000-0000-000000000005',
        'c1000000-0000-0000-0000-000000000003',
        'Live Mud Crab (Alimango)',
        'Heavy female/male mangrove mud crabs brimming with rich aligue (crab fat) and sweet claw meat. Tied and chilled for freshness. 1kg (2-3 pcs).',
        850.00,
        20,
        'https://images.unsplash.com/photo-1550989460-0adf9ea622e2?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000006',
        'c1000000-0000-0000-0000-000000000003',
        'Tropical Spiny Lobster Tail',
        'Wild caught spiny lobster tails with dense, sweet meat. Premium restaurant grade, flash-frozen at peak freshness. 400g (2 tails).',
        1250.00,
        15,
        'https://images.unsplash.com/photo-1541544741938-0af808871cc0?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000007',
        'c1000000-0000-0000-0000-000000000003',
        'Blue Swimming Crab (Alimasag)',
        'Whole cleaned blue crabs ideal for ginataang alimasag, sweet chili crab, or crab soup. 1kg pack.',
        420.00,
        30,
        'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?auto=format&fit=crop&w=600&q=80',
        true
    ),

    -- Shellfish & Mollusks
    (
        'a1000000-0000-0000-0000-000000000008',
        'c1000000-0000-0000-0000-000000000004',
        'Half-Shell Hokkaido Scallops',
        'Large sweet sea scallops on the half shell. Cleaned and ready for garlic butter broiling or grilling with cheese. 500g (8-10 pcs).',
        390.00,
        30,
        'https://images.unsplash.com/photo-1628102491629-778571d893a3?auto=format&fit=crop&w=600&q=80',
        true
    ),
    (
        'a1000000-0000-0000-0000-000000000009',
        'c1000000-0000-0000-0000-000000000004',
        'Fresh Cavite Green Mussels (Tahong)',
        'Purged and cleaned green mussels harvested from Cavite beds. Plump and tender meat for tinola or butter garlic saute. 1kg.',
        140.00,
        60,
        'https://images.unsplash.com/photo-1548811579-017cf2a4268b?auto=format&fit=crop&w=600&q=80',
        true
    ),

    -- Squid & Octopus
    (
        'a1000000-0000-0000-0000-000000000010',
        'c1000000-0000-0000-0000-000000000005',
        'Fresh Giant Squid (Pusit Lumot)',
        'Cleaned whole giant squid with natural ink sacs preserved. Tender and flavorful when grilled or cooked in classic adobo. 1kg pack.',
        380.00,
        25,
        'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=600&q=80',
        true
    )
ON CONFLICT (id) DO UPDATE SET
    category_id = EXCLUDED.category_id,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    stock = EXCLUDED.stock,
    image_url = EXCLUDED.image_url,
    is_active = EXCLUDED.is_active;
