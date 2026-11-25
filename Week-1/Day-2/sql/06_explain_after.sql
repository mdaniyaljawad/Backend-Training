EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM inspections WHERE car_id = 42 AND result = 'fail' ORDER BY inspected_on DESC;
