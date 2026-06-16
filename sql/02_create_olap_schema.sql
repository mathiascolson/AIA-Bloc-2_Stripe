DROP TABLE IF EXISTS mart_subscription_revenue CASCADE;
DROP TABLE IF EXISTS mart_fraud_monitoring CASCADE;
DROP TABLE IF EXISTS mart_customer_ltv CASCADE;
DROP TABLE IF EXISTS mart_daily_revenue CASCADE;

DROP TABLE IF EXISTS fact_disputes CASCADE;
DROP TABLE IF EXISTS fact_refunds CASCADE;
DROP TABLE IF EXISTS fact_transactions CASCADE;
DROP TABLE IF EXISTS fact_payments CASCADE;

DROP TABLE IF EXISTS dim_products CASCADE;
DROP TABLE IF EXISTS dim_merchants CASCADE;
DROP TABLE IF EXISTS dim_customers CASCADE;
DROP TABLE IF EXISTS dim_payment_methods CASCADE;
DROP TABLE IF EXISTS dim_countries CASCADE;
DROP TABLE IF EXISTS dim_currencies CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;

CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    day INT NOT NULL CHECK (day BETWEEN 1 AND 31),
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    quarter INT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    year INT NOT NULL,
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    day_name VARCHAR(20),
    month_name VARCHAR(20),
    is_weekend BOOLEAN NOT NULL
);

CREATE TABLE dim_currencies (
    currency_key SERIAL PRIMARY KEY,
    currency_id INT NOT NULL UNIQUE,
    currency_code VARCHAR(3) NOT NULL,
    currency_name VARCHAR(100) NOT NULL,
    currency_symbol VARCHAR(10)
);

CREATE TABLE dim_countries (
    country_key SERIAL PRIMARY KEY,
    country_id INT NOT NULL UNIQUE,
    country_code VARCHAR(2) NOT NULL,
    country_name VARCHAR(100) NOT NULL,
    currency_key INT REFERENCES dim_currencies(currency_key)
);

CREATE TABLE dim_payment_methods (
    payment_method_key SERIAL PRIMARY KEY,
    payment_method_id INT NOT NULL UNIQUE,
    payment_method_code VARCHAR(20) NOT NULL,
    payment_method_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN
);

CREATE TABLE dim_customers (
    customer_key SERIAL PRIMARY KEY,
    customer_id INT NOT NULL UNIQUE,
    user_id INT,
    stripe_customer_id VARCHAR(255),
    customer_name VARCHAR(255),
    customer_email VARCHAR(255),
    billing_city VARCHAR(100),
    billing_region VARCHAR(100),
    billing_postal_code VARCHAR(20),
    billing_country_key INT REFERENCES dim_countries(country_key),
    default_payment_method_key INT REFERENCES dim_payment_methods(payment_method_key),
    customer_created_at TIMESTAMP
);

CREATE TABLE dim_merchants (
    merchant_key SERIAL PRIMARY KEY,
    merchant_id INT NOT NULL UNIQUE,
    user_id INT,
    stripe_account_id VARCHAR(255),
    merchant_name VARCHAR(255),
    merchant_email VARCHAR(255),
    business_name VARCHAR(255),
    country_key INT REFERENCES dim_countries(country_key),
    merchant_created_at TIMESTAMP
);

CREATE TABLE dim_products (
    product_key SERIAL PRIMARY KEY,
    product_id INT NOT NULL UNIQUE,
    merchant_key INT REFERENCES dim_merchants(merchant_key),
    product_name VARCHAR(255) NOT NULL,
    product_description TEXT,
    product_price DECIMAL(10, 2),
    currency_key INT REFERENCES dim_currencies(currency_key),
    product_created_at TIMESTAMP
);

CREATE TABLE fact_payments (
    payment_key SERIAL PRIMARY KEY,
    payment_id INT NOT NULL UNIQUE,
    customer_key INT NOT NULL REFERENCES dim_customers(customer_key),
    merchant_key INT NOT NULL REFERENCES dim_merchants(merchant_key),
    payment_method_key INT NOT NULL REFERENCES dim_payment_methods(payment_method_key),
    product_key INT REFERENCES dim_products(product_key),
    currency_key INT NOT NULL REFERENCES dim_currencies(currency_key),
    payment_date_key INT NOT NULL REFERENCES dim_date(date_key),
    stripe_payment_id VARCHAR(255),
    payment_amount DECIMAL(10, 2) NOT NULL CHECK (payment_amount >= 0),
    payment_status VARCHAR(50) NOT NULL,
    payment_created_at TIMESTAMP NOT NULL
);

CREATE TABLE fact_transactions (
    transaction_key SERIAL PRIMARY KEY,
    transaction_id INT NOT NULL UNIQUE,
    payment_key INT NOT NULL REFERENCES fact_payments(payment_key),
    customer_key INT NOT NULL REFERENCES dim_customers(customer_key),
    merchant_key INT NOT NULL REFERENCES dim_merchants(merchant_key),
    currency_key INT NOT NULL REFERENCES dim_currencies(currency_key),
    transaction_date_key INT NOT NULL REFERENCES dim_date(date_key),
    stripe_transaction_id VARCHAR(255),
    transaction_amount DECIMAL(10, 2) NOT NULL CHECK (transaction_amount >= 0),
    transaction_status VARCHAR(50) NOT NULL,
    fraud_indicator DECIMAL(5, 2) CHECK (fraud_indicator BETWEEN 0 AND 100),
    location_ip VARCHAR(45),
    device_type VARCHAR(20),
    transaction_created_at TIMESTAMP NOT NULL
);

CREATE TABLE fact_refunds (
    refund_key SERIAL PRIMARY KEY,
    refund_id INT NOT NULL UNIQUE,
    payment_key INT NOT NULL REFERENCES fact_payments(payment_key),
    customer_key INT NOT NULL REFERENCES dim_customers(customer_key),
    merchant_key INT NOT NULL REFERENCES dim_merchants(merchant_key),
    refund_date_key INT NOT NULL REFERENCES dim_date(date_key),
    stripe_refund_id VARCHAR(255),
    refund_amount DECIMAL(10, 2) NOT NULL CHECK (refund_amount >= 0),
    refund_status VARCHAR(50) NOT NULL,
    refund_reason TEXT,
    refund_created_at TIMESTAMP NOT NULL
);

CREATE TABLE fact_disputes (
    dispute_key SERIAL PRIMARY KEY,
    dispute_id INT NOT NULL UNIQUE,
    payment_key INT NOT NULL REFERENCES fact_payments(payment_key),
    customer_key INT NOT NULL REFERENCES dim_customers(customer_key),
    merchant_key INT NOT NULL REFERENCES dim_merchants(merchant_key),
    dispute_date_key INT NOT NULL REFERENCES dim_date(date_key),
    stripe_dispute_id VARCHAR(255),
    dispute_amount DECIMAL(10, 2) NOT NULL CHECK (dispute_amount >= 0),
    dispute_status VARCHAR(50) NOT NULL,
    dispute_reason TEXT,
    dispute_created_at TIMESTAMP NOT NULL
);

CREATE TABLE mart_daily_revenue (
    payment_date_key INT REFERENCES dim_date(date_key),
    merchant_key INT REFERENCES dim_merchants(merchant_key),
    currency_key INT REFERENCES dim_currencies(currency_key),
    payment_status VARCHAR(50),
    total_payments INT NOT NULL CHECK (total_payments >= 0),
    gross_revenue DECIMAL(18, 2) NOT NULL CHECK (gross_revenue >= 0),
    average_payment_amount DECIMAL(18, 2),
    distinct_customers INT NOT NULL CHECK (distinct_customers >= 0),
    PRIMARY KEY (
        payment_date_key,
        merchant_key,
        currency_key,
        payment_status
    )
);

CREATE TABLE mart_customer_ltv (
    customer_key INT PRIMARY KEY REFERENCES dim_customers(customer_key),
    total_payments INT NOT NULL CHECK (total_payments >= 0),
    successful_payments INT NOT NULL CHECK (successful_payments >= 0),
    failed_payments INT NOT NULL CHECK (failed_payments >= 0),
    gross_lifetime_value DECIMAL(18, 2) NOT NULL CHECK (gross_lifetime_value >= 0),
    total_refund_amount DECIMAL(18, 2) NOT NULL CHECK (total_refund_amount >= 0),
    total_dispute_amount DECIMAL(18, 2) NOT NULL CHECK (total_dispute_amount >= 0),
    net_lifetime_value DECIMAL(18, 2) NOT NULL,
    first_payment_date_key INT REFERENCES dim_date(date_key),
    last_payment_date_key INT REFERENCES dim_date(date_key)
);

CREATE TABLE mart_fraud_monitoring (
    transaction_date_key INT REFERENCES dim_date(date_key),
    fraud_risk_level VARCHAR(20),
    currency_key INT REFERENCES dim_currencies(currency_key),
    total_transactions INT NOT NULL CHECK (total_transactions >= 0),
    total_transaction_amount DECIMAL(18, 2) NOT NULL CHECK (total_transaction_amount >= 0),
    average_fraud_score DECIMAL(5, 2),
    high_risk_transactions INT NOT NULL CHECK (high_risk_transactions >= 0),
    blocked_transactions INT NOT NULL CHECK (blocked_transactions >= 0),
    distinct_customers INT NOT NULL CHECK (distinct_customers >= 0),
    distinct_merchants INT NOT NULL CHECK (distinct_merchants >= 0),
    PRIMARY KEY (
        transaction_date_key,
        fraud_risk_level,
        currency_key
    )
);

CREATE TABLE mart_subscription_revenue (
    product_key INT REFERENCES dim_products(product_key),
    currency_key INT REFERENCES dim_currencies(currency_key),
    subscription_status VARCHAR(50),
    total_subscriptions INT NOT NULL CHECK (total_subscriptions >= 0),
    active_subscriptions INT NOT NULL CHECK (active_subscriptions >= 0),
    total_subscription_revenue DECIMAL(18, 2) NOT NULL CHECK (total_subscription_revenue >= 0),
    PRIMARY KEY (
        product_key,
        currency_key,
        subscription_status
    )
);