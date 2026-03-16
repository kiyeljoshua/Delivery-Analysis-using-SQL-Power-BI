ALTER TABLE SL_vs_Distance
ADD travel_time_to_store INT,
    travel_time_to_customer INT;


UPDATE SL_vs_Distance
SET travel_time_to_store = DATEDIFF(MINUTE, rider_arrived_at_pickup_time, order_pickup_done_time),
    travel_time_to_customer = DATEDIFF(MINUTE, order_pickup_done_time, order_delivered_time);


UPDATE SL_vs_Distance
SET travel_time_to_store = 0, travel_time_to_customer = 0
WHERE order_status = 30;


SELECT 
  order_id,
  CAST(distance_rider_from_store AS DECIMAL(18,2)) AS Distance_Rider_from_Store,
  travel_time_to_store,
  CAST(distance_to_customer AS DECIMAL(18,2)) AS Distance_to_Customer,
  travel_time_to_customer,

  CASE 
    WHEN order_status = 20 THEN 'Completed'
    ELSE 'Cancelled'
  END AS order_status,

  CASE delivery_service_level 
    WHEN 1 THEN 'Early'
    WHEN 2 THEN 'On Time'
    WHEN 3 THEN 'Late'
    ELSE 'Unknown'
  END AS delivery_status,

  CASE 
    WHEN distance_to_customer > 5 THEN 'Long Distance'
    ELSE 'Short Distance'
  END AS distance_category,

  FORMAT(order_pickup_done_time, 'yyyy/MM/dd') AS Delivery_Date

FROM SL_vs_Distance
WHERE order_status = 20 OR order_status = 30