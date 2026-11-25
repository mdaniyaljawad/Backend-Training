DROP TABLE IF EXISTS inspections, cars, dealers CASCADE;

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
