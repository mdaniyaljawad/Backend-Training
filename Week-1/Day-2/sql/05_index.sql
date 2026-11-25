CREATE INDEX idx_inspections_car_id_result_date ON inspections (car_id, result, inspected_on DESC);
ANALYZE inspections;
