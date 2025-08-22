


--Metrics----
-- calculate Total_Revenue,Total_Bookings,Total_Capacity, Total_Succesful_Bookings ---
SELECT
COUNT(booking_id) AS total_bookings,
ROUND(SUM(CAST(revenue_realized AS DECIMAL(12,2))) / 1000000.0, 2) AS total_revenue,
ROUND(SUM(CAST(capacity AS INT)) / 1000.0, 2) AS total_capacity,
SUM(CAST(successful_bookings AS INT)) AS total_successful_bookings
FROM mastertable;

--calculate Occupancy%,Average_Rating, No_of_days, Total_cancelled_bookings, Cancellation %--
select
ROUND((CAST(SUM(successful_bookings) AS FLOAT) / NULLIF(SUM(capacity), 0)) * 100, 2) AS occupancy_percent,
    -- Average rating, ignoring NULLs
ROUND(AVG(NULLIF(ratings_given, 0)), 2) AS average_rating,
    -- Days between first check-in and last check-out
DATEDIFF(DAY, MIN(check_in_date), MAX(checkout_date)) AS total_days_covered,
    -- Cancelled bookings count
COUNT(CASE WHEN LOWER(booking_status) = 'cancelled' THEN 1 END) AS total_cancelled_bookings,
    -- Cancellation rate
ROUND(COUNT(CASE WHEN LOWER(booking_status) = 'cancelled' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(booking_id), 0), 2) AS cancellation_percent
FROM mastertable;


--Calculate Total Checked Out, Total_No_show_bookings, No_Show_rate %--
SELECT
COUNT(*) AS total_bookings,
SUM(CASE WHEN booking_status = 'Checked Out' THEN 1 ELSE 0 END) AS total_checked_out,
SUM(CASE WHEN booking_status = 'No Show' THEN 1 ELSE 0 END) AS total_no_show,
ROUND((SUM(CASE WHEN booking_status = 'No Show' THEN 1 ELSE 0 END) * 100.0)
/ NULLIF(COUNT(*), 0),2) AS no_show_rate_percentage
FROM mastertable;

--Calculate Booking % by Platform, Booking % by Room_class, ADR 
--Booking % by Platform
SELECT
booking_platform,
COUNT(*) AS total_bookings,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),2) AS booking_percentage
FROM mastertable
GROUP BY booking_platform;


--Booking % by Room Class
SELECT
room_class,
COUNT(*) AS total_bookings,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),2) AS booking_percentage
FROM mastertable
GROUP BY room_class;


--ADR(Avg Daily Rate)
SELECT
ROUND(SUM(revenue_realized * 1.0) / NULLIF(SUM(DATEDIFF(day, check_in_date, checkout_date)), 0),2) AS ADR
FROM mastertable
WHERE booking_status = 'Checked Out';


--Calculate Realisation %, RevPAR, DBRN, DSRN, DURN---
--1. Realisation %
SELECT
    ROUND(SUM(revenue_realized) * 100.0 /
	NULLIF(SUM(revenue_generated), 0), 2) AS realization_percentage
FROM mastertable;


--2. RevPAR (Revenue per Available Room)
SELECT
    ROUND(SUM(revenue_realized) * 1.0 /
    NULLIF(SUM(capacity * DATEDIFF(day, check_in_date, checkout_date)), 0),2)AS RevPAR
FROM mastertable
WHERE booking_status = 'Checked Out';


--3. DBRN (Daily Booking Room Nights)
SELECT
SUM(successful_bookings) AS DBRN
FROM mastertable;

--4. DSRN (Daily Sold Room Nights)
SELECT
SUM(successful_bookings) AS DSRN
FROM mastertable
WHERE booking_status = 'Checked Out';


--5. DURN (Daily Used Room Nights)
SELECT
SUM(successful_bookings) AS DURN
FROM mastertable
WHERE booking_status NOT IN ('Cancelled', 'No Show');


----Calculate Revenue WoW change % Occupancy WoW change %, ADR WoW change %, Revpar WoW change %
--1 Revenue WoW change
WITH weekly_revenue AS (
SELECT
week_no,
SUM(CASE WHEN booking_status = 'Checked Out' THEN revenue_realized ELSE 0 END) AS total_revenue
FROM mastertable
GROUP BY week_no
)
SELECT
week_no,
total_revenue,
ROUND((total_revenue - LAG(total_revenue) OVER (ORDER BY week_no)) * 100.0 /
      NULLIF(LAG(total_revenue) OVER (ORDER BY week_no), 0), 2) AS revenue_wow_change_pct
FROM weekly_revenue
ORDER BY week_no

--2. Occupancy WoW change %
SELECT
week_no,
-- Total Room Nights = Capacity * (checkout_date - check_in_date)
ROUND(SUM(CASE WHEN booking_status = 'Checked Out' THEN successful_bookings ELSE 0 END) * 100.0 /
NULLIF(SUM(capacity * DATEDIFF(day, check_in_date, checkout_date)), 0),2)AS occupancy_pct,
-- WoW Change % using LAG
ROUND((ROUND(SUM(CASE WHEN booking_status = 'Checked Out' THEN successful_bookings ELSE 0 END) * 100.0 /
NULLIF(SUM(capacity * DATEDIFF(day, check_in_date, checkout_date)), 0), 2)
-LAG(ROUND(SUM(CASE WHEN booking_status = 'Checked Out' THEN successful_bookings ELSE 0 END) * 100.0 /
NULLIF(SUM(capacity * DATEDIFF(day, check_in_date, checkout_date)), 0), 2))OVER (ORDER BY week_no)) * 1.0 /
NULLIF(LAG(ROUND(SUM(CASE WHEN booking_status = 'Checked Out' THEN successful_bookings ELSE 0 END) * 100.0 /
NULLIF(SUM(capacity * DATEDIFF(day, check_in_date, checkout_date)), 0), 2))OVER (ORDER BY week_no), 0),2) AS occupancy_wow_change_pct
FROM mastertable
GROUP BY week_no
ORDER BY week_no;

--3. ADR WoW change %
WITH weekly_adr AS (
SELECT
week_no,
ROUND(SUM(CASE WHEN booking_status = 'Checked Out' THEN revenue_realized ELSE 0 END) * 1.0 /
      NULLIF(SUM(CASE WHEN booking_status = 'Checked Out' THEN successful_bookings ELSE 0 END), 0),2) AS adr
FROM mastertable
GROUP BY week_no
)
SELECT
week_no,
adr,
ROUND((adr - LAG(adr) OVER (ORDER BY week_no)) * 100.0 /
       NULLIF(LAG(adr) OVER (ORDER BY week_no), 0),2) AS adr_wow_change_pct
FROM weekly_adr
ORDER BY week_no;


-- Calculate Revpar WoW change %
WITH weekly_revpar AS (
SELECT
week_no,
ROUND(SUM(CASE WHEN booking_status = 'Checked Out' THEN revenue_realized ELSE 0 END) * 1.0 
      /NULLIF(SUM(capacity * DATEDIFF(day, check_in_date, checkout_date)), 0),2) AS revpar
FROM mastertable
GROUP BY week_no
)
SELECT
week_no,
revpar,
ROUND((revpar - LAG(revpar) OVER (ORDER BY week_no)) * 100.0 
       /NULLIF(LAG(revpar) OVER (ORDER BY week_no), 0),2) AS revpar_wow_change_pct
FROM weekly_revpar
ORDER BY week_no;

--Calculate Realisation WoW change %
WITH weekly_realisation AS (
SELECT
week_no,
ROUND(SUM(revenue_realized) * 100.0 /NULLIF(SUM(revenue_generated), 0),2) AS realisation_pct
FROM mastertable
GROUP BY week_no
)
SELECT
week_no,
realisation_pct,
ROUND((realisation_pct - LAG(realisation_pct) OVER (ORDER BY week_no)) * 1.0 
/NULLIF(LAG(realisation_pct) OVER (ORDER BY week_no), 0),2) AS realisation_wow_change_pct
FROM weekly_realisation
ORDER BY week_no;

--DSRN WoW change %(Daily Sold Room Nights Week-over-Week % Change)
WITH weekly_dsold AS (
SELECT
week_no,
SUM(CASE WHEN booking_status = 'Checked Out' THEN successful_bookings ELSE 0 END) AS dsrn
FROM mastertable
GROUP BY week_no
)
SELECT
week_no,
dsrn,
ROUND((dsrn - LAG(dsrn) OVER (ORDER BY week_no))*100.0
/NULLIF(LAG(dsrn) OVER (ORDER BY week_no),0),2) AS dsrn_wow_change_pct
FROM weekly_dsold
ORDER BY week_no;

