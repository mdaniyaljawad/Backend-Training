-- Q1: all dealers
SELECT * FROM dealers ORDER BY id;
-- Q2: available cars newer than 2020, cheapest first
SELECT id, make, model, year, price FROM cars WHERE status='available' AND year > 2020 ORDER BY price LIMIT 10;
-- Q3: count of cars per make
SELECT make, COUNT(*) AS cars FROM cars GROUP BY make ORDER BY cars DESC;
-- Q4: JOIN 1 - cars with their dealer
SELECT c.id, c.make, c.model, d.name AS dealer, d.city FROM cars c JOIN dealers d ON d.id = c.dealer_id ORDER BY c.id LIMIT 10;
-- Q5: JOIN 2 - inspections with car and dealer (three tables)
SELECT i.id, i.inspected_on, i.score, c.make, c.model, d.name AS dealer
FROM inspections i JOIN cars c ON c.id = i.car_id JOIN dealers d ON d.id = c.dealer_id
WHERE i.result = 'fail' ORDER BY i.inspected_on DESC LIMIT 10;
-- Q6: GROUP BY - average inspection score and pass rate per dealer
SELECT d.name, COUNT(i.id) AS inspections, round(AVG(i.score),1) AS avg_score,
       round(100.0 * AVG((i.result='pass')::int),1) AS pass_pct
FROM dealers d JOIN cars c ON c.dealer_id = d.id JOIN inspections i ON i.car_id = c.id
GROUP BY d.name ORDER BY avg_score DESC;
-- Q7: HAVING - makes with average price above 100k
SELECT make, round(AVG(price),0) AS avg_price FROM cars GROUP BY make HAVING AVG(price) > 100000;
-- Q8: cars never inspected (LEFT JOIN anti-join)
SELECT c.id, c.make FROM cars c LEFT JOIN inspections i ON i.car_id = c.id WHERE i.id IS NULL;
-- Q9: subquery - cars whose average score is below overall average
SELECT car_id, round(AVG(score),1) AS avg_score FROM inspections GROUP BY car_id
HAVING AVG(score) < (SELECT AVG(score) FROM inspections) ORDER BY avg_score LIMIT 10;
-- Q10 (slow candidate): all failed inspections for one car, newest first
SELECT * FROM inspections WHERE car_id = 42 AND result = 'fail' ORDER BY inspected_on DESC;
