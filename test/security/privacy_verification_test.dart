import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Privacy Verification Tests
///
/// These tests verify the privacy-first guarantees of the AIScan application:
/// 1. No network calls - the app works completely offline
/// 2. No trackers - no analytics, crash reporting, or third-party tracking SDKs
/// 3. No data collection - no personally identifiable information is collected
/// 4. Local processing only - all document processing happens on-device
///
/// CRITICAL: These tests must pass before any release to ensure user privacy.
/// Failure of any test indicates a privacy violation that must be addressed.
void main() {
  /// Project root directory
  late Directory projectRoot;

  /// Common analytics/tracking packages that should NOT be present
  final analyticsPackages = [
    'firebase_analytics',
    'firebase_crashlytics',
    'firebase_performance',
    'google_analytics',
    'amplitude_flutter',
    'mixpanel_flutter',
    'segment_analytics',
    'sentry_flutter',
    'appsflyer_sdk',
    'adjust_sdk',
    'branch_flutter',
    'facebook_app_events',
    'flurry_analytics',
    'bugsnag_flutter',
    'newrelic_mobile',
    'datadog_flutter',
    'instabug_flutter',
    'embrace_flutter',
    'rollbar_flutter',
    'raygun4flutter',
    'countly_flutter',
    'matomo_tracker',
    'posthog_flutter',
    'heap_flutter',
    'kissmetrics',
    'localytics',
    'conviva_flutter',
    'moengage_flutter',
    'clevertap_plugin',
    'onesignal_flutter', // Can be used for tracking
  ];

  /// URL patterns that indicate tracking or data exfiltration
  final trackingUrlPatterns = [
    RegExp(r'google-analytics\.com'),
    RegExp(r'googletagmanager\.com'),
    RegExp(r'facebook\.com/tr'),
    RegExp(r'analytics\.(google|facebook|twitter|amplitude)'),
    RegExp(r'segment\.io'),
    RegExp(r'mixpanel\.com'),
    RegExp(r'api\.amplitude\.com'),
    RegExp(r'sentry\.io'),
    RegExp(r'crashlytics\.com'),
    RegExp(r'appsflyer\.com'),
    RegExp(r'adjust\.com'),
    RegExp(r'branch\.io'),
    RegExp(r'hotjar\.com'),
    RegExp(r'mouseflow\.com'),
    RegExp(r'clarity\.ms'),
    RegExp(r'fullstory\.com'),
  ];

  /// Code patterns that indicate tracking/analytics usage
  final trackingCodePatterns = [
    RegExp(r'FirebaseAnalytics', caseSensitive: false),
    RegExp(r'FirebaseCrashlytics', caseSensitive: false),
    RegExp(r'Amplitude\.getInstance', caseSensitive: false),
    RegExp(r'Mixpanel\.track', caseSensitive: false),
    RegExp(r'Analytics\.track', caseSensitive: false),
    RegExp(r'logEvent\s*\(', caseSensitive: false),
    RegExp(r'sendAnalytics', caseSensitive: false),
    RegExp(r'trackScreen', caseSensitive: false),
    RegExp(r'recordError', caseSensitive: false),
    RegExp(r'setUserProperty', caseSensitive: false),
  ];

  /// Network-related patterns that should be flagged for review
  final networkPatterns = [
    RegExp(r'http\.Client\(\)', caseSensitive: false),
    RegExp(r'HttpClient\(\)', caseSensitive: false),
    RegExp(r'Dio\(\)', caseSensitive: false),
    RegExp(r'Uri\.parse\s*\([^)]*https?://[^)]+\)', caseSensitive: false),
    RegExp(r'WebSocket\.connect', caseSensitive: false),
    RegExp(r'\.get\s*\([^)]*https?://', caseSensitive: false),
    RegExp(r'\.post\s*\([^)]*https?://', caseSensitive: false),
  ];

  /// Allowed network-related patterns (e.g., documentation links)
  final allowedNetworkPatterns = [
    RegExp(r'//\s*https?://'), // URLs in comments
    RegExp(r'///\s*https?://'), // URLs in doc comments
    RegExp(r'@see\s+https?://'), // Documentation references
    RegExp(r'WCAG.*https?://'), // WCAG references
    RegExp(r'RFC.*https?://'), // RFC references
  ];

  setUpAll(() {
    // Find project root by looking for pubspec.yaml
    var dir = Directory.current;
    while (!File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) {
        throw Exception('Could not find project root (pubspec.yaml not found)');
      }
      dir = parent;
    }
    projectRoot = dir;
  });

  group('Privacy Verification: No Analytics/Tracking SDKs', () {
    test('pubspec.yaml should not contain any analytics packages', () async {
      // Arrange
      final pubspecFile = File(p.join(projectRoot.path, 'pubspec.yaml'));
      expect(pubspecFile.existsSync(), isTrue,
          reason: 'pubspec.yaml must exist');

      // Act
      final content = await pubspecFile.readAsString();
      final contentLower = content.toLowerCase();

      // Assert
      for (final package in analyticsPackages) {
        expect(
          contentLower.contains(package.toLowerCase()),
          isFalse,
          reason: 'pubspec.yaml should not contain analytics package: $package',
        );
      }
    });

    test('pubspec.yaml should not contain suspicious tracking-related packages',
        () async {
      // Arrange
      final pubspecFile = File(p.join(projectRoot.path, 'pubspec.yaml'));
      final content = await pubspecFile.readAsString();

      // Act - Look for packages with suspicious names
      final suspiciousPatterns = [
        RegExp(r'analytics', caseSensitive: false),
        RegExp(r'tracking', caseSensitive: false),
        RegExp(r'telemetry', caseSensitive: false),
        RegExp(r'metrics', caseSensitive: false),
        RegExp(r'crash.*report', caseSensitive: false),
      ];

      // Assert
      for (final pattern in suspiciousPatterns) {
        // Split into lines and check each dependency line
        final lines = content.split('\n');
        for (final line in lines) {
          // Skip comments and non-dependency lines
          if (line.trim().startsWith('#') || !line.contains(':')) continue;

          // Check if this looks like a dependency declaration
          if (pattern.hasMatch(line)) {
            // Allow known safe patterns
            if (line.contains('flutter_lints') ||
                line.contains('# ') ||
                line.contains('description:')) {
              continue;
            }
            fail(
              'Suspicious package found in pubspec.yaml: $line\n'
              'Pattern matched: ${pattern.pattern}',
            );
          }
        }
      }
    });

    test('no tracking/analytics code patterns in lib directory', () async {
      // Arrange
      final libDir = Directory(p.join(projectRoot.path, 'lib'));
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      // Act - Scan all Dart files
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      // Assert
      for (final file in dartFiles) {
        final content = await file.readAsString();
        final relativePath = p.relative(file.path, from: projectRoot.path);

        for (final pattern in trackingCodePatterns) {
          final match = pattern.firstMatch(content);
          if (match != null) {
            // Get line number for better error message
            final beforeMatch = content.substring(0, match.start);
            final lineNumber = '\n'.allMatches(beforeMatch).length + 1;

            fail(
              'Tracking code pattern found in $relativePath:$lineNumber\n'
              'Pattern: ${pattern.pattern}\n'
              'Match: ${match.group(0)}',
            );
          }
        }
      }
    });
  });

  group('Privacy Verification: No Network Permissions', () {
    test('Android manifest should not have INTERNET permission', () async {
      // Arrange
      final manifestFile = File(
        p.join(projectRoot.path, 'android/app/src/main/AndroidManifest.xml'),
      );

      // Skip if Android directory doesn't exist
      if (!manifestFile.existsSync()) {
        // This is acceptable - the file might not exist in test environment
        return;
      }

      // Act
      final content = await manifestFile.readAsString();

      // Assert
      expect(
        content.contains('android.permission.INTERNET'),
        isFalse,
        reason: 'App should not require INTERNET permission for privacy',
      );
    });

    test('Android manifest should not have ACCESS_NETWORK_STATE permission',
        () async {
      // Arrange
      final manifestFile = File(
        p.join(projectRoot.path, 'android/app/src/main/AndroidManifest.xml'),
      );

      if (!manifestFile.existsSync()) return;

      // Act
      final content = await manifestFile.readAsString();

      // Assert
      expect(
        content.contains('android.permission.ACCESS_NETWORK_STATE'),
        isFalse,
        reason: 'App should not require ACCESS_NETWORK_STATE permission',
      );
    });

    test('iOS Info.plist should not have network usage description', () async {
      // Arrange
      final plistFile = File(
        p.join(projectRoot.path, 'ios/Runner/Info.plist'),
      );

      // Skip if iOS directory doesn't exist
      if (!plistFile.existsSync()) return;

      // Act
      final content = await plistFile.readAsString();

      // Assert - These keys indicate network usage intent
      final networkKeys = [
        'NSAppTransportSecurity',
        'NSAllowsArbitraryLoads',
        'NSNetworkVolumes',
      ];

      for (final key in networkKeys) {
        // Allow if it's explicitly set to false/restricted
        if (!content.contains(key)) continue;

        // Check if it's set to allow arbitrary loads (bad)
        if (content.contains('NSAllowsArbitraryLoads') &&
            content.contains('<true/>')) {
          fail(
            'iOS Info.plist allows arbitrary network loads. '
            'This indicates network capability which violates privacy-first design.',
          );
        }
      }
    });
  });

  group('Privacy Verification: No Tracking URLs', () {
    test('source code should not contain tracking URLs', () async {
      // Arrange
      final libDir = Directory(p.join(projectRoot.path, 'lib'));
      expect(libDir.existsSync(), isTrue);

      // Act - Scan all Dart files
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      // Assert
      for (final file in dartFiles) {
        final content = await file.readAsString();
        final relativePath = p.relative(file.path, from: projectRoot.path);

        for (final pattern in trackingUrlPatterns) {
          final match = pattern.firstMatch(content);
          if (match != null) {
            // Get line number
            final beforeMatch = content.substring(0, match.start);
            final lineNumber = '\n'.allMatches(beforeMatch).length + 1;

            fail(
              'Tracking URL found in $relativePath:$lineNumber\n'
              'Pattern: ${pattern.pattern}\n'
              'Match: ${match.group(0)}',
            );
          }
        }
      }
    });

    test('source code should not make outbound HTTP requests', () async {
      // Arrange
      final libDir = Directory(p.join(projectRoot.path, 'lib'));
      expect(libDir.existsSync(), isTrue);

      // Act - Scan all Dart files
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      // Assert
      for (final file in dartFiles) {
        final content = await file.readAsString();
        final lines = content.split('\n');
        final relativePath = p.relative(file.path, from: projectRoot.path);

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];

          // Skip if line matches allowed patterns (comments, docs)
          bool isAllowed = false;
          for (final allowed in allowedNetworkPatterns) {
            if (allowed.hasMatch(line)) {
              isAllowed = true;
              break;
            }
          }
          if (isAllowed) continue;

          // Check for network patterns
          for (final pattern in networkPatterns) {
            if (pattern.hasMatch(line)) {
              fail(
                'Network code found in $relativePath:${i + 1}\n'
                'Line: ${line.trim()}\n'
                'Pattern: ${pattern.pattern}\n\n'
                'All network calls are prohibited in privacy-first design.',
              );
            }
          }
        }
      }
    });
  });

  group('Privacy Verification: No Data Exfiltration', () {
    test('app should not collect device identifiers', () async {
      // Arrange
      final libDir = Directory(p.join(projectRoot.path, 'lib'));
      expect(libDir.existsSync(), isTrue);

      // Device ID collection patterns
      final deviceIdPatterns = [
        RegExp(r'device_info_plus', caseSensitive: false),
        RegExp(r'getAndroidId', caseSensitive: false),
        RegExp(r'identifierForVendor', caseSensitive: false),
        RegExp(r'advertisingId', caseSensitive: false),
        RegExp(r'ANDROID_ID', caseSensitive: false),
        RegExp(r'getDeviceId', caseSensitive: false),
        RegExp(r'getIMEI', caseSensitive: false),
        RegExp(r'getMacAddress', caseSensitive: false),
      ];

      // Act - Scan pubspec.yaml
      final pubspecFile = File(p.join(projectRoot.path, 'pubspec.yaml'));
      final pubspecContent = await pubspecFile.readAsString();

      // Assert - No device_info package
      expect(
        pubspecContent.contains('device_info'),
        isFalse,
        reason: 'App should not include device_info package',
      );

      // Act - Scan lib directory
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      // Assert - No device ID collection code
      for (final file in dartFiles) {
        final content = await file.readAsString();
        final relativePath = p.relative(file.path, from: projectRoot.path);

        for (final pattern in deviceIdPatterns) {
          final match = pattern.firstMatch(content);
          if (match != null) {
            final beforeMatch = content.substring(0, match.start);
            final lineNumber = '\n'.allMatches(beforeMatch).length + 1;

            fail(
              'Device identifier collection code found in $relativePath:$lineNumber\n'
              'Pattern: ${pattern.pattern}\n'
              'Match: ${match.group(0)}',
            );
          }
        }
      }
    });

    test('app should not collect personal information', () async {
      // Arrange
      final libDir = Directory(p.join(projectRoot.path, 'lib'));
      expect(libDir.existsSync(), isTrue);

      // PII collection patterns (suspicious variable/method names)
      final piiPatterns = [
        RegExp(r'collectEmail', caseSensitive: false),
        RegExp(r'collectPhone', caseSensitive: false),
        RegExp(r'collectName', caseSensitive: false),
        RegExp(r'getUserEmail', caseSensitive: false),
        RegExp(r'getUserPhone', caseSensitive: false),
        RegExp(r'sendUserData', caseSensitive: false),
        RegExp(r'uploadUserInfo', caseSensitive: false),
        RegExp(r'submitPersonalData', caseSensitive: false),
      ];

      // Act - Scan all Dart files
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      // Assert
      for (final file in dartFiles) {
        final content = await file.readAsString();
        final relativePath = p.relative(file.path, from: projectRoot.path);

        for (final pattern in piiPatterns) {
          final match = pattern.firstMatch(content);
          if (match != null) {
            final beforeMatch = content.substring(0, match.start);
            final lineNumber = '\n'.allMatches(beforeMatch).length + 1;

            fail(
              'PII collection code found in $relativePath:$lineNumber\n'
              'Pattern: ${pattern.pattern}\n'
              'Match: ${match.group(0)}',
            );
          }
        }
      }
    });
  });

  group('Privacy Verification: Local Processing Only', () {
    test('OCR should be configured for local processing only', () async {
      // Arrange
      final ocrServiceFile = File(
        p.join(projectRoot.path, 'lib/features/ocr/domain/ocr_service.dart'),
      );

      // Skip if OCR service doesn't exist yet
      if (!ocrServiceFile.existsSync()) return;

      // Act
      final content = await ocrServiceFile.readAsString();

      // Assert - Should use Tesseract (local) not cloud OCR
      expect(
        content.contains('flutter_tesseract_ocr') ||
            content.contains('FlutterTesseractOcr') ||
            content.contains('tesseract'),
        isTrue,
        reason: 'OCR should use local Tesseract, not cloud services',
      );

      // Should NOT use cloud OCR services
      final cloudOcrPatterns = [
        'google_cloud_vision',
        'aws_textract',
        'azure_cognitive_services',
        'google_ml_kit_text_recognition', // Note: ML Kit is on-device, so this is OK
      ];

      for (final cloudService in cloudOcrPatterns) {
        // Exception for google_ml_kit_text_recognition which is on-device
        if (cloudService == 'google_ml_kit_text_recognition') continue;

        expect(
          content.contains(cloudService),
          isFalse,
          reason: 'OCR should not use cloud service: $cloudService',
        );
      }
    });

    test('document scanner should be configured for local processing', () async {
      // Arrange
      final scannerServiceFile = File(
        p.join(projectRoot.path, 'lib/features/scanner/domain/scanner_service.dart'),
      );

      // Skip if scanner service doesn't exist yet
      if (!scannerServiceFile.existsSync()) return;

      // Act
      final content = await scannerServiceFile.readAsString();

      // Assert - Should use ML Kit (on-device) document scanner
      expect(
        content.contains('google_mlkit_document_scanner') ||
            content.contains('DocumentScanner'),
        isTrue,
        reason: 'Scanner should use on-device ML Kit document scanner',
      );

      // Should NOT upload images to cloud for processing
      final cloudProcessingPatterns = [
        RegExp(r'upload.*image', caseSensitive: false),
        RegExp(r'send.*scan', caseSensitive: false),
        RegExp(r'cloud.*process', caseSensitive: false),
      ];

      for (final pattern in cloudProcessingPatterns) {
        expect(
          pattern.hasMatch(content),
          isFalse,
          reason: 'Scanner should not upload images: ${pattern.pattern}',
        );
      }
    });

    test('image processing should be local only', () async {
      // Arrange
      final imageProcessorFile = File(
        p.join(projectRoot.path, 'lib/features/enhancement/domain/image_processor.dart'),
      );

      // Skip if image processor doesn't exist yet
      if (!imageProcessorFile.existsSync()) return;

      // Act
      final content = await imageProcessorFile.readAsString();

      // Assert - Should use local image processing package
      expect(
        content.contains("import 'package:image/") ||
            content.contains('package:image/'),
        isTrue,
        reason: 'Image processing should use local image package',
      );

      // Should NOT use cloud image processing
      final cloudImagePatterns = [
        'cloudinary',
        'imgix',
        'aws_lambda',
        'cloud_functions',
        'image_upload',
      ];

      for (final pattern in cloudImagePatterns) {
        expect(
          content.toLowerCase().contains(pattern.toLowerCase()),
          isFalse,
          reason: 'Image processing should not use cloud service: $pattern',
        );
      }
    });
  });

  group('Privacy Verification: Dependency Audit', () {
    test('all dependencies should be from trusted sources', () async {
      // Arrange
      final pubspecFile = File(p.join(projectRoot.path, 'pubspec.yaml'));
      final content = await pubspecFile.readAsString();

      // Act - Parse dependencies section
      final lines = content.split('\n');
      var inDependencies = false;
      var inDevDependencies = false;
      final dependencies = <String>[];

      for (final line in lines) {
        if (line.trim() == 'dependencies:') {
          inDependencies = true;
          inDevDependencies = false;
          continue;
        }
        if (line.trim() == 'dev_dependencies:') {
          inDependencies = false;
          inDevDependencies = true;
          continue;
        }
        if (line.trim() == 'flutter:' ||
            line.trim() == 'environment:' ||
            line.trim() == 'dependency_overrides:') {
          inDependencies = false;
          inDevDependencies = false;
          continue;
        }

        if ((inDependencies || inDevDependencies) && line.trim().isNotEmpty) {
          // Extract package name
          final match = RegExp(r'^\s+(\w+):').firstMatch(line);
          if (match != null) {
            dependencies.add(match.group(1)!);
          }
        }
      }

      // Assert - No suspicious packages
      final suspiciousPackages = [
        'ad_mob',
        'admob',
        'google_mobile_ads',
        'facebook_audience_network',
        'unity_ads',
        'applovin',
        'ironsource',
        'vungle',
        'chartboost',
      ];

      for (final dep in dependencies) {
        for (final suspicious in suspiciousPackages) {
          expect(
            dep.toLowerCase().contains(suspicious.toLowerCase()),
            isFalse,
            reason: 'Suspicious package found: $dep (matches $suspicious)',
          );
        }
      }
    });

    test('pubspec.yaml should have privacy-focused dependencies only', () async {
      // Arrange
      final pubspecFile = File(p.join(projectRoot.path, 'pubspec.yaml'));
      final content = await pubspecFile.readAsString();

      // Core expected packages for privacy-first document scanner
      final expectedPackages = [
        'flutter_secure_storage', // Secure key storage
        'encrypt', // Encryption
        'google_mlkit_document_scanner', // On-device scanning
        'flutter_tesseract_ocr', // Offline OCR
        'sqflite', // Local database
        'path_provider', // Local file paths
      ];

      // Assert - Expected packages should be present
      for (final package in expectedPackages) {
        expect(
          content.contains(package),
          isTrue,
          reason: 'Expected privacy package missing: $package',
        );
      }
    });
  });

  group('Privacy Verification: Settings Transparency', () {
    test('settings should clearly indicate privacy-first design', () async {
      // Arrange
      final settingsFile = File(
        p.join(projectRoot.path, 'lib/features/settings/presentation/settings_screen.dart'),
      );

      // Skip if settings screen doesn't exist yet
      if (!settingsFile.existsSync()) return;

      // Act
      final content = await settingsFile.readAsString();

      // Assert - Settings should mention privacy features
      expect(
        content.toLowerCase().contains('privacy') ||
            content.toLowerCase().contains('no analytics') ||
            content.toLowerCase().contains('local') ||
            content.toLowerCase().contains('offline'),
        isTrue,
        reason: 'Settings should clearly communicate privacy-first design',
      );
    });
  });

  group('Privacy Verification: Comprehensive Audit', () {
    test('full codebase audit for privacy violations', () async {
      // Arrange
      final libDir = Directory(p.join(projectRoot.path, 'lib'));
      expect(libDir.existsSync(), isTrue);

      // Critical privacy violation patterns
      final criticalPatterns = [
        // Network calls
        (
          pattern: RegExp(r'http\.get\s*\('),
          description: 'HTTP GET request',
        ),
        (
          pattern: RegExp(r'http\.post\s*\('),
          description: 'HTTP POST request',
        ),
        (
          pattern: RegExp(r'http\.put\s*\('),
          description: 'HTTP PUT request',
        ),
        (
          pattern: RegExp(r'http\.delete\s*\('),
          description: 'HTTP DELETE request',
        ),
        // Data exfiltration
        (
          pattern: RegExp(r'uploadFile', caseSensitive: false),
          description: 'File upload',
        ),
        (
          pattern: RegExp(r'sendData', caseSensitive: false),
          description: 'Data transmission',
        ),
        (
          pattern: RegExp(r'postData', caseSensitive: false),
          description: 'Data posting',
        ),
        // User tracking
        (
          pattern: RegExp(r'trackUser', caseSensitive: false),
          description: 'User tracking',
        ),
        (
          pattern: RegExp(r'logUser', caseSensitive: false),
          description: 'User logging',
        ),
        (
          pattern: RegExp(r'recordUser', caseSensitive: false),
          description: 'User recording',
        ),
      ];

      // Act - Scan all Dart files
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final violations = <String>[];

      for (final file in dartFiles) {
        final content = await file.readAsString();
        final relativePath = p.relative(file.path, from: projectRoot.path);
        final lines = content.split('\n');

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];

          // Skip comments
          if (line.trim().startsWith('//') || line.trim().startsWith('*')) {
            continue;
          }

          for (final (pattern: pat, description: desc) in criticalPatterns) {
            if (pat.hasMatch(line)) {
              violations.add(
                '$relativePath:${i + 1}: $desc\n  Line: ${line.trim()}',
              );
            }
          }
        }
      }

      // Assert
      if (violations.isNotEmpty) {
        fail(
          'Privacy violations found:\n\n${violations.join('\n\n')}\n\n'
          'All network calls and data exfiltration are prohibited.',
        );
      }
    });
  });
}
