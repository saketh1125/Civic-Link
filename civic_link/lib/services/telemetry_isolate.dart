/// 50Hz IMU Telemetry Engine for Civic-Link
///
/// Background isolate service that reads hardware IMU sensors at 50Hz,
/// batches readings, and transmits via HTTP without blocking the UI thread.
///
/// Architecture: _TelemetryWorker class encapsulates all mutable state and
/// logic. The isolate entry point is a thin message router.

import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:sensors_plus/sensors_plus.dart';

// =============================================================================
// CONSTANTS
// =============================================================================

const int _maxRetryQueueSize = 50;

// =============================================================================
// DATA MODELS
// =============================================================================

class IMUReading {
  final DateTime timestamp;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  const IMUReading({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  });

  Map<String, dynamic> toJson() => {
        'timestamp_ms': timestamp.millisecondsSinceEpoch,
        'accel_x': accelX,
        'accel_y': accelY,
        'accel_z': accelZ,
        'gyro_x': gyroX,
        'gyro_y': gyroY,
        'gyro_z': gyroZ,
      };
}

class TelemetryBatch {
  final String userId;
  final String? matchId;
  final List<IMUReading> readings;

  const TelemetryBatch({
    required this.userId,
    this.matchId,
    required this.readings,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'match_id': matchId,
        'readings': readings.map((r) => r.toJson()).toList(),
      };

  int get length => readings.length;
  bool get isEmpty => readings.isEmpty;
}

// =============================================================================
// ISOLATE COMMUNICATION PROTOCOL
// =============================================================================

sealed class TelemetryCommand {}

class StartTelemetry extends TelemetryCommand {
  final String baseUrl;
  final String authToken;
  final String userId;
  final String? matchId;
  final int batchSize;
  final int flushIntervalMs;

  StartTelemetry({
    required this.baseUrl,
    required this.authToken,
    required this.userId,
    this.matchId,
    this.batchSize = 10,
    this.flushIntervalMs = 200,
  });
}

class StopTelemetry extends TelemetryCommand {}

class UpdateToken extends TelemetryCommand {
  final String newToken;
  UpdateToken(this.newToken);
}

class IngestTelemetry extends TelemetryCommand {
  final String tripId;
  final List<Map<String, dynamic>> samples;
  IngestTelemetry({required this.tripId, required this.samples});
}

sealed class TelemetryStatus {}

class TelemetryStarted extends TelemetryStatus {}

class TelemetryStopped extends TelemetryStatus {}

class TokenUpdated extends TelemetryStatus {}

class ScoreUpdate extends TelemetryStatus {
  final double score;
  ScoreUpdate(this.score);
}

class TelemetryError extends TelemetryStatus {
  final String message;
  final bool isFatal;
  TelemetryError(this.message, {this.isFatal = false});
}

class BatchTransmitted extends TelemetryStatus {
  final int batchSize;
  final int retryQueueSize;
  BatchTransmitted(this.batchSize, this.retryQueueSize);
}

class BatchRetryQueued extends TelemetryStatus {
  final int batchSize;
  final String error;
  final int retryQueueSize;
  BatchRetryQueued(this.batchSize, this.error, this.retryQueueSize);
}

class BatchesDropped extends TelemetryStatus {
  final int droppedCount;
  BatchesDropped(this.droppedCount);
}

class ScoreIngested extends TelemetryStatus {
  final double civicScore;
  final double delta;
  final String tier;
  ScoreIngested(this.civicScore, this.delta, this.tier);
}

// =============================================================================
// PRIVATE STATE WRAPPER CLASS
// =============================================================================

/// Encapsulates all mutable isolate state and processing logic.
///
/// Because this is a class (not a closure), all methods are visible
/// throughout the entire class body — no hoisting or forward-reference
/// issues are possible.
class _TelemetryWorker {
  final Dio dio;
  final String baseUrl;
  String authToken;
  final String userId;
  final String? matchId;
  final int batchSize;
  final int flushIntervalMs;
  final SendPort sendPort;

  // Sensor state
  double accelX = 0, accelY = 0, accelZ = 0;
  double gyroX = 0, gyroY = 0, gyroZ = 0;
  bool hasAccel = false;
  bool hasGyro = false;
  double currentScore = 100.0;

  // Buffers
  final List<IMUReading> activeBuffer = [];
  final List<TelemetryBatch> retryQueue = [];

  // Subscriptions & timer
  StreamSubscription? accelSub;
  StreamSubscription? gyroSub;
  Timer? flushTimer;

  _TelemetryWorker({
    required this.dio,
    required this.baseUrl,
    required this.authToken,
    required this.userId,
    this.matchId,
    required this.batchSize,
    required this.flushIntervalMs,
    required this.sendPort,
  });

  // -------------------------------------------------------------------------
  // SENSOR LISTENER SETUP
  // -------------------------------------------------------------------------
  void initListeners() {
    accelSub = userAccelerometerEventStream().listen(
      (event) {
        accelX = event.x;
        accelY = event.y;
        accelZ = event.z;
        hasAccel = true;
      },
      onError: (e) => sendPort.send(TelemetryError('Accel error: $e')),
    );

    gyroSub = gyroscopeEventStream().listen(
      (event) {
        gyroX = event.x;
        gyroY = event.y;
        gyroZ = event.z;
        hasGyro = true;

        final eventScore = (gyroZ > 1.5 || gyroZ < -1.5) ? 30.0 : 100.0;
        currentScore = (currentScore * 0.85) + (eventScore * 0.15);
        sendPort.send(ScoreUpdate(currentScore));
      },
      onError: (e) => sendPort.send(TelemetryError('Gyro error: $e')),
    );

    flushTimer = Timer.periodic(
      Duration(milliseconds: flushIntervalMs ~/ (batchSize ~/ 10)),
      (_) => sampleAndBuffer(),
    );
  }

  // -------------------------------------------------------------------------
  // SAMPLING
  // -------------------------------------------------------------------------
  void sampleAndBuffer() {
    if (!hasAccel && !hasGyro) return;

    activeBuffer.add(IMUReading(
      timestamp: DateTime.now(),
      accelX: accelX,
      accelY: accelY,
      accelZ: accelZ,
      gyroX: gyroX,
      gyroY: gyroY,
      gyroZ: gyroZ,
    ));

    if (activeBuffer.length >= batchSize) {
      transmitBatch();
    }
  }

  // -------------------------------------------------------------------------
  // TRANSMISSION
  // -------------------------------------------------------------------------
  Future<void> transmitBatch() async {
    if (activeBuffer.isEmpty || authToken == null) return;

    final currentBatch = TelemetryBatch(
      userId: userId,
      matchId: matchId,
      readings: List.from(activeBuffer),
    );
    activeBuffer.clear();

    final payload = currentBatch.toJson();

    try {
      await dio.post(
        '/api/v1/telemetry/telemetry',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );

      sendPort.send(BatchTransmitted(currentBatch.length, retryQueue.length));
    } on DioException catch (e) {
      final isRetryable = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          (e.response?.statusCode != null && e.response!.statusCode! >= 500);

      if (isRetryable) {
        retryQueue.addAll([currentBatch]);

        int droppedCount = 0;
        while (retryQueue.length > _maxRetryQueueSize) {
          retryQueue.removeAt(0);
          droppedCount++;
        }

        if (droppedCount > 0) {
          sendPort.send(BatchesDropped(droppedCount));
        }

        sendPort.send(BatchRetryQueued(
          currentBatch.readings.length,
          e.message ?? 'Network error',
          retryQueue.length,
        ));
      } else {
        sendPort.send(TelemetryError(
          'Non-retryable error: ${e.response?.statusCode} - ${e.message}',
        ));
      }
    } catch (e) {
      retryQueue.addAll([currentBatch]);

      int droppedCount = 0;
      while (retryQueue.length > _maxRetryQueueSize) {
        retryQueue.removeAt(0);
        droppedCount++;
      }

      if (droppedCount > 0) {
        sendPort.send(BatchesDropped(droppedCount));
      }

      sendPort.send(BatchRetryQueued(
        currentBatch.readings.length,
        'Unexpected error: $e',
        retryQueue.length,
      ));
    }
  }

  // -------------------------------------------------------------------------
  // INGESTION TO BACKEND
  // -------------------------------------------------------------------------
  Future<void> ingestToBackend(
    String tripId,
    List<Map<String, dynamic>> samples,
  ) async {
    if (samples.isEmpty || authToken.isEmpty) return;

    final payload = {
      'trip_id': tripId,
      'samples': samples,
    };

    try {
      final response = await dio.post(
        '/api/v1/civic-score/ingest',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map;
        sendPort.send(ScoreIngested(
          (data['civic_score'] as num).toDouble(),
          (data['delta'] as num).toDouble(),
          data['tier'] as String,
        ));
      }
    } on DioException catch (e) {
      sendPort.send(TelemetryError(
        'Score ingestion failed: ${e.message}',
      ));
    } catch (e) {
      sendPort.send(TelemetryError(
        'Unexpected ingestion error: $e',
      ));
    }
  }

  // -------------------------------------------------------------------------
  // FINAL FLUSH
  // -------------------------------------------------------------------------
  Future<void> finalFlush() async {
    if (activeBuffer.isNotEmpty || retryQueue.isNotEmpty) {
      await transmitBatch();
    }
  }

  // -------------------------------------------------------------------------
  // DISPOSE
  // -------------------------------------------------------------------------
  Future<void> dispose() async {
    await accelSub?.cancel();
    await gyroSub?.cancel();
    flushTimer?.cancel();
    dio.close();
  }
}

// =============================================================================
// ISOLATE ENTRY POINT
// =============================================================================

void _telemetryIsolateEntry(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  _TelemetryWorker? worker;

  receivePort.listen((message) {
    if (message is StartTelemetry) {
      worker = _TelemetryWorker(
        dio: Dio(BaseOptions(
          baseUrl: message.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        )),
        baseUrl: message.baseUrl,
        authToken: message.authToken,
        userId: message.userId,
        matchId: message.matchId,
        batchSize: message.batchSize,
        flushIntervalMs: message.flushIntervalMs,
        sendPort: sendPort,
      );
      worker!.initListeners();
      sendPort.send(TelemetryStarted());
    } else if (message is UpdateToken) {
      worker?.authToken = message.newToken;
      sendPort.send(TokenUpdated());
    } else if (message is StopTelemetry) {
      worker?.dispose();
      sendPort.send(TelemetryStopped());
      Isolate.current.kill();
    } else if (message is IngestTelemetry) {
      worker?.ingestToBackend(message.tripId, message.samples);
    }
  });
}

// =============================================================================
// TELEMETRY SERVICE (MAIN ISOLATE API)
// =============================================================================

class TelemetryService {
  final String baseUrl;
  final String userId;
  final String? matchId;
  String _authToken;
  final int batchSize;
  final int flushIntervalMs;
  final void Function(double)? onScoreUpdate;

  Isolate? _isolate;
  SendPort? _commandPort;
  final ReceivePort _statusPort = ReceivePort();
  StreamSubscription? _statusSubscription;

  final StreamController<TelemetryStatus> _statusController =
      StreamController<TelemetryStatus>.broadcast();

  Stream<TelemetryStatus> get statusStream => _statusController.stream;

  TelemetryService({
    required this.baseUrl,
    required this.userId,
    this.matchId,
    required String authToken,
    this.batchSize = 10,
    this.flushIntervalMs = 200,
    this.onScoreUpdate,
  }) : _authToken = authToken;

  Future<void> start() async {
    if (_isolate != null) {
      throw StateError('Telemetry isolate already running');
    }

    final completer = Completer<void>();

    _statusSubscription = _statusPort.listen((message) {
      if (message is SendPort) {
        _commandPort = message;

        _commandPort!.send(StartTelemetry(
          baseUrl: baseUrl,
          authToken: _authToken,
          userId: userId,
          matchId: matchId,
          batchSize: batchSize,
          flushIntervalMs: flushIntervalMs,
        ));
      } else if (message is TelemetryStatus) {
        if (message is ScoreUpdate) {
          onScoreUpdate?.call(message.score);
        }

        _statusController.add(message);

        if (message is TelemetryStarted && !completer.isCompleted) {
          completer.complete();
        } else if (message is TelemetryError && message.isFatal) {
          if (!completer.isCompleted) {
            completer.completeError(message.message);
          }
        }
      }
    });

    _isolate = await Isolate.spawn(
      _telemetryIsolateEntry,
      _statusPort.sendPort,
      debugName: 'TelemetryIsolate',
    );

    return completer.future;
  }

  Future<void> stop() async {
    if (_isolate == null) return;

    final completer = Completer<void>();

    late StreamSubscription<TelemetryStatus> sub;
    sub = _statusController.stream.listen((status) {
      if (status is TelemetryStopped) {
        sub.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    _commandPort?.send(StopTelemetry());

    await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _isolate?.kill(priority: Isolate.immediate);
      },
    );

    await _statusSubscription?.cancel();
    _statusPort.close();
    _isolate = null;
    _commandPort = null;
  }

  void updateToken(String newToken) {
    _authToken = newToken;
    _commandPort?.send(UpdateToken(newToken));
  }

  Future<void> ingestScore({
    required String tripId,
    required List<Map<String, dynamic>> samples,
  }) async {
    if (_commandPort == null) return;
    _commandPort!.send(IngestTelemetry(tripId: tripId, samples: samples));
  }

  bool get isRunning => _isolate != null;
}