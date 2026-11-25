# PostgreSQL: Dealers, Cars and Inspections

Environment: PostgreSQL 16 in Docker (`docker run -d --name pgtrain -e POSTGRES_PASSWORD=pw -p 55432:5432 postgres:16`).
All SQL lives in [sql/](sql/); raw outputs are in [queries_output.txt](queries_output.txt), [explain_before.txt](explain_before.txt) and [explain_after.txt](explain_after.txt).

## 1. Schema ([sql/01_schema.sql](sql/01_schema.sql))

```sql
CREATE TABLE dealers (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    city       VARCHAR(50)  NOT NULL,
    created_at TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE TABLE cars (
    id         SERIAL PRIMARY KEY,
    dealer_id  INTEGER      NOT NULL REFERENCES dealers(id),
    make       VARCHAR(50)  NOT NULL,
    model      VARCHAR(50)  NOT NULL,
    year       INTEGER      NOT NULL CHECK (year BETWEEN 1990 AND 2026),
    price      NUMERIC(10,2) NOT NULL,
    status     VARCHAR(20)  NOT NULL DEFAULT 'available'
);

CREATE TABLE inspections (
    id             SERIAL PRIMARY KEY,
    car_id         INTEGER     NOT NULL REFERENCES cars(id),
    inspected_on   DATE        NOT NULL,
    score          INTEGER     NOT NULL CHECK (score BETWEEN 0 AND 100),
    result         VARCHAR(10) NOT NULL CHECK (result IN ('pass','fail')),
    inspector_name VARCHAR(50) NOT NULL
);
```

Keys: each table has a `SERIAL PRIMARY KEY`; `cars.dealer_id -> dealers.id` and `inspections.car_id -> cars.id` are foreign keys. `CHECK` constraints guard year, score and result.

## 2. Seed data ([sql/02_seed.sql](sql/02_seed.sql))

| Table       |   Rows |
| :---------- | -----: |
| dealers     |     10 |
| cars        |    300 |
| inspections | 20,000 |

Inspections were seeded at 20,000 rows so the index effect is measurable.

```sql
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
```

## 3. Ten queries ([sql/03_queries.sql](sql/03_queries.sql))

|  #  | Purpose                                       | Technique                                                 |
| :-: | :-------------------------------------------- | :-------------------------------------------------------- |
| Q1  | List dealers                                  | `ORDER BY`                                                |
| Q2  | Cheapest available cars after 2020            | `WHERE`, `LIMIT`                                          |
| Q3  | Cars per make                                 | **GROUP BY**                                              |
| Q4  | Cars with their dealer                        | **JOIN** (2 tables)                                       |
| Q5  | Latest failed inspections with car and dealer | **JOIN** (3 tables)                                       |
| Q6  | Avg score and pass rate per dealer            | **GROUP BY** over joins                                   |
| Q7  | Makes with avg price above 100k               | `GROUP BY` + `HAVING`                                     |
| Q8  | Cars never inspected                          | `LEFT JOIN` anti-join (0 rows: every car has inspections) |
| Q9  | Cars scoring below the overall average        | subquery + `HAVING`                                       |
| Q10 | Failed inspections for one car, newest first  | filter + sort (used for EXPLAIN)                          |

```sql
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
```

Sample result, Q6 (GROUP BY across three tables):

```
   name    | inspections | avg_score | pass_pct
-----------+-------------+-----------+----------
 Dealer 2  |        2000 |      50.8 |     41.7
 Dealer 4  |        2000 |      50.7 |     42.2
 Dealer 10 |        2000 |      50.3 |     41.2
 ...
```

## 4. EXPLAIN ANALYZE on Q10

Query: `SELECT * FROM inspections WHERE car_id = 42 AND result = 'fail' ORDER BY inspected_on DESC;`

Foreign keys do not create an index in PostgreSQL, so `inspections.car_id` had none.

### Before

```
QUERY PLAN
----------------------------------------------------------------------------------------------------------------
 Sort  (cost=468.06..468.16 rows=40 width=33) (actual time=1.853..1.856 rows=39 loops=1)
   Sort Key: inspected_on DESC
   Sort Method: quicksort  Memory: 27kB
   Buffers: shared hit=170
   ->  Seq Scan on inspections  (cost=0.00..467.00 rows=40 width=33) (actual time=0.012..1.820 rows=39 loops=1)
         Filter: ((car_id = 42) AND ((result)::text = 'fail'::text))
         Rows Removed by Filter: 19961
         Buffers: shared hit=167
 Planning:
   Buffers: shared hit=94
 Planning Time: 0.313 ms
 Execution Time: 1.886 ms
(12 rows)
```

A **Seq Scan** reads all 20,000 rows and discards 19,961 (`Rows Removed by Filter`).

### Index added ([sql/05_index.sql](sql/05_index.sql))

```sql
CREATE INDEX idx_inspections_car_id_result_date ON inspections (car_id, result, inspected_on DESC);
ANALYZE inspections;
```

### After

```
QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=100.22..100.32 rows=40 width=33) (actual time=0.221..0.224 rows=39 loops=1)
   Sort Key: inspected_on DESC
   Sort Method: quicksort  Memory: 27kB
   Buffers: shared hit=42 read=2
   ->  Bitmap Heap Scan on inspections  (cost=4.70..99.15 rows=40 width=33) (actual time=0.051..0.179 rows=39 loops=1)
         Recheck Cond: ((car_id = 42) AND ((result)::text = 'fail'::text))
         Heap Blocks: exact=39
         Buffers: shared hit=39 read=2
         ->  Bitmap Index Scan on idx_inspections_car_id_result_date  (cost=0.00..4.69 rows=40 width=0) (actual time=0.042..0.043 rows=39 loops=1)
               Index Cond: ((car_id = 42) AND ((result)::text = 'fail'::text))
               Buffers: shared read=2
 Planning:
   Buffers: shared hit=140 read=1
 Planning Time: 0.581 ms
 Execution Time: 0.279 ms
(15 rows)
```

The planner switched to a **Bitmap Index Scan**, touching only the matching rows.

### Comparison

| Metric         | Before (Seq Scan) |                 After (Index) |
| :------------- | ----------------: | ----------------------------: |
| Scan type      |          Seq Scan | Bitmap Index Scan + Heap Scan |
| Rows examined  |            20,000 |                            39 |
| Estimated cost |            468.16 |                        100.32 |
| Execution time |          1.886 ms |                      0.279 ms |
| Buffers        |           170 hit |               42 hit + 2 read |

About **6.8x faster** (1.886 ms to 0.279 ms). Absolute times are tiny because the table is small; the gap grows with table size, since a seq scan is linear in rows while the index lookup is not. A single run each, so treat timings as indicative.
