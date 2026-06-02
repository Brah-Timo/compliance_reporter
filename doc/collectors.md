# Log Collectors

Log collectors are responsible for fetching `AccessLog` data from various sources. All implement `BaseLogCollector`.

---

## `MemoryLogCollector`

The simplest collector — wraps an existing `List<AccessLog>` in memory. Ideal for unit tests and Flutter applications that already have logs loaded.

```dart
final collector = MemoryLogCollector(
  logs: accessLogs,    // List<AccessLog>
);
```

Supports `userId` and `ipAddress` filtering in-memory.

---

## `FileLogCollector`

Reads access logs from a JSON or JSONL file on the local filesystem.

```dart
final collector = FileLogCollector(
  filePath: '/var/log/myapp/access.json',
  format: FileLogFormat.json,       // json (array) or jsonl (one object per line)
  customParser: null,               // optional: custom AccessLog.fromJson replacement
);
```

### Supported formats

| Format | Description |
|---|---|
| `FileLogFormat.json` | Single JSON array `[{...}, {...}]` |
| `FileLogFormat.jsonl` | One JSON object per line (NDJSON) |

---

## `DatabaseLogCollector`

Queries a SQL database for access logs. Uses a raw connection interface — inject your own database handle.

```dart
final collector = DatabaseLogCollector(
  query: 'SELECT * FROM access_logs WHERE login_at >= ? AND login_at <= ?',
  connectionFactory: () => openDatabase('/data/app.db'),
  rowMapper: (row) => AccessLog(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    ipAddress: row['ip_address'] as String,
    loginAt: DateTime.parse(row['login_at'] as String),
    status: LoginStatus.values.byName(row['status'] as String),
  ),
);
```

---

## `HttpLogCollector`

Fetches logs from a REST API endpoint. Supports pagination, retries, and custom parsers.

```dart
final collector = HttpLogCollector(
  baseUrl: 'https://api.myapp.com/audit-logs',
  headers: {
    'Authorization': 'Bearer $token',
    'X-Tenant-ID': tenantId,
  },
  timeout: const Duration(seconds: 30),
  maxRetries: 2,
  // Optional: custom query parameter builder
  buildQueryParameters: (from, to, userId, ipAddress, limit, offset) => {
    'start': from.millisecondsSinceEpoch.toString(),
    'end': to.millisecondsSinceEpoch.toString(),
    if (userId != null) 'user': userId,
  },
  // Optional: custom JSON-to-AccessLog parser
  customParser: (json) => AccessLog.fromJson(json),
);
```

### Expected API Response Formats

The collector automatically handles:
- JSON array: `[{...}, {...}]`
- JSON envelope with `data`, `items`, `logs`, `results`, or `records` key:
  ```json
  { "data": [{...}, {...}], "total": 1234 }
  ```

### Retry Behaviour

On HTTP 5xx or timeout, the collector retries up to `maxRetries` times with exponential backoff (1s, 2s).

---

## `BaseLogCollector` Interface

```dart
abstract class BaseLogCollector {
  /// Fetch access logs in the [from, to] time range.
  Future<List<AccessLog>> collect({
    required DateTime from,
    required DateTime to,
    String? userId,
    String? ipAddress,
    int? limit,
    int? offset,
  });

  /// Return the total count of entries (may return -1 if not supported).
  Future<int> count({
    required DateTime from,
    required DateTime to,
  });

  /// Check whether the data source is reachable.
  Future<bool> isAvailable();
}
```
