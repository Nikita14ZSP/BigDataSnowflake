
--- Заполняем справочники

INSERT INTO dim_product_category (category_name)
SELECT DISTINCT product_category FROM raw_data WHERE product_category IS NOT NULL AND product_category != ''
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO dim_pet_category (pet_category_name)
SELECT DISTINCT pet_category FROM raw_data WHERE pet_category IS NOT NULL AND pet_category != ''
ON CONFLICT (pet_category_name) DO NOTHING;

INSERT INTO dim_brand (brand_name)
SELECT DISTINCT product_brand FROM raw_data WHERE product_brand IS NOT NULL AND product_brand != ''
ON CONFLICT (brand_name) DO NOTHING;

INSERT INTO dim_material (material_name)
SELECT DISTINCT product_material FROM raw_data WHERE product_material IS NOT NULL AND product_material != ''
ON CONFLICT (material_name) DO NOTHING;

INSERT INTO dim_color (color_name)
SELECT DISTINCT product_color FROM raw_data WHERE product_color IS NOT NULL AND product_color != ''
ON CONFLICT (color_name) DO NOTHING;

INSERT INTO dim_size (size_name)
SELECT DISTINCT product_size FROM raw_data WHERE product_size IS NOT NULL AND product_size != ''
ON CONFLICT (size_name) DO NOTHING;

INSERT INTO dim_state (state_name)
SELECT DISTINCT store_state FROM raw_data WHERE store_state IS NOT NULL AND store_state != ''
ON CONFLICT (state_name) DO NOTHING;

INSERT INTO dim_country (country_name)
SELECT DISTINCT country FROM (
    SELECT customer_country AS country FROM raw_data WHERE customer_country IS NOT NULL AND customer_country != ''
    UNION
    SELECT seller_country AS country FROM raw_data WHERE seller_country IS NOT NULL AND seller_country != ''
    UNION
    SELECT store_country AS country FROM raw_data WHERE store_country IS NOT NULL AND store_country != ''
    UNION
    SELECT supplier_country AS country FROM raw_data WHERE supplier_country IS NOT NULL AND supplier_country != ''
) AS countries
ON CONFLICT (country_name) DO NOTHING;

INSERT INTO dim_city (city_name)
SELECT DISTINCT city FROM (
    SELECT supplier_city AS city FROM raw_data WHERE supplier_city IS NOT NULL AND supplier_city != ''
    UNION
    SELECT store_city AS city FROM raw_data WHERE store_city IS NOT NULL AND store_city != ''
) AS countries
ON CONFLICT (city_name) DO NOTHING;

INSERT INTO dim_pet_breed (breed_name)
SELECT DISTINCT customer_pet_breed FROM raw_data WHERE customer_pet_breed IS NOT NULL AND customer_pet_breed != ''
ON CONFLICT (breed_name) DO NOTHING;

INSERT INTO dim_pet_type (pet_type_name)
SELECT DISTINCT customer_pet_type FROM raw_data WHERE customer_pet_type IS NOT NULL AND customer_pet_type != ''
ON CONFLICT (pet_type_name) DO NOTHING;


-- Заполняем измерения

INSERT INTO dim_date (full_date, year, quarter, month, day, weekday, week_of_year, day_name, month_name, is_weekend)
SELECT
    datum AS full_date,
    EXTRACT(YEAR FROM datum) AS year,
    EXTRACT(QUARTER FROM datum) AS quarter,
    EXTRACT(MONTH FROM datum) AS month,
    EXTRACT(DAY FROM datum) AS day,
    EXTRACT(DOW FROM datum) AS weekday, --- (DOW)
    EXTRACT(WEEK FROM datum) AS week_of_year,
    TO_CHAR(datum, 'Day') AS day_name,
    TO_CHAR(datum, 'Month') AS month_name,
    CASE
        WHEN EXTRACT(DOW FROM datum) IN (0, 6) THEN TRUE
        ELSE FALSE
    END AS is_weekend
FROM (
    SELECT DISTINCT sale_date::DATE AS datum
    FROM raw_data
    WHERE sale_date IS NOT NULL
) AS dates
ON CONFLICT (full_date) DO NOTHING;

INSERT INTO dim_supplier (
    supplier_name, supplier_contact_person, supplier_email, supplier_phone,
    supplier_address, city_id, country_id
)
SELECT DISTINCT
    raw.supplier_name,
    raw.supplier_contact,
    raw.supplier_email,
    raw.supplier_phone,
    raw.supplier_address,
    dct.city_id,
    dc.country_id
FROM raw_data raw
LEFT JOIN dim_country dc ON raw.supplier_country = dc.country_name
LEFT JOIN dim_city dct ON raw.supplier_city = dct.city_name
WHERE raw.supplier_name IS NOT NULL OR raw.supplier_email IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO dim_store (
    store_name, store_location, city_id, state_id, country_id,
    store_phone, store_email
)
SELECT DISTINCT
    raw.store_name,
    raw.store_location,
    dct.city_id,
    dst.state_id,
    dc.country_id,
    raw.store_phone,
    raw.store_email
FROM raw_data raw
LEFT JOIN dim_country dc ON raw.store_country = dc.country_name
LEFT JOIN dim_city dct ON raw.store_city = dct.city_name
LEFT JOIN dim_state dst ON raw.store_state = dst.state_name
WHERE raw.store_name IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO dim_seller (
    seller_first_name, seller_last_name, seller_email, country_id, seller_postal_code
)
SELECT DISTINCT
    raw.seller_first_name,
    raw.seller_last_name,
    raw.seller_email,
    dc.country_id,
    raw.seller_postal_code
FROM raw_data raw
LEFT JOIN dim_country dc ON raw.seller_country = dc.country_name
WHERE raw.seller_email IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO dim_customer (
    customer_first_name, customer_last_name, customer_age, customer_email,
    country_id, customer_postal_code
)
SELECT DISTINCT
    raw.customer_first_name,
    raw.customer_last_name,
    raw.customer_age,
    raw.customer_email,
    dc.country_id,
    raw.customer_postal_code
FROM raw_data raw
LEFT JOIN dim_country dc ON raw.customer_country = dc.country_name
WHERE raw.customer_email IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO dim_product (
    product_name, category_id, brand_id, material_id,
    color_id, size_id, product_current_price, product_weight_gr,
    product_description, product_avg_rating, product_reviews_count,
    product_release_date, product_expiry_date, supplier_id
)
SELECT DISTINCT ON (
    raw.product_name, raw.product_brand, raw.product_weight, raw.product_color, raw.product_size, raw.product_material
)
    raw.product_name,
    dpc.category_id,
    db.brand_id,
    dm.material_id,
    dco.color_id,
    dsz.size_id,
    raw.product_price,
    raw.product_weight,
    raw.product_description,
    raw.product_rating,
    raw.product_reviews,
    raw.product_release_date::DATE,
    raw.product_expiry_date::DATE,
    dsup.supplier_id
FROM raw_data raw
LEFT JOIN dim_product_category dpc ON raw.product_category = dpc.category_name
LEFT JOIN dim_brand db ON raw.product_brand = db.brand_name
LEFT JOIN dim_material dm ON raw.product_material = dm.material_name
LEFT JOIN dim_color dco ON raw.product_color = dco.color_name
LEFT JOIN dim_size dsz ON raw.product_size = dsz.size_name
LEFT JOIN dim_supplier dsup ON raw.supplier_name = dsup.supplier_name AND raw.supplier_email = dsup.supplier_email
WHERE raw.product_name IS NOT NULL AND raw.product_brand IS NOT NULL
ON CONFLICT DO NOTHING;

-- Заполняем факты звезды

INSERT INTO fact_sales (
    date_id, customer_id, seller_id, product_id, store_id, supplier_id,
    sale_quantity, sale_total_price, original_raw_id, pet_id
)
SELECT
    dd.date_id,
    dcust.customer_id,
    ds.seller_id,
    dp.product_id,
    dst.store_id,
    dp.supplier_id,
    raw.sale_quantity,
    raw.sale_total_price,
    raw.id,
    dpet.pet_id
    
FROM raw_data raw
LEFT JOIN dim_date dd ON raw.sale_date::DATE = dd.full_date
LEFT JOIN dim_customer dcust ON raw.customer_email = dcust.customer_email
LEFT JOIN dim_seller ds ON raw.seller_email = ds.seller_email
LEFT JOIN dim_country store_country ON raw.store_country = store_country.country_name
LEFT JOIN dim_city store_city ON raw.store_city = store_city.city_name
LEFT JOIN dim_state store_state ON raw.store_state = store_state.state_name
LEFT JOIN dim_store dst ON raw.store_name = dst.store_name
                        AND COALESCE(store_city.city_id, -1) = COALESCE(dst.city_id, -1)
                        AND COALESCE(store_state.state_id, -1) = COALESCE(dst.state_id, -1)
                        AND COALESCE(store_country.country_id, -1) = COALESCE(dst.country_id, -1)
LEFT JOIN dim_product_category dpc ON raw.product_category = dpc.category_name
LEFT JOIN dim_pet_category dpec ON raw.pet_category = dpec.pet_category_name
LEFT JOIN dim_brand db ON raw.product_brand = db.brand_name
LEFT JOIN dim_material dm ON raw.product_material = dm.material_name
LEFT JOIN dim_color dco ON raw.product_color = dco.color_name
LEFT JOIN dim_size dsz ON raw.product_size = dsz.size_name
LEFT JOIN dim_product dp ON raw.product_name = dp.product_name
                         AND COALESCE(dpc.category_id, -1) = COALESCE(dp.category_id, -1)
                         AND COALESCE(db.brand_id, -1) = COALESCE(dp.brand_id, -1)
                         AND COALESCE(dm.material_id, -1) = COALESCE(dp.material_id, -1)
                         AND COALESCE(dco.color_id, -1) = COALESCE(dp.color_id, -1)
                         AND COALESCE(dsz.size_id, -1) = COALESCE(dp.size_id, -1)
                         AND raw.product_weight = dp.product_weight_gr
LEFT JOIN dim_pet_type dpt_join ON raw.customer_pet_type = dpt_join.pet_type_name
LEFT JOIN dim_pet_breed dpb_join ON raw.customer_pet_breed = dpb_join.breed_name
LEFT JOIN dim_pet dpet ON raw.customer_pet_name = dpet.customer_pet_name
                       AND COALESCE(dpt_join.pet_type_id, -1) = COALESCE(dpet.pet_type_id, -1)
                       AND COALESCE(dpb_join.breed_id, -1) = COALESCE(dpet.pet_breed_id, -1)
WHERE
    dd.date_id IS NOT NULL
    AND dcust.customer_id IS NOT NULL
    AND ds.seller_id IS NOT NULL
    AND dp.product_id IS NOT NULL
    AND dst.store_id IS NOT NULL
    AND dp.supplier_id IS NOT NULL;


-- Проверим кол-во записей

SELECT 'dim_product_category', COUNT(*) FROM dim_product_category UNION ALL
SELECT 'dim_pet_category', COUNT(*) FROM dim_pet_category UNION ALL
SELECT 'dim_brand', COUNT(*) FROM dim_brand UNION ALL
SELECT 'dim_material', COUNT(*) FROM dim_material UNION ALL
SELECT 'dim_color', COUNT(*) FROM dim_color UNION ALL
SELECT 'dim_size', COUNT(*) FROM dim_size UNION ALL
SELECT 'dim_country', COUNT(*) FROM dim_country UNION ALL
SELECT 'dim_pet_breed', COUNT(*) FROM dim_pet_breed UNION ALL
SELECT 'dim_pet_type', COUNT(*) FROM dim_pet_type UNION ALL
SELECT 'dim_date', COUNT(*) FROM dim_date UNION ALL
SELECT 'dim_supplier', COUNT(*) FROM dim_supplier UNION ALL
SELECT 'dim_store', COUNT(*) FROM dim_store UNION ALL
SELECT 'dim_seller', COUNT(*) FROM dim_seller UNION ALL
SELECT 'dim_customer', COUNT(*) FROM dim_customer UNION ALL
SELECT 'dim_product', COUNT(*) FROM dim_product UNION ALL
SELECT 'fact_sales', COUNT(*) FROM fact_sales;
