-- PROJECT NAME - MARKETPLACE REVENUE LEAKAGE, CUSTOMER ECONOMICS & COMMERCIAL DECISION-MAKING CASE STUDY 1 --

CREATE DATABASE case_study_1;

USE case_study_1;

SHOW TABLES;

SELECT *
FROM marketplace_transactions
LIMIT 10;

-- *) COUNT TOTAL ROWS IN THE TABLE

SELECT COUNT(*) AS TOTAL_ROWS
FROM marketplace_transactions;

-- *) DATE RANGE: OLDEST AND NEWEST DATES IN ORDER_TIMESTAMP

SELECT MIN(ORDER_TIMESTAMP) AS OLDEST_DATE,
       MAX(ORDER_TIMESTAMP) AS NEWEST_DATE
FROM marketplace_transactions;

-- *) DISTINCT VALUES AND COUNTS FOR ORDER_STATUS, PRODUCT_CATEGORY,  ACQUISITION_CHANNEL AND CUSTOMER_SEGMENT

SELECT 'ORDER_STATUS' AS COL, ORDER_STATUS AS COL_VALUE, COUNT(*) AS CNT
FROM marketplace_transactions 
GROUP BY ORDER_STATUS

UNION ALL

SELECT 'PRODUCT_CATEGORY', PRODUCT_CATEGORY, COUNT(*)
FROM marketplace_transactions GROUP BY PRODUCT_CATEGORY

UNION ALL

SELECT 'ACQUISITION_CHANNEL', ACQUISITION_CHANNEL, COUNT(*)
FROM marketplace_transactions GROUP BY ACQUISITION_CHANNEL

UNION ALL

SELECT 'CUSTOMER_SEGMENT', CUSTOMER_SEGMENT, COUNT(*)
FROM marketplace_transactions GROUP BY CUSTOMER_SEGMENT
ORDER BY COL, CNT DESC;

-- *) DUPLICATE TRANSACTION_ID CHECK

SELECT TRANSACTION_ID, COUNT(*)
FROM marketplace_transactions
GROUP BY TRANSACTION_ID
HAVING COUNT(*) > 1;

-- *) NULL CHECKS

SELECT
  SUM(DISCOUNT_AMOUNT IS NULL) AS NULL_DISCOUNT,
  SUM(REFUND_AMOUNT IS NULL)   AS NULL_REFUND,
  SUM(PAYMENT_FEE IS NULL)     AS NULL_FEE,
  SUM(FULFILMENT_COST IS NULL) AS NULL_FULFIL
FROM marketplace_transactions;

-- *) STATUS WISE REFUND

SELECT ORDER_STATUS, COUNT(*) AS LINE_COUNT, SUM(REFUND_AMOUNT) AS TOTAL_REFUND
FROM marketplace_transactions
GROUP BY ORDER_STATUS;


-- ******* QUESTION NO ONE *******

-- ****************************************************************************************************************************
-- 1) RECONSTRUCT THE COMMERCIAL PERFORMANCE BRIDGE

-- CALCULATE MONTHLY GMV, DELIVERED GMV, CANCELLED GMV, RETURNED GMV, DISCOUNTS, REFUNDS,
-- SELLER COMMISSION, PAYMENT FEES, FULFILMENT COSTS, AND CONTRIBUTION PROXY.
-- COMPARE MONTH-OVER-MONTH GROWTH IN ORDER COUNT, GMV, DELIVERED GMV, AND CONTRIBUTION PROXY.
-- IDENTIFY MONTHS WITH POSITIVE GMV GROWTH BUT NEGATIVE CONTRIBUTION GROWTH.
-- **********************************************************************************************************************************


-- GMV FORMULA = (QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT
-- CONTRIBUTION FORMULA = GMV - REFUND_AMOUNT - PAYMENT_FEE - FULFILMENT_COST
-- SELLER COMMISSION FORMULA = ((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT) * SELLER_COMMISSION_RATE

-- CALCULATES THE GMV OF ALL ROWS

SELECT
    TRANSACTION_ID,
    QUANTITY,
    UNIT_SELLING_PRICE,
    DISCOUNT_AMOUNT,
    (QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT AS GMV
FROM marketplace_transactions
LIMIT 10;

-- CALCULATE THE MONTHLY GMV

SELECT
    DATE_FORMAT(ORDER_TIMESTAMP, '%Y-%m-01') AS MONTH,
    COUNT(*) AS LINE_COUNT,
    SUM((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT) AS GMV
FROM marketplace_transactions
GROUP BY MONTH
ORDER BY MONTH DESC;

-- REAL QUESTION ANSWER QUERY

WITH MONTHLY AS (
    SELECT
        DATE_FORMAT(ORDER_TIMESTAMP, '%Y-%m-01') AS MONTH,
        COUNT(*) AS LINE_COUNT,
        COUNT(DISTINCT ORDER_ID) AS ORDER_COUNT,
        ROUND(
            SUM(CASE WHEN ORDER_STATUS = 'Delivered'
                     THEN ((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT) * SELLER_COMMISSION_RATE
                     ELSE 0 END), 2) AS SELLER_COMMISSION,
        SUM((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT) AS GMV,
        SUM(CASE WHEN ORDER_STATUS = 'Delivered'
                 THEN (QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT
                 ELSE 0 END) AS DELIVERED_GMV,
        SUM(CASE WHEN ORDER_STATUS = 'Cancelled'
                 THEN (QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT
                 ELSE 0 END) AS CANCELLED_GMV,
        SUM(CASE WHEN ORDER_STATUS = 'Returned'
                 THEN (QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT
                 ELSE 0 END) AS RETURNED_GMV,
        SUM(CASE WHEN ORDER_STATUS = 'Delivered'
                 THEN (QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT
                      - REFUND_AMOUNT - PAYMENT_FEE - FULFILMENT_COST
                 ELSE 0 END) AS CONTRIBUTION_PROXY,
        SUM(DISCOUNT_AMOUNT) AS DISCOUNTS,
        SUM(REFUND_AMOUNT) AS REFUNDS,
        SUM(PAYMENT_FEE) AS PAYMENT_FEES,
        SUM(FULFILMENT_COST) AS FULFILMENT_COSTS
    FROM marketplace_transactions
    GROUP BY MONTH
),
GROWTH AS (
    SELECT
        MONTH,
        DELIVERED_GMV,
        CANCELLED_GMV,
        RETURNED_GMV,
        DISCOUNTS,
        REFUNDS,
        SELLER_COMMISSION,
        PAYMENT_FEES,
        FULFILMENT_COSTS,
        CONTRIBUTION_PROXY,
        GMV,
        ORDER_COUNT,
        LAG(GMV) OVER (ORDER BY MONTH) AS PREV_GMV,
        ROUND(
            (GMV - LAG(GMV) OVER (ORDER BY MONTH))
                / LAG(GMV) OVER (ORDER BY MONTH) * 100, 2) AS GMV_GROWTH_PCT,
        LAG(ORDER_COUNT) OVER (ORDER BY MONTH) AS PREV_ORDER_COUNT,
        ROUND(
            (ORDER_COUNT - LAG(ORDER_COUNT) OVER (ORDER BY MONTH)) * 100.0
                / LAG(ORDER_COUNT) OVER (ORDER BY MONTH), 2) AS ORDER_GROWTH_PCT,
        LAG(DELIVERED_GMV) OVER (ORDER BY MONTH) AS PREV_DELIVERED_GMV,
        ROUND(
            (DELIVERED_GMV - LAG(DELIVERED_GMV) OVER (ORDER BY MONTH))
                / LAG(DELIVERED_GMV) OVER (ORDER BY MONTH) * 100, 2) AS DELIVERED_GMV_GROWTH_PCT,
        LAG(CONTRIBUTION_PROXY) OVER (ORDER BY MONTH) AS PREV_CONTRIBUTION_PROXY,
        ROUND(
            (CONTRIBUTION_PROXY - LAG(CONTRIBUTION_PROXY) OVER (ORDER BY MONTH))
                / LAG(CONTRIBUTION_PROXY) OVER (ORDER BY MONTH) * 100, 2) AS CONTRIBUTION_GROWTH_PCT
    FROM MONTHLY
)
SELECT
    MONTH,
    ORDER_COUNT,
    GMV,
    DELIVERED_GMV,
    CANCELLED_GMV,
    RETURNED_GMV,
    DISCOUNTS,
    REFUNDS,
    SELLER_COMMISSION,
    PAYMENT_FEES,
    FULFILMENT_COSTS,
    CONTRIBUTION_PROXY,
    ORDER_GROWTH_PCT,
    GMV_GROWTH_PCT,
    DELIVERED_GMV_GROWTH_PCT,
    CONTRIBUTION_GROWTH_PCT,
    CASE WHEN GMV_GROWTH_PCT > 0 AND CONTRIBUTION_GROWTH_PCT < 0
         THEN 'Yes' ELSE 'No' END AS GMV_UP_CONTRIBUTION_DOWN
FROM GROWTH
ORDER BY MONTH;

-- ********* QUESTION NO TWO ************

-- **********************************************************************************************************************
-- 2) CUSTOMER CONCENTRATION AND ECONOMIC DEPENDENCY

-- CALCULATE THE SHARE OF DELIVERED GMV AND CONTRIBUTION PROXY GENERATED BY THE TOP 1%, 5%, AND 10% OF
-- CUSTOMERS. CALCULATE REPEAT-PURCHASE PARTICIPATION AND IDENTIFY CUSTOMERS WHOSE DELIVERED GMV IS ABOVE THE
-- 90TH PERCENTILE BUT WHOSE CONTRIBUTION PROXY IS NEGATIVE. DETERMINE WHETHER THE LARGEST CUSTOMERS ARE ALSO
-- THE MOST PROFITABLE.
-- ****************************************************************************************************************

-- FORMULA OF DELIVERED GMV -  SUM((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT)
-- FORMULA OF CONTRIBUTION PROXY - SUM((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT
--         - REFUND_AMOUNT - PAYMENT_FEE - FULFILMENT_COST) AS CONTRIBUTION_PROXY.

--  CUSTOMER CONCENTRATION (TOP 1%, 5%, 10%)

WITH CUSTOMER_TOTALS AS (
    SELECT CUSTOMER_ID,
           SUM((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT) AS DELIVERED_GMV,
           SUM((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT
               - REFUND_AMOUNT - PAYMENT_FEE - FULFILMENT_COST) AS CONTRIBUTION_PROXY,
           COUNT(DISTINCT ORDER_ID) AS DELIVERED_ORDER_COUNT
    FROM marketplace_transactions
    WHERE ORDER_STATUS = 'Delivered'
    GROUP BY CUSTOMER_ID
),
RANKED AS (
    SELECT *,
           NTILE(100) OVER (ORDER BY DELIVERED_GMV DESC) AS PCT_BUCKET
    FROM CUSTOMER_TOTALS
)
SELECT 'Top 1%' AS CONCENTRATION_BAND,
       COUNT(*) AS CUSTOMER_COUNT,
       SUM(DELIVERED_GMV) AS DELIVERED_GMV,
       SUM(CONTRIBUTION_PROXY) AS CONTRIBUTION_PROXY,
       ROUND(100 * SUM(DELIVERED_GMV)
             / (SELECT SUM(DELIVERED_GMV) FROM CUSTOMER_TOTALS), 2) AS SHARE_OF_TOTAL_GMV_PCT,
       ROUND(100 * SUM(CONTRIBUTION_PROXY)
             / (SELECT SUM(CONTRIBUTION_PROXY) FROM CUSTOMER_TOTALS), 2) AS SHARE_OF_TOTAL_CONTRIBUTION_PCT
FROM RANKED
WHERE PCT_BUCKET <= 1

UNION ALL

SELECT 'Top 5%' AS CONCENTRATION_BAND,
       COUNT(*) AS CUSTOMER_COUNT,
       SUM(DELIVERED_GMV) AS DELIVERED_GMV,
       SUM(CONTRIBUTION_PROXY) AS CONTRIBUTION_PROXY,
       ROUND(100 * SUM(DELIVERED_GMV)
             / (SELECT SUM(DELIVERED_GMV) FROM CUSTOMER_TOTALS), 2) AS SHARE_OF_TOTAL_GMV_PCT,
       ROUND(100 * SUM(CONTRIBUTION_PROXY)
             / (SELECT SUM(CONTRIBUTION_PROXY) FROM CUSTOMER_TOTALS), 2) AS SHARE_OF_TOTAL_CONTRIBUTION_PCT
FROM RANKED
WHERE PCT_BUCKET <= 5

UNION ALL

SELECT 'Top 10%' AS CONCENTRATION_BAND,
       COUNT(*) AS CUSTOMER_COUNT,
       SUM(DELIVERED_GMV) AS DELIVERED_GMV,
       SUM(CONTRIBUTION_PROXY) AS CONTRIBUTION_PROXY,
       ROUND(100 * SUM(DELIVERED_GMV)
             / (SELECT SUM(DELIVERED_GMV) FROM CUSTOMER_TOTALS), 2) AS SHARE_OF_TOTAL_GMV_PCT,
       ROUND(100 * SUM(CONTRIBUTION_PROXY)
             / (SELECT SUM(CONTRIBUTION_PROXY) FROM CUSTOMER_TOTALS), 2) AS SHARE_OF_TOTAL_CONTRIBUTION_PCT
FROM RANKED
WHERE PCT_BUCKET <= 10;


--  REPEAT-PURCHASE PARTICIPATION

WITH CUSTOMER_ORDERS AS (
    SELECT CUSTOMER_ID,
           COUNT(DISTINCT ORDER_ID) AS DELIVERED_ORDER_COUNT
    FROM marketplace_transactions
    WHERE ORDER_STATUS = 'Delivered'
    GROUP BY CUSTOMER_ID
)
SELECT COUNT(*) AS CUSTOMERS_WITH_1_PLUS_ORDERS,
       SUM(CASE WHEN DELIVERED_ORDER_COUNT >= 2 THEN 1 ELSE 0 END) AS CUSTOMERS_WITH_2_PLUS_ORDERS,
       ROUND(100.0 * SUM(CASE WHEN DELIVERED_ORDER_COUNT >= 2 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0), 2) AS REPEAT_PURCHASE_RATE_PCT
FROM CUSTOMER_ORDERS;

--  BIG CUSTOMERS (ABOVE 90TH PERCENTILE) WITH NEGATIVE CONTRIBUTION

WITH CUSTOMER_TOTALS AS (
    SELECT CUSTOMER_ID,
           SUM((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT) AS DELIVERED_GMV,
           SUM((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT
               - REFUND_AMOUNT - PAYMENT_FEE - FULFILMENT_COST) AS CONTRIBUTION_PROXY,
           COUNT(DISTINCT ORDER_ID) AS DELIVERED_ORDER_COUNT
    FROM marketplace_transactions
    WHERE ORDER_STATUS = 'Delivered'
    GROUP BY CUSTOMER_ID
),
PCT AS (
    SELECT *,
           PERCENT_RANK() OVER (ORDER BY DELIVERED_GMV) AS GMV_PERCENTILE
    FROM CUSTOMER_TOTALS
)
SELECT CUSTOMER_ID,
		DELIVERED_GMV,
        CONTRIBUTION_PROXY, 
        DELIVERED_ORDER_COUNT,
       ROUND(GMV_PERCENTILE, 2) AS GMV_PERCENTILE,
       CASE WHEN CONTRIBUTION_PROXY < 0 THEN 'Yes' ELSE 'No' END AS NEGATIVE_CONTRIBUTION
FROM PCT
WHERE GMV_PERCENTILE > 0.90
  AND CONTRIBUTION_PROXY < 0
ORDER BY DELIVERED_GMV DESC;

-- ********* 	QUESTION NO THREE ********* ---

-- ********************************************************************************************************************************
 /* 3) Discount dependency and commercial quality
 
Calculate discount rates by product category and acquisition channel. Identify categories where higher
discount rates coincide with lower contribution per delivered order. Compare customer segments by average
order value, repeat-purchase frequency, discount dependency, refund burden, and contribution proxy. Identify
high-value transactions with weak post-discount economics. */ 
-- **************************************************************************************************************************************

-- DISCOUNT RATE BY PRODUCT CATEGORY

SELECT PRODUCT_CATEGORY,
       ROUND(100 * SUM(DISCOUNT_AMOUNT) 
		/ SUM(QUANTITY * UNIT_LIST_PRICE), 2) 
			AS DISCOUNT_RATE_PCT
FROM marketplace_transactions
GROUP BY PRODUCT_CATEGORY
ORDER BY DISCOUNT_RATE_PCT DESC;

--  DISCOUNT RATE BY ACQUISITION CHANNEL

SELECT ACQUISITION_CHANNEL,
       ROUND(100 * SUM(DISCOUNT_AMOUNT) 
		/ SUM(QUANTITY * UNIT_LIST_PRICE), 2)
			AS DISCOUNT_RATE_PCT
FROM marketplace_transactions
GROUP BY ACQUISITION_CHANNEL
ORDER BY DISCOUNT_RATE_PCT DESC;

--  CATEGORY COMMERCIAL QUALITY

WITH CAT AS (
    SELECT PRODUCT_CATEGORY,
           100 * SUM(DISCOUNT_AMOUNT) 
			/ NULLIF(SUM(QUANTITY * UNIT_LIST_PRICE), 0) 
				AS DISCOUNT_RATE_PCT,
           100 * SUM(REFUND_AMOUNT) 
			/ NULLIF(SUM((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT), 0) 
				AS REFUND_RATE_PCT,
           COUNT(DISTINCT CASE WHEN ORDER_STATUS = 'Delivered' THEN ORDER_ID END) AS DELIVERED_ORDERS,
           SUM(CASE WHEN ORDER_STATUS = 'Delivered'
                    THEN (QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT
                         - REFUND_AMOUNT - PAYMENT_FEE - FULFILMENT_COST
                    ELSE 0 END) AS DELIVERED_CONTRIBUTION
    FROM marketplace_transactions
    GROUP BY PRODUCT_CATEGORY
),

SCORED AS (
    SELECT *,
           DELIVERED_CONTRIBUTION / NULLIF(DELIVERED_ORDERS, 0) AS CONTRIBUTION_PER_ORDER
    FROM CAT
)
SELECT PRODUCT_CATEGORY,
       ROUND(DISCOUNT_RATE_PCT, 2) AS DISCOUNT_RATE_PCT,
       ROUND(CONTRIBUTION_PER_ORDER, 2) AS CONTRIBUTION_PER_ORDER,
       ROUND(REFUND_RATE_PCT, 2) AS REFUND_RATE_PCT,
       CASE WHEN DISCOUNT_RATE_PCT > AVG(DISCOUNT_RATE_PCT) OVER ()
                 AND CONTRIBUTION_PER_ORDER < AVG(CONTRIBUTION_PER_ORDER) OVER () THEN 'High'
            WHEN DISCOUNT_RATE_PCT <= AVG(DISCOUNT_RATE_PCT) OVER ()
                 AND CONTRIBUTION_PER_ORDER >= AVG(CONTRIBUTION_PER_ORDER) OVER () THEN 'Low'
            ELSE 'Medium' END AS COMMERCIAL_RISK,
       ROUND(0.10 * DELIVERED_CONTRIBUTION, 2) AS CONTRIBUTION_EXPOSED_TO_10PCT_GMV_DROP,
       RANK() OVER (ORDER BY DELIVERED_CONTRIBUTION DESC) AS EXPOSURE_RANK
FROM SCORED
ORDER BY EXPOSURE_RANK;

--  CUSTOMER SEGMENT COMPARISON

SELECT
	CUSTOMER_SEGMENT,
       COUNT(DISTINCT CASE WHEN ORDER_STATUS = 'Delivered' THEN CUSTOMER_ID END) AS DELIVERED_CUSTOMERS,
       COUNT(DISTINCT CASE WHEN ORDER_STATUS = 'Delivered' THEN ORDER_ID END) AS DELIVERED_ORDERS,
       ROUND(SUM(CASE WHEN ORDER_STATUS = 'Delivered'
                      THEN (QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT ELSE 0 END)
             / NULLIF(COUNT(DISTINCT CASE WHEN ORDER_STATUS = 'Delivered' THEN ORDER_ID END), 0), 2) AS AVG_ORDER_VALUE,
       ROUND(COUNT(DISTINCT CASE WHEN ORDER_STATUS = 'Delivered' THEN ORDER_ID END)
             / NULLIF(COUNT(DISTINCT CASE WHEN ORDER_STATUS = 'Delivered' THEN CUSTOMER_ID END), 0), 2) AS ORDERS_PER_CUSTOMER,
       ROUND(100 * SUM(DISCOUNT_AMOUNT) / NULLIF(SUM(QUANTITY * UNIT_LIST_PRICE), 0), 2) AS DISCOUNT_DEPENDENCY_PCT,
       ROUND(100 * SUM(REFUND_AMOUNT)
             / NULLIF(SUM((QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT), 0), 2) AS REFUND_BURDEN_PCT,
       ROUND(SUM(CASE WHEN ORDER_STATUS = 'Delivered'
                      THEN (QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT
                           - REFUND_AMOUNT - PAYMENT_FEE - FULFILMENT_COST
                      ELSE 0 END), 2) AS CONTRIBUTION_PROXY
FROM marketplace_transactions
GROUP BY CUSTOMER_SEGMENT
ORDER BY CONTRIBUTION_PROXY DESC;

--  HIGH-VALUE TRANSACTIONS WITH WEAK POST-DISCOUNT ECONOMICS

WITH LINES_COUNT AS (
    SELECT TRANSACTION_ID, ORDER_STATUS, PRODUCT_CATEGORY,
           (QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT AS LINE_GMV,
           100 * DISCOUNT_AMOUNT / NULLIF(QUANTITY * UNIT_LIST_PRICE, 0) AS DISCOUNT_RATE_PCT,
           REFUND_AMOUNT,
           (QUANTITY * UNIT_SELLING_PRICE) - DISCOUNT_AMOUNT
               - REFUND_AMOUNT - PAYMENT_FEE - FULFILMENT_COST AS LINE_CONTRIBUTION
    FROM marketplace_transactions
    WHERE ORDER_STATUS IN ('Delivered', 'Returned')
),

PCT AS (
    SELECT *,
           PERCENT_RANK() OVER (ORDER BY LINE_GMV) AS GMV_PERCENTILE
    FROM LINES_COUNT
)
SELECT TRANSACTION_ID, ORDER_STATUS, PRODUCT_CATEGORY,
       ROUND(LINE_GMV, 2) AS LINE_GMV,
       ROUND(DISCOUNT_RATE_PCT, 2) AS DISCOUNT_RATE_PCT,
       REFUND_AMOUNT,
       ROUND(LINE_CONTRIBUTION, 2) AS LINE_CONTRIBUTION,
       ROUND(100 * LINE_CONTRIBUTION / NULLIF(LINE_GMV, 0), 2) AS CONTRIBUTION_MARGIN_PCT
FROM PCT
WHERE GMV_PERCENTILE > 0.90
  AND LINE_CONTRIBUTION < 0.5 * LINE_GMV
ORDER BY CONTRIBUTION_MARGIN_PCT;

-- *********** QUESTION NO FOUR ************ ------- 

-- ********************************************************************************************************************************
/* 4)  Acquisition cohort quality

Build acquisition-month cohorts. Compare first-purchase contribution, 90-day cumulative contribution, and
repeat-purchase rate by acquisition channel. Identify cohorts where first-purchase economics are positive but
90-day economics deteriorate, and flag incomplete 90-day windows.*/
-- *********************************************************************************************************************************

--  Acquisition Cohort Analysis

SELECT
    DATE_FORMAT(
        STR_TO_DATE(customer_acquisition_date, '%Y-%m-%d'),
        '%Y-%m') AS acquisition_month,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT CASE
        WHEN order_status = 'Delivered' THEN order_id END) AS delivered_orders,

    ROUND(SUM(
        CASE WHEN order_status = 'Delivered'
        THEN quantity * unit_selling_price - discount_amount
        ELSE 0 END), 2) AS delivered_gmv,

    ROUND(SUM(
        CASE WHEN order_status = 'Delivered'
        THEN (quantity * unit_selling_price - discount_amount)
             - refund_amount - payment_fee - fulfilment_cost
        ELSE 0 END), 2) AS contribution_proxy
FROM marketplace_transactions
GROUP BY acquisition_month
ORDER BY acquisition_month;

--  Acquisition Cohort Contribution per Delivered Order

SELECT
    DATE_FORMAT(
        STR_TO_DATE(customer_acquisition_date, '%Y-%m-%d'),
        '%Y-%m') AS acquisition_month,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT CASE
        WHEN order_status = 'Delivered' THEN order_id END) AS delivered_orders,

    ROUND(
        SUM(
            CASE WHEN order_status = 'Delivered'
            THEN (quantity * unit_selling_price - discount_amount)
                 - refund_amount - payment_fee - fulfilment_cost ELSE 0 END)
				/ NULLIF(
            COUNT(DISTINCT CASE
                WHEN order_status = 'Delivered' THEN order_id
					END), 0),2) AS contribution_per_delivered_order
FROM marketplace_transactions
GROUP BY acquisition_month
ORDER BY contribution_per_delivered_order DESC;

-- Which customer acquisition cohorts have the highest repeat customer rate, and how does repeat purchasing behavior
--  vary across acquisition months?

SELECT
    acquisition_month,
    COUNT(*) AS total_customers,
    SUM(CASE
        WHEN delivered_orders >= 2 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(
        SUM(CASE
            WHEN delivered_orders >= 2 THEN 1 ELSE 0 END) * 100.0 
				/ COUNT(*),2) AS repeat_customer_rate_pct
FROM (
		SELECT
			customer_id,
				DATE_FORMAT(
						STR_TO_DATE(
							MIN(customer_acquisition_date),'%Y-%m-%d'),'%Y-%m') AS acquisition_month,
			COUNT(DISTINCT CASE
            WHEN order_status = 'Delivered' THEN order_id END) AS delivered_orders
		FROM marketplace_transactions
		GROUP BY customer_id
	) AS customer_cohorts
GROUP BY acquisition_month
ORDER BY acquisition_month;

--  Which acquisition cohorts generate the highest total contribution and contribution per delivered order, and how can the business use these insights to improve customer acquisition strategy?

SELECT
    DATE_FORMAT(
				STR_TO_DATE(customer_acquisition_date, '%Y-%m-%d'),'%Y-%m') AS acquisition_month,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT CASE
        WHEN order_status = 'Delivered'
        THEN order_id
    END) AS delivered_orders,

    ROUND(
        SUM(CASE
            WHEN order_status = 'Delivered'
            THEN (quantity * unit_selling_price - discount_amount) - refund_amount - 
						payment_fee - fulfilment_cost ELSE 0 END),2) AS total_contribution,
    ROUND(
        SUM(CASE
            WHEN order_status = 'Delivered'
            THEN (quantity * unit_selling_price - discount_amount) - refund_amount - payment_fee
							- fulfilment_cost ELSE 0 END) /
								NULLIF( COUNT(DISTINCT CASE	WHEN order_status = 'Delivered'	THEN order_id END),0),2) 
									AS contribution_per_order
FROM marketplace_transactions
GROUP BY acquisition_month
ORDER BY total_contribution DESC;

--  What recommendations can the business make to improve customer acquisition quality, repeat purchases, and contribution from each acquisition cohort?

SELECT
    acquisition_month,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN delivered_orders >= 2 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(
        100.0 * SUM(CASE
                       WHEN delivered_orders >= 2 THEN 1 ELSE 0 END) / COUNT(*),2) AS repeat_customer_rate_pct,
    SUM(delivered_orders) AS delivered_orders,
    ROUND(SUM(total_contribution), 2) AS total_contribution,
    ROUND(
			SUM(total_contribution)
				/ NULLIF(SUM(delivered_orders), 0),2) AS contribution_per_order
FROM (
		SELECT
			customer_id,
			DATE_FORMAT(
				STR_TO_DATE(
							MIN(customer_acquisition_date),'%Y-%m-%d'),'%Y-%m') AS acquisition_month,
			COUNT(DISTINCT CASE
            WHEN order_status = 'Delivered' THEN order_id END) AS delivered_orders,
			SUM(CASE
					WHEN order_status = 'Delivered'
							THEN (quantity * unit_selling_price - discount_amount)
									- refund_amount - payment_fee - fulfilment_cost ELSE 0 END) AS total_contribution
    FROM marketplace_transactions
    GROUP BY customer_id
) AS customer_cohorts
GROUP BY acquisition_month
ORDER BY total_contribution DESC;

-- ********* QUESTION NO 5 ********* -------

-- *********************************************************************************************************************************
/* 5) Commercial downside scenario
Quantify current monthly contribution by category. Calculate the break-even delivered-GMV decline that
eliminates the benefit of a 10% reduction in discount expense. Identify categories with the smallest tolerance
for volume decline.*/
-- *********************************************************************************************************************************

--  Current contribution and discount expense by category

SELECT
    DATE_FORMAT(order_timestamp, '%Y-%m') AS month,
    product_category,
    ROUND(
        SUM(CASE
				WHEN order_status = 'Delivered' THEN discount_amount ELSE 0 END) * 0.10, 2) AS discount_saving,
    ROUND(
        SUM(CASE
            WHEN order_status = 'Delivered'
            THEN (quantity * unit_selling_price - discount_amount)
                 - refund_amount - payment_fee - fulfilment_cost
						ELSE 0 END), 2) AS contribution_at_risk,
    ROUND(
			(
				SUM(CASE
					WHEN order_status = 'Delivered'
						THEN discount_amount ELSE 0 END) * 0.10)
							/ NULLIF( SUM(CASE
								WHEN order_status = 'Delivered'
									THEN (quantity * unit_selling_price - discount_amount)
										- refund_amount - payment_fee - fulfilment_cost ELSE 0 END),0) * 100, 2)
											AS break_even_gmv_decline_pct

FROM marketplace_transactions
GROUP BY
    DATE_FORMAT(order_timestamp, '%Y-%m'),
    product_category
ORDER BY
    month,
    break_even_gmv_decline_pct ASC;

--  10% Discount Reduction Scenario

SELECT
    product_category,
    ROUND(SUM(CASE
        WHEN order_status = 'Delivered'
			THEN discount_amount
				ELSE 0 END) * 0.10, 2) AS discount_saving,
    ROUND(SUM(CASE
				WHEN order_status = 'Delivered'
					THEN (quantity * unit_selling_price - discount_amount)
							- refund_amount - payment_fee - fulfilment_cost
					ELSE 0 END), 2) AS contribution_at_risk,

    ROUND(
        100.0 * (SUM(CASE
						WHEN order_status = 'Delivered' THEN discount_amount ELSE 0 END) * 0.10) 
                        / NULLIF(SUM(CASE WHEN order_status = 'Delivered'
							THEN (quantity * unit_selling_price - discount_amount)
								- refund_amount - payment_fee - fulfilment_cost
							ELSE 0 END),0),2) AS break_even_gmv_decline_pct

FROM marketplace_transactions
GROUP BY product_category
ORDER BY break_even_gmv_decline_pct ASC;

--  Monthly contribution by category

SELECT
    DATE_FORMAT(order_timestamp, '%Y-%m') AS month,
    product_category,
    COUNT(DISTINCT CASE
        WHEN order_status = 'Delivered'
        THEN order_id
    END) AS delivered_orders,

    ROUND(SUM(CASE
        WHEN order_status = 'Delivered'
        THEN quantity * unit_selling_price - discount_amount
        ELSE 0
    END), 2) AS delivered_gmv,

    ROUND(SUM(CASE
        WHEN order_status = 'Delivered'
        THEN discount_amount
        ELSE 0
    END), 2) AS discount_expense,

    ROUND(SUM(CASE
        WHEN order_status = 'Delivered'
        THEN (quantity * unit_selling_price - discount_amount)
             - refund_amount - payment_fee - fulfilment_cost
        ELSE 0
    END), 2) AS current_contribution

FROM marketplace_transactions
GROUP BY
    DATE_FORMAT(order_timestamp, '%Y-%m'),
    product_category
ORDER BY
    month,
    product_category;














