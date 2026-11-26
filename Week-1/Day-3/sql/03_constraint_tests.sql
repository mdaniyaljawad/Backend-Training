\set ON_ERROR_STOP off
-- each statement below must be REJECTED
INSERT INTO cars (dealer_id,vin,make,model,year,price) VALUES (1,'SHORTVIN','X','Y',2020,1000);            -- bad VIN
INSERT INTO cars (dealer_id,vin,make,model,year,price) VALUES (1,'1HGCM82633A004352','X','Y',2020,1000);   -- duplicate VIN
INSERT INTO cars (dealer_id,vin,make,model,year,price) VALUES (99,'2HGCM82633A004352','X','Y',2020,1000);  -- no such dealer
INSERT INTO cars (dealer_id,vin,make,model,year,price) VALUES (1,'3HGCM82633A004352','X','Y',2020,-5);     -- negative price
INSERT INTO cars (dealer_id,vin,make,model,year,price,status) VALUES (1,'4HGCM82633A004352','X','Y',2020,5,'stolen'); -- bad status
INSERT INTO inspections (car_id,inspected_on,inspector_name,score,result) VALUES (1,'2026-11-05','Z',30,'pass');   -- pass with low score
INSERT INTO inspections (car_id,inspected_on,inspector_name,score,result) VALUES (1,'2026-11-01','Z',90,'pass');   -- same car+day
INSERT INTO offers (car_id,offered_price,status,expires_at) VALUES (1,100,'accepted',now()+interval '1 day');      -- accepted w/o buyer
INSERT INTO offers (car_id,offered_price,expires_at) VALUES (1,100,now()-interval '1 day');                        -- expires in past
DELETE FROM dealers WHERE id = 1;                                                                                   -- dealer still has cars
