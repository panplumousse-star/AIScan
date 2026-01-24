/// Performance utilities and optimization tools for the AIScan application.
///
/// This barrel file provides convenient access to all performance-related
/// modules and utilities. Import this file to access the complete performance
/// API in a single import statement.
///
/// ## Core Performance Monitoring
/// - [DevicePerformance] - Device capability detection and tier classification
/// - [PerformanceMonitor] - Runtime performance metrics and monitoring
///
/// ## Caching Systems
/// - [ImageCacheManager] - LRU cache for image data
/// - [ThumbnailCacheService] - Document thumbnail caching service
///
/// ## Rate Limiting & Control Flow
/// - [Debouncer] - Debounce rapid function calls
/// - [Throttler] - Throttle function execution rate
///
/// ## Data Loading
/// - [LazyLoader] - Pagination and lazy loading for lists
///
/// ## Memory Management
/// - [MemoryManager] - Memory optimization utilities
///
/// ## Optimization Utilities
/// - [ScrollOptimizationConfig] - Device-specific scroll optimization
/// - [ImageOptimization] - Image loading and caching optimization
///
/// ## Optimized Widgets
/// - [OptimizedImage] - Performance-optimized image widget
/// - [OptimizedListView] - Performance-optimized list view
///
/// ## Startup & Extensions
/// - [StartupOptimization] - App startup performance tools
/// - [PerformanceContextExtension] - BuildContext extensions for performance
///
/// ## Usage
/// ```dart
/// import 'package:aiscan/core/performance/performance.dart';
///
/// // Access any performance utility:
/// final deviceTier = DevicePerformance.tier;
/// final monitor = ref.read(performanceMonitorProvider);
/// final debouncer = Debouncer(duration: Duration(milliseconds: 300));
/// ```
library;

// Core performance monitoring
export 'device_performance.dart';
export 'performance_monitor.dart';

// Caching systems
export 'cache/image_cache_manager.dart';
export 'cache/thumbnail_cache_service.dart';

// Rate limiting and control flow
export 'rate_limiting.dart';

// Data loading
export 'lazy_loader.dart';

// Memory management
export 'memory_manager.dart';

// Optimization utilities
export 'optimization/scroll_optimization.dart';
export 'optimization/image_optimization.dart'
    show ImageOptimization;

// Optimized widgets
export 'widgets/optimized_image.dart';
export 'widgets/optimized_list_view.dart';

// Startup optimization
export 'startup_optimization.dart';

// Extensions
export 'performance_extensions.dart';
