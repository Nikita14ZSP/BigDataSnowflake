INSERT INTO dim_customer (customer_id, first_name, last_name, age, email, country, postal_code)
SELECT
  sale_customer_id,
  customer_first_name,
  customer_last_name,
  customer_age,
  customer_email,
  customer_country,
  customer_postal_code
FROM (
  SELECT
    sale_customer_id,
    customer_first_name,
    customer_last_name,
    customer_age,
    customer_email,
    customer_country,
    customer_postal_code,
    ROW_NUMBER() OVER (PARTITION BY sale_customer_id ORDER BY sale_date) AS row_number
  FROM mock_data
) t
WHERE t.row_number = 1
ON CONFLICT (customer_id) DO NOTHING;


INSERT INTO dim_seller (seller_id,first_name,last_name,email,country,postal_code)
SELECT
  sale_seller_id AS seller_id,
  seller_first_name AS first_name,
  seller_last_name AS last_name,
  seller_email AS email,
  seller_country AS country,
  seller_postal_code AS postal_code
FROM (
  SELECT
    sale_seller_id,
    seller_first_name,
    seller_last_name,
    seller_email,
    seller_country,
    seller_postal_code,
    ROW_NUMBER() OVER (PARTITION BY sale_seller_idORDER BY sale_date) AS row_number
  FROM mock_data
) t
WHERE t.row_number = 1
  AND sale_seller_id IS NOT NULL
ON CONFLICT (seller_id) DO NOTHING;


INSERT INTO dim_supplier (name,contact,email,phone,address,city,country)
SELECT
  supplier_name AS name,
  supplier_contact AS contact,
  supplier_email AS email,
  supplier_phone AS phone,
  supplier_address AS address,
  supplier_city AS city,
  supplier_country AS country
FROM (
  SELECT
    supplier_name,
    supplier_contact,
    supplier_email,
    supplier_phone,
    supplier_address,
    supplier_city,
    supplier_country,
    ROW_NUMBER() OVER (PARTITION BY supplier_nameORDER BY sale_date) AS row_number
  FROM mock_data
) t
WHERE 1=1
	AND t.row_number = 1
  	AND supplier_name IS NOT NULL
ON CONFLICT (name) DO NOTHING;


INSERT INTO dim_date (sale_date, year, quarter, month, day, weekday)
SELECT DISTINCT
  sale_date,
  EXTRACT(YEAR FROM sale_date)::INT AS year,
  EXTRACT(QUARTER FROM sale_date)::INT AS quarter,
  EXTRACT(MONTH FROM sale_date)::INT AS month,
  EXTRACT(DAY FROM sale_date)::INT AS day,
  EXTRACT(DOW FROM sale_date)::INT AS weekday
FROM 
	mock_data
where sale_date IS NOT NULL
ON CONFLICT (sale_date) DO NOTHING;


INSERT INTO dim_product (product_id,name,category,weight,color,size,brand,material,description,rating,reviews,release_date,expiry_date,unit_price)
SELECT
  sale_product_id AS product_id,
  product_name AS name,
  product_category AS category,
  product_weight AS weight,
  product_color AS color,
  product_size AS size,
  product_brand AS brand,
  product_material AS material,
  product_description AS description,
  product_rating AS rating,
  product_reviews AS reviews,
  product_release_date AS release_date,
  product_expiry_date AS expiry_date,
  product_price AS unit_price
FROM (
  SELECT
    sale_product_id,
    product_name,
    product_category,
    product_weight,
    product_color,
    product_size,
    product_brand,
    product_material,
    product_description,
    product_rating,
    product_reviews,
    product_release_date,
    product_expiry_date,
    product_price,
    ROW_NUMBER() OVER (PARTITION BY sale_product_id ORDER BY sale_date) AS row_number
  FROM mock_data
) t
WHERE t.row_number = 1
  AND sale_product_id IS NOT NULL
ON CONFLICT (product_id) DO NOTHING;


INSERT INTO dim_store (name,location,city,state,country,phone,email)
SELECT
  store_name AS name,
  store_location AS location,
  store_city AS city,
  store_state AS state,
  store_country AS country,
  store_phone AS phone,
  store_email AS email
FROM (
  SELECT
    store_name,
    store_location,
    store_city,
    store_state,
    store_country,
    store_phone,
    store_email,
    ROW_NUMBER() OVER (PARTITION BY store_name ORDER BY sale_date) AS row_number
  FROM mock_data
) t
WHERE 1=1
	AND t.row_number = 1
  	AND store_name IS NOT NULL
ON CONFLICT (name) DO NOTHING;


INSERT INTO fact_sales (date_sk,customer_sk,seller_sk,product_sk,store_sk,supplier_sk,sale_quantity,sale_total_price,unit_price)
SELECT
  d.date_sk,
  c.customer_sk,
  s.seller_sk,
  p.product_sk,
  st.store_sk,
  sup.supplier_sk,
  md.sale_quantity,
  md.sale_total_price,
  md.product_price
FROM 
	mock_data md
JOIN dim_date d   
	ON md.sale_date = d.sale_date
JOIN dim_customer c
	ON md.sale_customer_id = c.customer_id
JOIN dim_seller s
	ON md.sale_seller_id = s.seller_id
JOIN dim_product p
	ON md.sale_product_id = p.product_id
JOIN dim_store st  
	ON md.store_name = st.name
JOIN dim_supplier sup 
	ON md.supplier_name = sup.name

WHERE 1=1
	AND md.sale_customer_id IS NOT null
	AND md.sale_seller_id IS NOT null
	AND md.sale_product_id  IS NOT NULL;
