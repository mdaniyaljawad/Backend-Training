-- 10 dealers
INSERT INTO dealers (name, city)
SELECT 'Dealer ' || g,
       (ARRAY['Dubai','Abu Dhabi','Sharjah','Ajman','Karachi','Lahore'])[1 + g % 6]
FROM generate_series(1,10) g;

-- 300 cars
INSERT INTO cars (dealer_id, make, model, year, price, status)
SELECT 1 + (g % 10),
       (ARRAY['Toyota','Honda','Nissan','BMW','Kia'])[1 + g % 5],
       'Model-' || (1 + g % 8),
       2010 + (g % 16),
       round((20000 + random()*180000)::numeric, 2),
       (ARRAY['available','sold','reserved'])[1 + g % 3]
FROM generate_series(1,300) g;

-- 20,000 inspections (large enough for index effects to show)
INSERT INTO inspections (car_id, inspected_on, score, result, inspector_name)
SELECT 1 + (g % 300),
       DATE '2023-01-01' + (random()*1000)::int,
       s,
       CASE WHEN s >= 60 THEN 'pass' ELSE 'fail' END,
       'Inspector ' || (1 + g % 12)
FROM (SELECT g, (random()*100)::int AS s FROM generate_series(1,20000) g) t;

ANALYZE;
