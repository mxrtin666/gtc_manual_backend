SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE DATABASE IF NOT EXISTS gtc
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE gtc;

-- =========================
-- 1) Core lookup tables
-- =========================

CREATE TABLE IF NOT EXISTS currencies (
                                          iso CHAR(3) NOT NULL,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (iso),
    UNIQUE KEY uq_currencies_name (name)
    ) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS countries (
                                         iso CHAR(2) NOT NULL,
    name VARCHAR(120) NOT NULL,
    official VARCHAR(180) NOT NULL,
    capital VARCHAR(120) NOT NULL,
    largest_city VARCHAR(120) NOT NULL,
    area INT UNSIGNED NOT NULL,
    area_rank SMALLINT UNSIGNED NOT NULL,
    population BIGINT UNSIGNED NOT NULL,
    population_rank SMALLINT UNSIGNED NOT NULL,
    calling_code VARCHAR(12) NOT NULL,
    currency_iso CHAR(3) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (iso),
    UNIQUE KEY uq_countries_name (name),
    KEY idx_countries_currency_iso (currency_iso),
    CONSTRAINT fk_countries_currency
    FOREIGN KEY (currency_iso) REFERENCES currencies(iso)
                                                            ON UPDATE CASCADE
                                                            ON DELETE RESTRICT
    ) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS country_tlds (
                                            country_iso CHAR(2) NOT NULL,
    tld VARCHAR(20) NOT NULL,
    PRIMARY KEY (country_iso, tld),
    CONSTRAINT fk_country_tlds_country
    FOREIGN KEY (country_iso) REFERENCES countries(iso)
    ON UPDATE CASCADE
    ON DELETE CASCADE
    ) ENGINE=InnoDB;

-- Flat pair table (better for REST than matrix JSON shape)
CREATE TABLE IF NOT EXISTS exchange_rates (
                                              base_currency_iso CHAR(3) NOT NULL,
    quote_currency_iso CHAR(3) NOT NULL,
    rate DECIMAL(18,6) NOT NULL,
    valid_from DATETIME(3) NOT NULL,
    valid_to DATETIME(3) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (base_currency_iso, quote_currency_iso, valid_from),
    KEY idx_exchange_rates_lookup (base_currency_iso, quote_currency_iso, valid_to, valid_from),
    CONSTRAINT fk_exchange_rates_base
    FOREIGN KEY (base_currency_iso) REFERENCES currencies(iso)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    CONSTRAINT fk_exchange_rates_quote
    FOREIGN KEY (quote_currency_iso) REFERENCES currencies(iso)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    CONSTRAINT chk_exchange_rates_positive CHECK (rate > 0)
    ) ENGINE=InnoDB;

-- =========================
-- 2) Auth + business tables
-- =========================

CREATE TABLE IF NOT EXISTS users (
                                     id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                                     first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    user_login VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_as_cs NOT NULL,
    -- Keep plaintext for current compatibility; migrate to password_hash asap.
    password VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_as_cs NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_user_login (user_login)
    ) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS transactions (
                                            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                                            transaction_date DATETIME(3) NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    source_amount DECIMAL(18,2) NOT NULL,
    source_currency_iso CHAR(3) NOT NULL,
    target_currency_iso CHAR(3) NOT NULL,
    exchange_rate DECIMAL(18,6) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_transactions_user_date (user_id, transaction_date),
    KEY idx_transactions_date (transaction_date),
    KEY idx_transactions_source_currency (source_currency_iso),
    KEY idx_transactions_target_currency (target_currency_iso),
    CONSTRAINT fk_transactions_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    CONSTRAINT fk_transactions_source_currency
    FOREIGN KEY (source_currency_iso) REFERENCES currencies(iso)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    CONSTRAINT fk_transactions_target_currency
    FOREIGN KEY (target_currency_iso) REFERENCES currencies(iso)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
    CONSTRAINT chk_transactions_source_amount CHECK (source_amount > 0),
    CONSTRAINT chk_transactions_exchange_rate CHECK (exchange_rate > 0)
    ) ENGINE=InnoDB;

-- =========================
-- 3) Seed data from current JSON
-- =========================

INSERT INTO currencies (iso, name) VALUES
                                       ('CHF', 'Swiss Franc'),
                                       ('CZK', 'Czech Koruna'),
                                       ('EUR', 'Euro'),
                                       ('GBP', 'Pound Sterling'),
                                       ('SEK', 'Swedish Krona'),
                                       ('TRY', 'Turkish Lira'),
                                       ('USD', 'United States Dollar')
    ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO countries
(iso, name, official, capital, largest_city, area, area_rank, population, population_rank, calling_code, currency_iso)
VALUES
    ('AT','Austria','Republic of Austria','Wien','Wien',83878,113,9216459,97,'+43','EUR'),
    ('BE','Belgium','Kingdom of Belgium','Bruxelles','Bruxelles',30528,136,11917402,80,'+32','EUR'),
    ('CZ','Czechia','Czech Republic','Praha','Praha',78871,115,10882341,85,'+420','CZK'),
    ('FR','France','French Republic','Paris','Paris',643801,42,68736000,21,'+33','EUR'),
    ('DE','Germany','Federal Republic of Germany','Berlin','Berlin',357581,63,83497147,19,'+49','EUR'),
    ('IT','Italy','Italian Republic','Roma','Roma',302068,71,58925596,25,'+39','EUR'),
    ('LI','Liechtenstein','Principality of Liechtenstein','Vaduz','Schaan',160,190,41024,189,'+423','CHF'),
    ('ES','Spain','Kingdom of Spain','Madrid','Madrid',505370,50,49442844,31,'+34','EUR'),
    ('SE','Sweden','Kingdom of Sweden','Stockholm','Stockholm',450295,55,10610485,88,'+46','SEK'),
    ('CH','Switzerland','Swiss Confederation','Bern','Zürich',41291,132,9104063,99,'+41','CHF'),
    ('TR','Turkey','Republic of Türkiye','Ankara','İstanbul',783562,36,85664944,18,'+90','TRY'),
    ('GB','United Kingdom','United Kingdom of Great Britain and Northern Ireland','London','London',244376,78,69487000,20,'+44','GBP'),
    ('US','United States','United States of America','Washington, D.C.','New York City',9525067,4,340110988,3,'+1','USD'),
    ('VA','Vatican City','Vatican City State','Vatican City','Vatican City',0,195,882,195,'+379','EUR')
    ON DUPLICATE KEY UPDATE
                         name = VALUES(name),
                         official = VALUES(official),
                         capital = VALUES(capital),
                         largest_city = VALUES(largest_city),
                         area = VALUES(area),
                         area_rank = VALUES(area_rank),
                         population = VALUES(population),
                         population_rank = VALUES(population_rank),
                         calling_code = VALUES(calling_code),
                         currency_iso = VALUES(currency_iso);

INSERT INTO country_tlds (country_iso, tld) VALUES
                                                ('AT','.at'),
                                                ('BE','.be'),
                                                ('CZ','.cz'),
                                                ('FR','.fr'),
                                                ('DE','.de'),
                                                ('DE','.eu'),
                                                ('IT','.it'),
                                                ('LI','.li'),
                                                ('ES','.es'),
                                                ('SE','.se'),
                                                ('CH','.ch'),
                                                ('CH','.swiss'),
                                                ('TR','.tr'),
                                                ('GB','.uk'),
                                                ('US','.us'),
                                                ('VA','.va')
    ON DUPLICATE KEY UPDATE tld = VALUES(tld);

INSERT INTO users (id, first_name, last_name, user_login, password) VALUES
    (1, 'Demo', 'User', 'demo', 'demo123')
    ON DUPLICATE KEY UPDATE
                         first_name = VALUES(first_name),
                         last_name = VALUES(last_name),
                         password = VALUES(password);


INSERT INTO transactions
(id, transaction_date, user_id, source_amount, source_currency_iso, target_currency_iso, exchange_rate)
VALUES
    (1, '2026-01-01 09:15:00.000', 1, 100.00, 'CHF', 'EUR', 1.062300)
    ON DUPLICATE KEY UPDATE
                         transaction_date = VALUES(transaction_date),
                         user_id = VALUES(user_id),
                         source_amount = VALUES(source_amount),
                         source_currency_iso = VALUES(source_currency_iso),
                         target_currency_iso = VALUES(target_currency_iso),
                         exchange_rate = VALUES(exchange_rate);

-- Based on /data/rateRows.json matrix; snapshot date from UI reference (2026-01-01)
INSERT INTO exchange_rates (base_currency_iso, quote_currency_iso, rate, valid_from, valid_to) VALUES
                                                                                                   ('CHF','CHF',1.000000,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('CHF','EUR',1.073860,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('CHF','USD',1.261140,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('CHF','GBP',0.937044,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('EUR','CHF',0.931216,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('EUR','EUR',1.000000,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('EUR','USD',1.174400,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('EUR','GBP',0.872591,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('USD','CHF',0.792932,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('USD','EUR',0.851502,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('USD','USD',1.000000,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('USD','GBP',0.743013,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('GBP','CHF',1.067190,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('GBP','EUR',1.146010,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('GBP','USD',1.345870,'2026-01-01 00:00:00.000',NULL),
                                                                                                   ('GBP','GBP',1.000000,'2026-01-01 00:00:00.000',NULL)
    ON DUPLICATE KEY UPDATE
                         rate = VALUES(rate),
                         valid_to = VALUES(valid_to);
