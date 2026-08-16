library;

// Expose the main orchestrator
export 'src/engine/download_engine.dart';
export 'src/engine/isolated_download_engine.dart';

// Expose all public data models
export 'src/models/download_error.dart';
export 'src/models/download_metadata.dart';
export 'src/models/download_progress.dart';
export 'src/models/download_request.dart';
export 'src/models/download_result.dart';
export 'src/models/download_status.dart';
export 'src/models/download_task.dart';
export 'src/models/retry_config.dart';

// Expose the transport abstraction so users can build custom network layers
export 'src/transport/download_transport.dart';
export 'src/transport/dart_http_transport.dart';
