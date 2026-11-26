DROP TABLE IF EXISTS offers, inspections, car_features, features, cars, buyers, dealers CASCADE;

CREATE TABLE dealers (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(100) NOT NULL CHECK (btrim(name) <> ''),
    email      VARCHAR(150) NOT NULL UNIQUE CHECK (email LIKE '%_@_%'),
    phone      VARCHAR(20)  CHECK (phone ~ '^\+?[0-9 -]{7,20}$'),
    city       VARCHAR(50)  NOT NULL,
    is_active  BOOLEAN      NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE buyers (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name  VARCHAR(100) NOT NULL CHECK (btrim(full_name) <> ''),
    email      VARCHAR(150) NOT NULL UNIQUE CHECK (email LIKE '%_@_%'),
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE cars (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dealer_id   INTEGER       NOT NULL REFERENCES dealers(id) ON DELETE RESTRICT,
    vin         CHAR(17)      NOT NULL UNIQUE CHECK (vin ~ '^[A-HJ-NPR-Z0-9]{17}$'),
    make        VARCHAR(50)   NOT NULL,
    model       VARCHAR(50)   NOT NULL,
    year        SMALLINT      NOT NULL CHECK (year BETWEEN 1990 AND 2030),
    mileage_km  INTEGER       NOT NULL DEFAULT 0 CHECK (mileage_km >= 0),
    price       NUMERIC(12,2) NOT NULL CHECK (price > 0),
    status      VARCHAR(10)   NOT NULL DEFAULT 'available'
                CHECK (status IN ('available','reserved','sold')),
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_cars_dealer_id ON cars(dealer_id);
CREATE INDEX idx_cars_status    ON cars(status) WHERE status = 'available';

CREATE TABLE features (
    id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(60) NOT NULL UNIQUE CHECK (btrim(name) <> '')
);

-- many-to-many: a car has many features, a feature is on many cars
CREATE TABLE car_features (
    car_id     INTEGER NOT NULL REFERENCES cars(id)     ON DELETE CASCADE,
    feature_id INTEGER NOT NULL REFERENCES features(id) ON DELETE RESTRICT,
    PRIMARY KEY (car_id, feature_id)
);
CREATE INDEX idx_car_features_feature_id ON car_features(feature_id);

CREATE TABLE inspections (
    id             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    car_id         INTEGER      NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
    inspected_on   DATE         NOT NULL,
    inspector_name VARCHAR(50)  NOT NULL,
    score          SMALLINT     NOT NULL CHECK (score BETWEEN 0 AND 100),
    result         VARCHAR(4)   NOT NULL CHECK (result IN ('pass','fail')),
    notes          TEXT,
    UNIQUE (car_id, inspected_on),                 -- one inspection per car per day
    CHECK ((result = 'pass') = (score >= 60))      -- result must agree with score
);
CREATE INDEX idx_inspections_car_id ON inspections(car_id);

-- An offer is a dealer's price offer on a car; the first buyer to accept it wins.
CREATE TABLE offers (
    id             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    car_id         INTEGER       NOT NULL REFERENCES cars(id)  ON DELETE CASCADE,
    offered_price  NUMERIC(12,2) NOT NULL CHECK (offered_price > 0),
    status         VARCHAR(10)   NOT NULL DEFAULT 'open'
                   CHECK (status IN ('open','accepted','expired','withdrawn')),
    accepted_by    INTEGER       REFERENCES buyers(id) ON DELETE RESTRICT,
    accepted_at    TIMESTAMPTZ,
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    expires_at     TIMESTAMPTZ   NOT NULL,
    CHECK (expires_at > created_at),
    -- accepted_by / accepted_at are set if and only if status = 'accepted'
    CHECK ((status = 'accepted') = (accepted_by IS NOT NULL AND accepted_at IS NOT NULL))
);
CREATE INDEX idx_offers_car_id ON offers(car_id);
-- a car can only ever have ONE accepted offer
CREATE UNIQUE INDEX uq_offers_one_accepted_per_car ON offers(car_id) WHERE status = 'accepted';
