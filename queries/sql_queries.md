# Requêtes SQL — Snowflake / dbt

## 1. Revenu quotidien par marchand

Objectif : suivre le revenu quotidien par marchand, devise et statut de paiement.

```sql
SELECT
    d.full_date AS payment_date,
    m.business_name,
    c.currency_code,
    r.payment_status,
    r.total_payments,
    r.gross_revenue,
    r.average_payment_amount,
    r.distinct_customers
FROM mart_daily_revenue r
JOIN dim_date d ON r.payment_date_key = d.date_key
JOIN dim_merchants m ON r.merchant_key = m.merchant_key
JOIN dim_currencies c ON r.currency_key = c.currency_key
ORDER BY d.full_date DESC, r.gross_revenue DESC;
```

## 2. Transactions à risque élevé

```sql
SELECT
    t.transaction_id,
    d.full_date AS transaction_date,
    cu.customer_email,
    m.business_name,
    t.transaction_amount,
    t.fraud_indicator,
    t.transaction_status
FROM fact_transactions t
JOIN dim_date d ON t.transaction_date_key = d.date_key
JOIN dim_customers cu ON t.customer_key = cu.customer_key
JOIN dim_merchants m ON t.merchant_key = m.merchant_key
WHERE t.fraud_indicator >= 80
ORDER BY t.fraud_indicator DESC;
```

## 3. Segmentation client par valeur

```sql
SELECT
    c.customer_id,
    c.customer_email,
    l.total_payments,
    l.gross_lifetime_value,
    l.total_refund_amount,
    l.total_dispute_amount,
    l.net_lifetime_value,
    CASE
        WHEN l.net_lifetime_value >= 10000 AND l.total_dispute_amount = 0 THEN 'high_value_low_risk'
        WHEN l.net_lifetime_value >= 10000 AND l.total_dispute_amount > 0 THEN 'high_value_watchlist'
        WHEN l.net_lifetime_value BETWEEN 1000 AND 9999 THEN 'standard_customer'
        ELSE 'low_value_customer'
    END AS customer_segment
FROM mart_customer_ltv l
JOIN dim_customers c ON l.customer_key = c.customer_key
ORDER BY l.net_lifetime_value DESC;
```

## 4. Revenu glissant sur 7 jours

```sql
SELECT
    merchant_key,
    payment_date_key,
    gross_revenue,
    SUM(gross_revenue) OVER (
        PARTITION BY merchant_key
        ORDER BY payment_date_key
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7d_revenue
FROM mart_daily_revenue
ORDER BY merchant_key, payment_date_key;
```
## 5. Monitoring du risque par jour

```sql
SELECT
    d.full_date AS transaction_date,
    f.fraud_risk_level,
    c.currency_code,
    f.total_transactions,
    f.total_transaction_amount,
    f.average_fraud_score,
    f.high_risk_transactions,
    f.blocked_transactions
FROM mart_fraud_monitoring f
JOIN dim_date d ON f.transaction_date_key = d.date_key
JOIN dim_currencies c ON f.currency_key = c.currency_key
ORDER BY d.full_date DESC, f.average_fraud_score DESC;
```

