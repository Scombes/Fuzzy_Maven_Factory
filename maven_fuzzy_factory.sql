/*
   Maven Fuzzy Factory Website Data
    
    - Skills used: Temporary Tables, Window Functions, Aggregate Functions, CTE's
    
*/

/*
	Show volume growth.  Pull overall session and order volume,
    trended by quarter for the life of the business.
*/

SELECT 
    YEAR(ws.created_at) AS yr,
    QUARTER(ws.created_at) AS qrtr,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS num_orders,
    COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) AS avg_convr_rate,
    SUM(price_usd) AS revenue,
    SUM(cogs_usd) AS cogs
FROM
    website_sessions ws
        LEFT JOIN
    orders o ON o.website_session_id = ws.website_session_id
GROUP BY 1,2
;

/*
	Show quarterly figures since launch for session-to-order
    conversio rate, revenue per order, and revenue per session.
*/

-- STEP 1: Use website_sessions on a left join with orders
-- STEP 2: Use date functions YEAR and QUARTER to aggregate data on
-- STEP 3: USE COUNT and SUM to get needed data

SELECT 
    YEAR(ws.created_at) AS yr,
    QUARTER(ws.created_at) AS qrtr,
    COUNT(DISTINCT ws.website_session_id) as sessions,
    COUNT(DISTINCT o.order_id) as orders,
    SUM(price_usd) AS total_revenue,
	SUM(o.price_usd) / COUNT(DISTINCT o.order_id) AS revenue_per_order,
	SUM(o.price_usd) / COUNT(DISTINCT ws.website_session_id) AS revenue_per_session
FROM
    website_sessions ws
        LEFT JOIN
    orders o ON o.website_session_id = ws.website_session_id
GROUP BY 1,2
;

/*
	Channel growth.  Quarterly view of orders from
    Gsearch nonbrand, Bsearch nonbrand, brand search overall,
    organic search, and direct type-in.
*/

-- STEP 1: Determin different channels using utm_source, utm_campaign, and http_referer

SELECT DISTINCT utm_source, utm_campaign, http_referer FROM website_sessions;

-- STEP 2: Use website_sessions to get all sessions and label what channel it is with a CASE statement

SELECT
website_session_id,
created_at,
CASE
	WHEN utm_source IS NULL AND http_referer IS NULL THEN 'direct_type_in'
    WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN 'organic_search'
    WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN 'gsearch_nonbrand'
    WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN 'bsearch_nonbrand'
    WHEN utm_campaign = 'brand' THEN 'brand_search'
    WHEN utm_source = 'socialbook' THEN 'social'
    ELSE 'Error'
END AS channel
FROM website_sessions;

-- STEP 3: Use above query as a subquery to get counts for each channel. Left Join Orders to count number of orders.

SELECT 
YEAR(channel_count.created_at) AS yr,
QUARTER(channel_count.created_at) AS qrtr,
channel_count.channel AS channel,
COUNT(DISTINCT channel_count.website_session_id) AS sessions,
COUNT(DISTINCT orders.order_id) AS orders,
IFNULL(SUM(orders.price_usd), 0)  AS total_revenue
FROM
(
SELECT
website_session_id,
created_at,
CASE
	WHEN utm_source IS NULL AND http_referer IS NULL THEN 'direct_type_in'
    WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN 'organic_search'
    WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN 'gsearch_nonbrand'
    WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN 'bsearch_nonbrand'
    WHEN utm_campaign = 'brand' THEN 'brand_search'
    WHEN utm_source = 'socialbook' THEN 'social'
    ELSE 'Error'
END AS channel
FROM website_sessions) AS channel_count
LEFT JOIN ORDERS ON ORDERS.website_session_id = channel_count.website_session_id
GROUP BY 1,2,3
;

/*
	Pull monthly trending for revenue and margin by product, along with
    sales and revenue. 
*/

-- Use the orders and order_items tables
-- Need Year, Month, Product ID as GROUP BY
-- Count of each product sold
-- SUM price_usd for each product sold as total_revenue
-- SUM price_usd minus cogs_usd AS margin
-- AVG price_usd as AVG revenue generated per order

SELECT 
    YEAR(created_at) AS yr,
    MONTH(created_at) AS mo,
    product_id,
    COUNT(product_id) AS num_sold,
    SUM(price_usd) AS total_revenue,
    SUM(price_usd - cogs_usd) AS margin,
    AVG(price_usd) AS aov
FROM
    order_items
GROUP BY 1 , 2 , 3
ORDER BY 1, 2, 3
;

/*
	Monthly sessions to the /products page and how
    the % of those sessions clicking through another page has changed
    over time, along with a view of how conversion from /products to placing
    an order has improved
*/

-- Step 1: Pull all website_pageview_id, website_session_id and created_at of sessions landing on /products page.
-- Step 2:  Use that as a subquery and join that data back onto website_pageviews table on website_session_id and where wesite_pageview is greater than the subquery pageview.  This way we only get the next pages.
-- Step 3: Create a temporary table to do the analysis from.

DROP TABLE IF EXISTS product_next_page_sessions;
CREATE TEMPORARY TABLE product_next_page_sessions
SELECT
product_page_sessions.first_pageview_id,
product_page_sessions.created_at,
product_page_sessions.website_session_id,
MIN(website_pageviews.created_at) AS second_created_at, -- Gives us the next created_at only if it exists
MIN(website_pageviews.website_pageview_id) AS next_pageview_id -- Gives us the next page only if it exists
FROM
(SELECT 
    website_pageview_id AS first_pageview_id,
    created_at,
    website_session_id
FROM
    website_pageviews
WHERE
    pageview_url = '/products') AS product_page_sessions 
LEFT JOIN website_pageviews ON website_pageviews.website_session_id = product_page_sessions.website_session_id
AND website_pageviews.website_pageview_id > product_page_sessions.first_pageview_id
GROUP BY 1
;

-- Step 4: USE COUNT function to get number of product page sessions, Use Count and Case statement to find the number of click throughs to another page. Divide number of clickthroughs by total sessions to get clickthrough rate.

SELECT
YEAR(created_at) as yr,
MONTH(created_at) as mo,
COUNT(DISTINCT first_pageview_id) AS product_pg_sessions,
COUNT(DISTINCT CASE WHEN next_pageview_id IS NOT NULL THEN website_session_id ELSE NULL END) AS click_throughs,
COUNT(DISTINCT CASE WHEN next_pageview_id IS NOT NULL THEN website_session_id ELSE NULL END) / COUNT(DISTINCT first_pageview_id) AS pct_click_throughs
FROM product_next_page_sessions
GROUP BY 1,2
;

/* Order Conversons from Product Page */

SELECT 
YEAR(product_next_page_sessions.created_at) as yr,
MONTH(product_next_page_sessions.created_at) as mo,
COUNT(DISTINCT product_next_page_sessions.first_pageview_id) AS product_pg_sessions,
COUNT(DISTINCT orders.order_id) AS num_orders,
COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT product_next_page_sessions.first_pageview_id) AS pct_that_ordered
FROM product_next_page_sessions
LEFT JOIN orders ON orders.website_session_id = product_next_page_sessions.website_session_id 
GROUP BY 1, 2
;

/*
	Cross Sale data from December 05, 2014.
*/

SELECT 
orders.primary_product_id,
COUNT(DISTINCT orders.order_id) AS orders,
COUNT(DISTINCT CASE WHEN order_items.product_id = 1 THEN orders.order_id ELSE NULL END) AS x_sell_prod1,
COUNT(DISTINCT CASE WHEN order_items.product_id = 2 THEN orders.order_id ELSE NULL END) AS x_sell_prod2,
COUNT(DISTINCT CASE WHEN order_items.product_id = 3 THEN orders.order_id ELSE NULL END) AS x_sell_prod3,
COUNT(DISTINCT CASE WHEN order_items.product_id = 4 THEN orders.order_id ELSE NULL END) AS x_sell_prod4
FROM orders
LEFt JOIN order_items
ON order_items.order_id = orders.order_id
AND order_items.is_primary_item = 0 -- cross sell only
WHERE orders.created_at > '2014-12-05'
GROUP BY 1
;

/*
For the gsearch lander test, please estimate the revenue that test earned us 
 Look at the increase in CVR from the test (Jun 19 – Jul 28), and use 
nonbrand sessions and revenue since then to calculate incremental value
*/ 

SELECT
	MIN(website_pageview_id) AS first_test_pv
FROM website_pageviews
WHERE pageview_url = '/lander-1';

-- for this step, we'll find the first pageview id 

CREATE TEMPORARY TABLE first_test_pageviews
SELECT
	website_pageviews.website_session_id, 
    MIN(website_pageviews.website_pageview_id) AS min_pageview_id
FROM website_pageviews 
	INNER JOIN website_sessions 
		ON website_sessions.website_session_id = website_pageviews.website_session_id
		AND website_sessions.created_at < '2012-07-28' -- prescribed by the assignment
		AND website_pageviews.website_pageview_id >= 23504 -- first page_view
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
GROUP BY 
	website_pageviews.website_session_id;

-- next, we'll bring in the landing page to each session, like last time, but restricting to home or lander-1 this time

CREATE TEMPORARY TABLE nonbrand_test_sessions_w_landing_pages
SELECT 
	first_test_pageviews.website_session_id, 
    website_pageviews.pageview_url AS landing_page
FROM first_test_pageviews
	LEFT JOIN website_pageviews 
		ON website_pageviews.website_pageview_id = first_test_pageviews.min_pageview_id
WHERE website_pageviews.pageview_url IN ('/home','/lander-1'); 

-- SELECT * FROM nonbrand_test_sessions_w_landing_pages;

-- then we make a table to bring in orders

CREATE TEMPORARY TABLE nonbrand_test_sessions_w_orders
SELECT
	nonbrand_test_sessions_w_landing_pages.website_session_id, 
    nonbrand_test_sessions_w_landing_pages.landing_page, 
    orders.order_id AS order_id

FROM nonbrand_test_sessions_w_landing_pages
LEFT JOIN orders 
	ON orders.website_session_id = nonbrand_test_sessions_w_landing_pages.website_session_id
;

SELECT * FROM nonbrand_test_sessions_w_orders;

-- to find the difference between conversion rates 
SELECT
	landing_page, 
    COUNT(DISTINCT website_session_id) AS sessions, 
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT order_id)/COUNT(DISTINCT website_session_id) AS conv_rate
FROM nonbrand_test_sessions_w_orders
GROUP BY 1; 

-- .0319 for /home, vs .0406 for /lander-1 
-- .0087 additional orders per session

-- finding the most reent pageview for gsearch nonbrand where the traffic was sent to /home
SELECT 
	MAX(website_sessions.website_session_id) AS most_recent_gsearch_nonbrand_home_pageview 
FROM website_sessions 
	LEFT JOIN website_pageviews 
		ON website_pageviews.website_session_id = website_sessions.website_session_id
WHERE utm_source = 'gsearch'
	AND utm_campaign = 'nonbrand'
    AND pageview_url = '/home'
    AND website_sessions.created_at < '2012-11-27'
;
-- max website_session_id = 17145


SELECT 
	COUNT(website_session_id) AS sessions_since_test
FROM website_sessions
WHERE created_at < '2012-11-27'
	AND website_session_id > 17145 -- last /home session
	AND utm_source = 'gsearch'
	AND utm_campaign = 'nonbrand'
;
-- 22,972 website sessions since the test

-- X .0087 incremental conversion = 202 incremental orders since 7/29
-- roughly 4 months, so roughly 50 extra orders per month. 
