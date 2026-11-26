INSERT INTO dealers (name, email, phone, city) VALUES
 ('Gulf Motors',  'sales@gulfmotors.example', '+971-4-5550101', 'Dubai'),
 ('Desert Auto',  'hello@desertauto.example', '+971-2-5550102', 'Abu Dhabi');
INSERT INTO buyers (full_name, email) VALUES
 ('Alice Buyer', 'alice@example.com'),
 ('Bob Buyer',   'bob@example.com');
INSERT INTO cars (dealer_id, vin, make, model, year, mileage_km, price) VALUES
 (1, '1HGCM82633A004352', 'Honda',  'Accord',  2019, 62000, 21000.00),
 (1, 'JTDKN3DU0A0123456', 'Toyota', 'Prius',   2020, 41000, 19500.00),
 (2, 'WBA3A5C50CF256789', 'BMW',    '320i',    2018, 88000, 24000.00);
INSERT INTO features (name) VALUES ('Sunroof'),('Leather seats'),('Backup camera'),('Apple CarPlay');
INSERT INTO car_features VALUES (1,1),(1,3),(2,3),(2,4),(3,1),(3,2),(3,3),(3,4);
INSERT INTO inspections (car_id, inspected_on, inspector_name, score, result) VALUES
 (1, '2026-11-01', 'Omar', 88, 'pass'),
 (2, '2026-11-02', 'Sara', 92, 'pass'),
 (3, '2026-11-03', 'Omar', 55, 'fail');
INSERT INTO offers (car_id, offered_price, expires_at) VALUES
 (1, 20000.00, now() + interval '7 days');
