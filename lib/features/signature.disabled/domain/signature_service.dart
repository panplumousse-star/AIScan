import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hand_signature/signature.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/storage/database_helper.dart';
import '../../../core/security/encryption_service.dart';

/// Riverpod provider for [SignatureService].
///
/// Provides a singleton instance of the signature service for
/// dependency injection throughout the application.
final signatureServiceProvider = Provider<SignatureService>((ref) {
  final databaseHelper = ref.read(databaseHelperProvider);
  final encryptionService = ref.read(encryptionServiceProvider);
  return SignatureService(
    databaseHelper: databaseHelper,
    encryptionService: encryptionService,
  );
});

/// Exception thrown when signature operations fail.
///
/// Contains the original error message and optional underlying exception.
class SignatureException implements Exception {
  /// Creates a [SignatureException] with the given [message].
  const SignatureException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'SignatureException: $message (caused by: $cause)';
    }
    return 'SignatureException: $message';
  }
}

/// A saved signature stored in the database.
///
/// Contains the signature image data, SVG representation, and metadata.
@immutable
class SavedSignature {
  /// Creates a [SavedSignature] with the given properties.
  const SavedSignature({
    required this.id,
    required this.label,
    required this.signaturePath,
    this.svgData,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a [SavedSignature] from a database map.
  factory SavedSignature.fromMap(Map<String, dynamic> map) {
    return SavedSignature(
      id: map[DatabaseHelper.columnId] as String,
      label: map[DatabaseHelper.columnLabel] as String,
      signaturePath: map[DatabaseHelper.columnSignaturePath] as String,
      svgData: map[DatabaseHelper.columnSvgData] as String?,
      isDefault: (map[DatabaseHelper.columnIsDefault] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map[DatabaseHelper.columnCreatedAt] as String),
      updatedAt: DateTime.parse(map[DatabaseHelper.columnUpdatedAt] as String),
    );
  }

  /// Unique identifier for the signature.
  final String id;

  /// User-provided label for the signature.
  final String label;

  /// Path to the encrypted signature image file.
  final String signaturePath;

  /// SVG representation of the signature for scalable rendering.
  final String? svgData;

  /// Whether this is the default signature.
  final bool isDefault;

  /// When the signature was created.
  final DateTime createdAt;

  /// When the signature was last updated.
  final DateTime updatedAt;

  /// Whether this signature has SVG data.
  bool get hasSvgData => svgData != null && svgData!.isNotEmpty;

  /// Converts this signature to a database map.
  Map<String, dynamic> toMap() {
    return {
      DatabaseHelper.columnId: id,
      DatabaseHelper.columnLabel: label,
      DatabaseHelper.columnSignaturePath: signaturePath,
      DatabaseHelper.columnSvgData: svgData,
      DatabaseHelper.columnIsDefault: isDefault ? 1 : 0,
      DatabaseHelper.columnCreatedAt: createdAt.toIso8601String(),
      DatabaseHelper.columnUpdatedAt: updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated values.
  SavedSignature copyWith({
    String? id,
    String? label,
    String? signaturePath,
    String? svgData,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearSvgData = false,
  }) {
    return SavedSignature(
      id: id ?? this.id,
      label: label ?? this.label,
      signaturePath: signaturePath ?? this.signaturePath,
      svgData: clearSvgData ? null : (svgData ?? this.svgData),
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedSignature &&
        other.id == id &&
        other.label == label &&
        other.signaturePath == signaturePath &&
        other.svgData == svgData &&
        other.isDefault == isDefault &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    signaturePath,
    svgData,
    isDefault,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'SavedSignature('
      'id: $id, '
      'label: $label, '
      'isDefault: $isDefault)';
}

/// Configuration options for signature rendering.
///
/// Controls how the signature is drawn and exported.
@immutable
class SignatureOptions {
  /// Creates [SignatureOptions] with specified parameters.
  const SignatureOptions({
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
    this.backgroundColor = Colors.transparent,
    this.threshold = 0.01,
    this.smoothRatio = 0.65,
    this.velocityRange = 2.0,
    this.exportWidth,
    this.exportHeight,
    this.maxStrokeWidth = 6.0,
    this.minStrokeWidth = 1.0,
    this.fit = true,
  });

  /// Creates options optimized for document signing.
  const SignatureOptions.document()
    : strokeColor = Colors.black,
      strokeWidth = 2.0,
      backgroundColor = Colors.transparent,
      threshold = 0.01,
      smoothRatio = 0.65,
      velocityRange = 2.0,
      exportWidth = null,
      exportHeight = null,
      maxStrokeWidth = 6.0,
      minStrokeWidth = 1.0,
      fit = true;

  /// Creates options for a thicker, more visible signature.
  const SignatureOptions.bold()
    : strokeColor = Colors.black,
      strokeWidth = 4.0,
      backgroundColor = Colors.transparent,
      threshold = 0.01,
      smoothRatio = 0.65,
      velocityRange = 2.5,
      exportWidth = null,
      exportHeight = null,
      maxStrokeWidth = 10.0,
      minStrokeWidth = 2.0,
      fit = true;

  /// Creates options for a fine, precise signature.
  const SignatureOptions.fine()
    : strokeColor = Colors.black,
      strokeWidth = 1.0,
      backgroundColor = Colors.transparent,
      threshold = 0.005,
      smoothRatio = 0.8,
      velocityRange = 1.5,
      exportWidth = null,
      exportHeight = null,
      maxStrokeWidth = 3.0,
      minStrokeWidth = 0.5,
      fit = true;

  /// Creates options with a blue ink appearance.
  const SignatureOptions.blueInk()
    : strokeColor = const Color(0xFF1A237E),
      strokeWidth = 2.0,
      backgroundColor = Colors.transparent,
      threshold = 0.01,
      smoothRatio = 0.65,
      velocityRange = 2.0,
      exportWidth = null,
      exportHeight = null,
      maxStrokeWidth = 6.0,
      minStrokeWidth = 1.0,
      fit = true;

  /// The color of the signature stroke.
  final Color strokeColor;

  /// Base stroke width in logical pixels.
  final double strokeWidth;

  /// Background color for the signature.
  final Color backgroundColor;

  /// Threshold for recognizing new points (lower = more sensitive).
  final double threshold;

  /// Smoothing ratio for Bezier curves (0.0 - 1.0).
  final double smoothRatio;

  /// Range of velocity-based stroke variation.
  final double velocityRange;

  /// Width of exported image (null = auto-fit).
  final int? exportWidth;

  /// Height of exported image (null = auto-fit).
  final int? exportHeight;

  /// Maximum stroke width based on velocity.
  final double maxStrokeWidth;

  /// Minimum stroke width based on velocity.
  final double minStrokeWidth;

  /// Whether to fit the signature to the export bounds.
  final bool fit;

  /// Creates [HandSignatureControl] with these options.
  HandSignatureControl createControl() {
    return HandSignatureControl(
      threshold: threshold,
      smoothRatio: smoothRatio,
      velocityRange: velocityRange,
    );
  }

  /// Creates a copy with updated values.
  SignatureOptions copyWith({
    Color? strokeColor,
    double? strokeWidth,
    Color? backgroundColor,
    double? threshold,
    double? smoothRatio,
    double? velocityRange,
    int? exportWidth,
    int? exportHeight,
    double? maxStrokeWidth,
    double? minStrokeWidth,
    bool? fit,
    bool clearExportWidth = false,
    bool clearExportHeight = false,
  }) {
    return SignatureOptions(
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      threshold: threshold ?? this.threshold,
      smoothRatio: smoothRatio ?? this.smoothRatio,
      velocityRange: velocityRange ?? this.velocityRange,
      exportWidth: clearExportWidth ? null : (exportWidth ?? this.exportWidth),
      exportHeight: clearExportHeight
          ? null
          : (exportHeight ?? this.exportHeight),
      maxStrokeWidth: maxStrokeWidth ?? this.maxStrokeWidth,
      minStrokeWidth: minStrokeWidth ?? this.minStrokeWidth,
      fit: fit ?? this.fit,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SignatureOptions &&
        other.strokeColor == strokeColor &&
        other.strokeWidth == strokeWidth &&
        other.backgroundColor == backgroundColor &&
        other.threshold == threshold &&
        other.smoothRatio == smoothRatio &&
        other.velocityRange == velocityRange &&
        other.exportWidth == exportWidth &&
        other.exportHeight == exportHeight &&
        other.maxStrokeWidth == maxStrokeWidth &&
        other.minStrokeWidth == minStrokeWidth &&
        other.fit == fit;
  }

  @override
  int get hashCode => Object.hash(
    strokeColor,
    strokeWidth,
    backgroundColor,
    threshold,
    smoothRatio,
    velocityRange,
    exportWidth,
    exportHeight,
    maxStrokeWidth,
    minStrokeWidth,
    fit,
  );
}

/// Result of a signature capture operation.
///
/// Contains the signature in multiple formats for different use cases.
@immutable
class CapturedSignature {
  /// Creates a [CapturedSignature] with the captured data.
  const CapturedSignature({
    required this.pngBytes,
    this.svgData,
    required this.width,
    required this.height,
    required this.strokeColor,
  });

  /// The signature as PNG image bytes with transparent background.
  final Uint8List pngBytes;

  /// The signature as SVG string for scalable rendering.
  final String? svgData;

  /// Width of the captured signature in pixels.
  final int width;

  /// Height of the captured signature in pixels.
  final int height;

  /// The color used for the signature stroke.
  final Color strokeColor;

  /// Whether the signature has SVG data.
  bool get hasSvgData => svgData != null && svgData!.isNotEmpty;

  /// Gets the file size of the PNG in bytes.
  int get pngSize => pngBytes.length;

  /// Gets a formatted string of the PNG size.
  String get pngSizeFormatted {
    if (pngSize < 1024) {
      return '$pngSize B';
    } else if (pngSize < 1024 * 1024) {
      return '${(pngSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(pngSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CapturedSignature &&
        listEquals(other.pngBytes, pngBytes) &&
        other.svgData == svgData &&
        other.width == width &&
        other.height == height &&
        other.strokeColor == strokeColor;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(pngBytes),
    svgData,
    width,
    height,
    strokeColor,
  );

  @override
  String toString() =>
      'CapturedSignature('
      'size: ${width}x$height, '
      'pngSize: $pngSizeFormatted, '
      'hasSvg: $hasSvgData)';
}

/// Result of overlaying a signature on a document.
@immutable
class SignedDocument {
  /// Creates a [SignedDocument] with the result data.
  const SignedDocument({
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.signaturePosition,
    required this.signatureSize,
  });

  /// The signed document as image bytes.
  final Uint8List imageBytes;

  /// Width of the document in pixels.
  final int width;

  /// Height of the document in pixels.
  final int height;

  /// Position where the signature was placed.
  final Offset signaturePosition;

  /// Size of the signature on the document.
  final Size signatureSize;

  @override
  String toString() =>
      'SignedDocument('
      'size: ${width}x$height, '
      'signatureAt: $signaturePosition)';
}

/// Service for capturing, saving, and managing electronic signatures.
///
/// Uses the hand_signature package for smooth, velocity-sensitive
/// signature capture with natural-looking strokes.
///
/// ## Key Features
/// - **Smooth Capture**: Velocity-based stroke thickness for natural signatures
/// - **Multiple Formats**: Export as PNG (for overlay) or SVG (for scaling)
/// - **Secure Storage**: Signatures encrypted at rest
/// - **Multiple Signatures**: Save and manage multiple signatures
/// - **Document Overlay**: Apply signatures to scanned documents
///
/// ## Usage
/// ```dart
/// final signatureService = ref.read(signatureServiceProvider);
///
/// // Initialize the service
/// await signatureService.initialize();
///
/// // Create a signature control for the UI
/// final control = signatureService.createControl();
///
/// // In your widget, use HandSignaturePad with the control
/// // After user draws signature, capture it:
/// final captured = await signatureService.captureSignature(control);
///
/// // Save the signature
/// final saved = await signatureService.saveSignature(
///   captured,
///   label: 'My Signature',
///   setAsDefault: true,
/// );
///
/// // Later, apply to a document
/// final signedDoc = await signatureService.overlaySignatureOnDocument(
///   documentBytes: documentImageBytes,
///   signatureBytes: captured.pngBytes,
///   position: Offset(100, 500),
///   signatureWidth: 200,
/// );
/// ```
///
/// ## Error Handling
/// The service throws [SignatureException] for all error cases.
/// Always wrap calls in try-catch:
/// ```dart
/// try {
///   final captured = await signatureService.captureSignature(control);
///   // Use captured...
/// } on SignatureException catch (e) {
///   print('Signature capture failed: ${e.message}');
/// }
/// ```
class SignatureService {
  /// Creates a [SignatureService] instance.
  SignatureService({
    required DatabaseHelper databaseHelper,
    required EncryptionService encryptionService,
  }) : _databaseHelper = databaseHelper,
       _encryptionService = encryptionService;

  final DatabaseHelper _databaseHelper;
  final EncryptionService _encryptionService;

  /// UUID generator for signature IDs.
  final _uuid = const Uuid();

  /// Whether the service has been initialized.
  bool _isInitialized = false;

  /// Path to the signatures directory.
  String? _signaturesPath;

  /// Whether the service has been initialized and is ready for use.
  bool get isReady => _isInitialized && _signaturesPath != null;

  /// Initializes the signature service.
  ///
  /// This must be called before any signature operations. It:
  /// 1. Creates the signatures directory for storing signature images
  /// 2. Verifies database connectivity
  ///
  /// Returns true if initialization was successful.
  ///
  /// Throws [SignatureException] if initialization fails.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Get the app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final signaturesDir = Directory(p.join(appDir.path, 'signatures'));

      // Create signatures directory if it doesn't exist
      if (!await signaturesDir.exists()) {
        await signaturesDir.create(recursive: true);
      }

      _signaturesPath = signaturesDir.path;
      _isInitialized = true;

      debugPrint('Signature Service initialized at: $_signaturesPath');

      return true;
    } catch (e) {
      throw SignatureException(
        'Failed to initialize signature service',
        cause: e,
      );
    }
  }

  /// Creates a new [HandSignatureControl] for signature capture.
  ///
  /// The control should be used with [HandSignaturePad] widget
  /// for capturing user signatures.
  ///
  /// The [options] parameter allows customizing the capture behavior.
  /// If not specified, [SignatureOptions.document] is used.
  ///
  /// Example:
  /// ```dart
  /// final control = signatureService.createControl();
  ///
  /// // In your widget:
  /// HandSignaturePad(
  ///   control: control,
  ///   color: Colors.black,
  ///   width: 2.0,
  ///   type: SignatureDrawType.shape,
  /// )
  /// ```
  HandSignatureControl createControl({
    SignatureOptions options = const SignatureOptions.document(),
  }) {
    return options.createControl();
  }

  /// Captures the current signature from a [HandSignatureControl].
  ///
  /// Returns a [CapturedSignature] containing the signature in
  /// PNG format (for document overlay) and SVG format (for scaling).
  ///
  /// The [control] must contain a valid signature (not empty).
  ///
  /// The [options] parameter controls export settings like color
  /// and dimensions.
  ///
  /// Throws [SignatureException] if:
  /// - The control has no signature data
  /// - Image conversion fails
  ///
  /// Example:
  /// ```dart
  /// // After user draws signature
  /// final captured = await signatureService.captureSignature(
  ///   control,
  ///   options: const SignatureOptions.document(),
  /// );
  /// print('Captured ${captured.pngSizeFormatted} signature');
  /// ```
  Future<CapturedSignature> captureSignature(
    HandSignatureControl control, {
    SignatureOptions options = const SignatureOptions.document(),
  }) async {
    if (control.isEmpty) {
      throw const SignatureException(
        'Cannot capture empty signature. Draw a signature first.',
      );
    }

    try {
      // Capture as PNG with transparent background
      final pngBytes = await control.toImage(
        color: options.strokeColor,
        background: options.backgroundColor,
        fit: options.fit,
        maxStrokeWidth: options.maxStrokeWidth,
        exportPenColor: true,
      );

      if (pngBytes == null || pngBytes.isEmpty) {
        throw const SignatureException('Failed to capture signature as image');
      }

      // Capture as SVG for scalable graphics
      String? svgData;
      try {
        svgData = control.toSvg(
          color: options.strokeColor,
          fit: options.fit,
          maxStrokeWidth: options.maxStrokeWidth,
          exportPenColor: true,
        );
      } catch (e) {
        // SVG capture failed, but PNG succeeded - continue without SVG
        debugPrint('Warning: SVG capture failed: $e');
      }

      // Decode PNG to get dimensions
      final image = img.decodePng(pngBytes);
      if (image == null) {
        throw const SignatureException('Failed to decode captured signature');
      }

      return CapturedSignature(
        pngBytes: pngBytes,
        svgData: svgData,
        width: image.width,
        height: image.height,
        strokeColor: options.strokeColor,
      );
    } catch (e) {
      if (e is SignatureException) rethrow;
      throw SignatureException('Failed to capture signature', cause: e);
    }
  }

  /// Saves a captured signature to the database and storage.
  ///
  /// The signature image is encrypted before storage for security.
  ///
  /// The [signature] must be a valid [CapturedSignature] from
  /// [captureSignature].
  ///
  /// The [label] is a user-friendly name for the signature.
  ///
  /// Set [setAsDefault] to true to make this the default signature.
  /// Only one signature can be default at a time.
  ///
  /// Returns the [SavedSignature] with database ID and metadata.
  ///
  /// Throws [SignatureException] if saving fails.
  ///
  /// Example:
  /// ```dart
  /// final saved = await signatureService.saveSignature(
  ///   captured,
  ///   label: 'Professional Signature',
  ///   setAsDefault: true,
  /// );
  /// print('Saved signature: ${saved.id}');
  /// ```
  Future<SavedSignature> saveSignature(
    CapturedSignature signature, {
    required String label,
    bool setAsDefault = false,
  }) async {
    if (!isReady) {
      throw const SignatureException(
        'Signature service not initialized. Call initialize() first.',
      );
    }

    if (label.trim().isEmpty) {
      throw const SignatureException('Signature label cannot be empty');
    }

    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      // Save encrypted signature image
      final signaturePath = p.join(_signaturesPath!, '$id.png.enc');
      await _encryptionService.encryptFile(signature.pngBytes, signaturePath);

      // If setting as default, clear other defaults first
      if (setAsDefault) {
        await _clearDefaultSignature();
      }

      // Create saved signature record
      final savedSignature = SavedSignature(
        id: id,
        label: label.trim(),
        signaturePath: signaturePath,
        svgData: signature.svgData,
        isDefault: setAsDefault,
        createdAt: now,
        updatedAt: now,
      );

      // Insert into database
      await _databaseHelper.insert(
        DatabaseHelper.tableSignatures,
        savedSignature.toMap(),
      );

      debugPrint('Saved signature: $id (${label.trim()})');

      return savedSignature;
    } catch (e) {
      if (e is SignatureException) rethrow;
      throw SignatureException('Failed to save signature', cause: e);
    }
  }

  /// Gets all saved signatures from the database.
  ///
  /// Returns a list of [SavedSignature] sorted by creation date
  /// (newest first), with default signature at the beginning.
  ///
  /// Throws [SignatureException] if database query fails.
  Future<List<SavedSignature>> getAllSignatures() async {
    if (!isReady) {
      throw const SignatureException(
        'Signature service not initialized. Call initialize() first.',
      );
    }

    try {
      final results = await _databaseHelper.query(
        DatabaseHelper.tableSignatures,
        orderBy:
            '${DatabaseHelper.columnIsDefault} DESC, ${DatabaseHelper.columnCreatedAt} DESC',
      );

      return results.map((map) => SavedSignature.fromMap(map)).toList();
    } catch (e) {
      throw SignatureException('Failed to get signatures', cause: e);
    }
  }

  /// Gets a single signature by ID.
  ///
  /// Returns the [SavedSignature] if found, null otherwise.
  ///
  /// Throws [SignatureException] if database query fails.
  Future<SavedSignature?> getSignature(String id) async {
    if (!isReady) {
      throw const SignatureException(
        'Signature service not initialized. Call initialize() first.',
      );
    }

    if (id.isEmpty) {
      throw const SignatureException('Signature ID cannot be empty');
    }

    try {
      final results = await _databaseHelper.query(
        DatabaseHelper.tableSignatures,
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isEmpty) return null;

      return SavedSignature.fromMap(results.first);
    } catch (e) {
      throw SignatureException('Failed to get signature', cause: e);
    }
  }

  /// Gets the default signature, if one is set.
  ///
  /// Returns the default [SavedSignature] if found, null otherwise.
  ///
  /// Throws [SignatureException] if database query fails.
  Future<SavedSignature?> getDefaultSignature() async {
    if (!isReady) {
      throw const SignatureException(
        'Signature service not initialized. Call initialize() first.',
      );
    }

    try {
      final results = await _databaseHelper.query(
        DatabaseHelper.tableSignatures,
        where: '${DatabaseHelper.columnIsDefault} = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (results.isEmpty) return null;

      return SavedSignature.fromMap(results.first);
    } catch (e) {
      throw SignatureException('Failed to get default signature', cause: e);
    }
  }

  /// Gets the number of saved signatures.
  ///
  /// Returns the count of signatures in the database.
  Future<int> getSignatureCount() async {
    if (!isReady) {
      throw const SignatureException(
        'Signature service not initialized. Call initialize() first.',
      );
    }

    try {
      final results = await _databaseHelper.query(
        DatabaseHelper.tableSignatures,
        columns: ['COUNT(*) as count'],
      );

      return results.first['count'] as int? ?? 0;
    } catch (e) {
      throw SignatureException('Failed to get signature count', cause: e);
    }
  }

  /// Updates a signature's label.
  ///
  /// Returns the updated [SavedSignature].
  ///
  /// Throws [SignatureException] if the signature is not found or
  /// update fails.
  Future<SavedSignature> updateSignatureLabel(
    String id,
    String newLabel,
  ) async {
    if (!isReady) {
      throw const SignatureException(
        'Signature service not initialized. Call initialize() first.',
      );
    }

    if (newLabel.trim().isEmpty) {
      throw const SignatureException('Signature label cannot be empty');
    }

    try {
      final signature = await getSignature(id);
      if (signature == null) {
        throw SignatureException('Signature not found: $id');
      }

      final now = DateTime.now();
      await _databaseHelper.update(
        DatabaseHelper.tableSignatures,
        {
          DatabaseHelper.columnLabel: newLabel.trim(),
          DatabaseHelper.columnUpdatedAt: now.toIso8601String(),
        },
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [id],
      );

      return signature.copyWith(label: newLabel.trim(), updatedAt: now);
    } catch (e) {
      if (e is SignatureException) rethrow;
      throw SignatureException('Failed to update signature label', cause: e);
    }
  }

  /// Sets a signature as the default.
  ///
  /// Only one signature can be default at a time. Setting a new
  /// default will clear the previous default.
  ///
  /// Returns the updated [SavedSignature].
  ///
  /// Throws [SignatureException] if the signature is not found or
  /// update fails.
  Future<SavedSignature> setDefaultSignature(String id) async {
    if (!isReady) {
      throw const SignatureException(
        'Signature service not initialized. Call initialize() first.',
      );
    }

    try {
      final signature = await getSignature(id);
      if (signature == null) {
        throw SignatureException('Signature not found: $id');
      }

      // Clear existing default
      await _clearDefaultSignature();

      // Set new default
      final now = DateTime.now();
      await _databaseHelper.update(
        DatabaseHelper.tableSignatures,
        {
          DatabaseHelper.columnIsDefault: 1,
          DatabaseHelper.columnUpdatedAt: now.toIso8601String(),
        },
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [id],
      );

      return signature.copyWith(isDefault: true, updatedAt: now);
    } catch (e) {
      if (e is SignatureException) rethrow;
      throw SignatureException('Failed to set default signature', cause: e);
    }
  }

  /// Clears the default signature.
  ///
  /// After calling this, no signature will be marked as default.
  Future<void> clearDefaultSignature() async {
    if (!isReady) {
      throw const SignatureException(
        'Signature service not initialized. Call initialize() first.',
      );
    }

    await _clearDefaultSignature();
  }

  Future<void> _clearDefaultSignature() async {
    try {
      await _databaseHelper.update(
        DatabaseHelper.tableSignatures,
        {
          DatabaseHelper.columnIsDefault: 0,
          DatabaseHelper.columnUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${DatabaseHelper.columnIsDefault} = ?',
        whereArgs: [1],
      );
    } catch (e) {
      throw SignatureException('Failed to clear default signature', cause: e);
    }
  }

  /// Deletes a signature from the database and storage.
  ///
  /// Removes both the database record and the encrypted image file.
  ///
  /// Throws [SignatureException] if deletion fails.
  Future<void> deleteSignature(String id) async {
    if (!isReady) {
      throw const SignatureException(
        'Signature service not initialized. Call initialize() first.',
      );
    }

    if (id.isEmpty) {
      throw const SignatureException('Signature ID cannot be empty');
    }

    try {
      final signature = await getSignature(id);
      if (signature == null) {
        throw SignatureException('Signature not found: $id');
      }

      // Delete the encrypted file
      final file = File(signature.signaturePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Delete from database
      await _databaseHelper.delete(
        DatabaseHelper.tableSignatures,
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [id],
      );

      debugPrint('Deleted signature: $id');
    } catch (e) {
      if (e is SignatureException) rethrow;
      throw SignatureException('Failed to delete signature', cause: e);
    }
  }

  /// Deletes multiple signatures.
  ///
  /// Removes both database records and encrypted image files.
  ///
  /// Throws [SignatureException] if any deletion fails.
  Future<void> deleteSignatures(List<String> ids) async {
    for (final id in ids) {
      await deleteSignature(id);
    }
  }

  /// Loads the image bytes for a saved signature.
  ///
  /// Decrypts the signature image from storage.
  ///
  /// Returns the decrypted PNG bytes.
  ///
  /// Throws [SignatureException] if loading fails.
  Future<Uint8List> loadSignatureImage(SavedSignature signature) async {
    if (!isReady) {
      throw const SignatureException(
        'Signature service not initialized. Call initialize() first.',
      );
    }

    try {
      final file = File(signature.signaturePath);
      if (!await file.exists()) {
        throw SignatureException(
          'Signature file not found: ${signature.signaturePath}',
        );
      }

      // Decrypt and return
      final decrypted = await _encryptionService.decryptFile(
        signature.signaturePath,
      );

      return decrypted;
    } catch (e) {
      if (e is SignatureException) rethrow;
      throw SignatureException('Failed to load signature image', cause: e);
    }
  }

  /// Overlays a signature on a document image.
  ///
  /// Places the [signatureBytes] at the specified [position] on
  /// the [documentBytes] image.
  ///
  /// The [signatureWidth] controls the size of the signature.
  /// The height is calculated to maintain aspect ratio.
  ///
  /// Set [opacity] to blend the signature (0.0 - 1.0).
  ///
  /// Returns a [SignedDocument] with the composited image.
  ///
  /// Throws [SignatureException] if overlay fails.
  ///
  /// Example:
  /// ```dart
  /// final signedDoc = await signatureService.overlaySignatureOnDocument(
  ///   documentBytes: documentImageBytes,
  ///   signatureBytes: captured.pngBytes,
  ///   position: Offset(100, 500),
  ///   signatureWidth: 200,
  /// );
  /// ```
  Future<SignedDocument> overlaySignatureOnDocument({
    required Uint8List documentBytes,
    required Uint8List signatureBytes,
    required Offset position,
    required double signatureWidth,
    double opacity = 1.0,
  }) async {
    if (documentBytes.isEmpty) {
      throw const SignatureException('Document bytes cannot be empty');
    }

    if (signatureBytes.isEmpty) {
      throw const SignatureException('Signature bytes cannot be empty');
    }

    if (signatureWidth <= 0) {
      throw const SignatureException('Signature width must be positive');
    }

    if (opacity < 0 || opacity > 1) {
      throw const SignatureException('Opacity must be between 0.0 and 1.0');
    }

    try {
      // Decode images
      final documentImage = img.decodeImage(documentBytes);
      if (documentImage == null) {
        throw const SignatureException('Failed to decode document image');
      }

      final signatureImage = img.decodePng(signatureBytes);
      if (signatureImage == null) {
        throw const SignatureException('Failed to decode signature image');
      }

      // Calculate signature dimensions maintaining aspect ratio
      final aspectRatio = signatureImage.height / signatureImage.width;
      final scaledWidth = signatureWidth.round();
      final scaledHeight = (signatureWidth * aspectRatio).round();

      // Resize signature
      final resizedSignature = img.copyResize(
        signatureImage,
        width: scaledWidth,
        height: scaledHeight,
        interpolation: img.Interpolation.linear,
      );

      // Apply opacity if needed
      img.Image finalSignature;
      if (opacity < 1.0) {
        finalSignature = _applyOpacity(resizedSignature, opacity);
      } else {
        finalSignature = resizedSignature;
      }

      // Composite signature onto document
      final result = img.compositeImage(
        documentImage,
        finalSignature,
        dstX: position.dx.round(),
        dstY: position.dy.round(),
      );

      // Encode result
      final resultBytes = Uint8List.fromList(
        img.encodeJpg(result, quality: 95),
      );

      return SignedDocument(
        imageBytes: resultBytes,
        width: result.width,
        height: result.height,
        signaturePosition: position,
        signatureSize: Size(scaledWidth.toDouble(), scaledHeight.toDouble()),
      );
    } catch (e) {
      if (e is SignatureException) rethrow;
      throw SignatureException(
        'Failed to overlay signature on document',
        cause: e,
      );
    }
  }

  /// Applies opacity to an image.
  img.Image _applyOpacity(img.Image image, double opacity) {
    final opacityValue = (opacity * 255).round();
    final result = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 4,
    );

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final a = pixel.a.toInt();
        final newA = (a * opacityValue / 255).round();
        result.setPixel(
          x,
          y,
          img.ColorRgba8(
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
            newA,
          ),
        );
      }
    }

    return result;
  }

  /// Overlays a saved signature on a document.
  ///
  /// Convenience method that loads the signature image and applies it.
  ///
  /// Returns a [SignedDocument] with the composited image.
  ///
  /// Throws [SignatureException] if overlay fails.
  Future<SignedDocument> overlaySignatureOnDocumentById({
    required Uint8List documentBytes,
    required String signatureId,
    required Offset position,
    required double signatureWidth,
    double opacity = 1.0,
  }) async {
    final signature = await getSignature(signatureId);
    if (signature == null) {
      throw SignatureException('Signature not found: $signatureId');
    }

    final signatureBytes = await loadSignatureImage(signature);

    return overlaySignatureOnDocument(
      documentBytes: documentBytes,
      signatureBytes: signatureBytes,
      position: position,
      signatureWidth: signatureWidth,
      opacity: opacity,
    );
  }

  /// Clears a signature control.
  ///
  /// Removes all strokes from the control, preparing it for a new signature.
  void clearControl(HandSignatureControl control) {
    control.clear();
  }

  /// Checks if a control has any signature data.
  ///
  /// Returns true if the control contains at least one stroke.
  bool hasSignature(HandSignatureControl control) {
    return !control.isEmpty;
  }

  /// Gets the total storage size used by signatures.
  ///
  /// Returns the size in bytes.
  Future<int> getStorageSize() async {
    if (_signaturesPath == null) return 0;

    try {
      final dir = Directory(_signaturesPath!);
      if (!await dir.exists()) return 0;

      var totalSize = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (_) {
      return 0;
    }
  }

  /// Gets a formatted string of the storage size.
  ///
  /// Returns a human-readable string like "1.2 MB".
  Future<String> getStorageSizeFormatted() async {
    final size = await getStorageSize();
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Clears all signatures from storage and database.
  ///
  /// This permanently deletes all saved signatures.
  /// Use with caution.
  ///
  /// Throws [SignatureException] if clearing fails.
  Future<void> clearAllSignatures() async {
    if (!isReady) {
      throw const SignatureException(
        'Signature service not initialized. Call initialize() first.',
      );
    }

    try {
      // Delete all signature files
      final dir = Directory(_signaturesPath!);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }

      // Delete all database records
      await _databaseHelper.delete(DatabaseHelper.tableSignatures);

      debugPrint('Cleared all signatures');
    } catch (e) {
      throw SignatureException('Failed to clear signatures', cause: e);
    }
  }
}

/// Extension methods for lists of [SavedSignature].
extension SavedSignatureListExtensions on List<SavedSignature> {
  /// Gets the default signature, if any.
  SavedSignature? get defaultSignature {
    try {
      return firstWhere((s) => s.isDefault);
    } catch (_) {
      return null;
    }
  }

  /// Gets signatures sorted by label.
  List<SavedSignature> get sortedByLabel {
    final list = List<SavedSignature>.from(this);
    list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  /// Gets signatures sorted by creation date (newest first).
  List<SavedSignature> get sortedByCreatedDesc {
    final list = List<SavedSignature>.from(this);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Gets signatures sorted by creation date (oldest first).
  List<SavedSignature> get sortedByCreatedAsc {
    final list = List<SavedSignature>.from(this);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Finds a signature by ID.
  SavedSignature? findById(String id) {
    try {
      return firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Searches signatures by label (case-insensitive).
  List<SavedSignature> search(String query) {
    if (query.isEmpty) return this;
    final lowerQuery = query.toLowerCase();
    return where((s) => s.label.toLowerCase().contains(lowerQuery)).toList();
  }
}
