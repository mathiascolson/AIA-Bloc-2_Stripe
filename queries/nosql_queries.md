# Requêtes NoSQL — MongoDB

## 1. Événements de risque récents

```javascript
db.risk_events.find(
  { risk_level: "high" }
).sort(
  { event_timestamp: -1 }
).limit(20)
```

## 2. Parcours utilisateur par session

```javascript
db.clickstream_events.find(
  { session_id: "SESSION_001" }
).sort(
  { event_timestamp: 1 }
)
```

## 3. Snapshot de features ML pour une transaction

```javascript
db.ml_feature_snapshots.find(
  { transaction_id: "TXN_100245" }
)
```

## 4. Feedbacks clients négatifs

```javascript
db.customer_feedback.find(
  { sentiment_score: { $lt: -0.5 } }
).sort(
  { submitted_at: -1 }
)
```

## 5. Détection d’appareils suspects

```javascript
db.clickstream_events.aggregate([
  {
    $group: {
      _id: "$device_fingerprint",
      total_events: { $sum: 1 },
      unique_customers: { $addToSet: "$customer_id" }
    }
  },
  {
    $project: {
      total_events: 1,
      customer_count: { $size: "$unique_customers" }
    }
  },
  {
    $match: {
      customer_count: { $gt: 10 }
    }
  },
  {
    $sort: {
      customer_count: -1
    }
  }
])
```