# Performance Modules Documentation

## Overview

The AIScan performance utilities have been refactored from a single 1,579-line `performance_utils.dart` file into 13 domain-specific modules. This refactoring improves code organization, maintainability, and makes it easier to understand and test individual components.

## Rationale

The original `performance_utils.dart` file contained 4-5 unrelated concerns bundled together:
- Device capability detection
- Performance monitoring
- Image caching
- Thumbnail caching
- Various utility classes (rate limiting, lazy loading, memory management, etc.)

Having these unrelated utilities in one file made it:
- Hard to understand individual components
- Increased the chance of unintended side effects when modifying one utility
- Made testing more difficult
- Created unnecessary coupling between distinct domains

## Module Structure

The performance utilities are now organized under `lib/core/performance/` with the following structure:

```
lib/core/performance/
├── performance.dart                    # Barrel file - exports all modules
├── device_performance.dart             # Device capability detection
├── performance_monitor.dart            # Runtime performance metrics
├── rate_limiting.dart                  # Debouncer and Throttler
├── lazy_loader.dart                    # Pagination and lazy loading
├── memory_manager.dart                 # Memory optimization utilities
├── startup_optimization.dart           # App startup performance tools
├── performance_extensions.dart         # BuildContext extensions
├── cache/
│   ├── image_cache_manager.dart        # LRU cache for images
│   └── thumbnail_cache_service.dart    # Thumbnail caching service
├── optimization/
│   ├── scroll_optimization.dart        # Scroll performance config
│   └── image_optimization.dart         # Image loading optimization
└── widgets/
    ├── optimized_image.dart            # Performance-optimized image widget
    └── optimized_list_view.dart        # Performance-optimized list view
```

## Module Descriptions

### Core Performance Monitoring

#### `device_performance.dart`
Detects device capabilities and classifies devices into performance tiers (low, medium, high).

**Exports:**
- `DevicePerformance` class - Device capability detection
- `DeviceTier` enum - Performance tier classification (low/medium/high)
- `devicePerformanceProvider` - Riverpod provider for device performance

**Use cases:**
- Adapting UI complexity based on device capabilities
- Setting appropriate cache sizes
- Adjusting animation durations
- Configuring image quality

#### `performance_monitor.dart`
Monitors runtime performance metrics like frame rate and provides performance summaries.

**Exports:**
- `PerformanceMonitor` class - Runtime performance monitoring
- `PerformanceSummary` class - Performance metrics summary
- `performanceMonitorProvider` - Riverpod provider for performance monitor

**Use cases:**
- Tracking frame rates during development
- Identifying performance bottlenecks
- Logging performance metrics
- Monitoring app responsiveness

### Caching Systems

#### `cache/image_cache_manager.dart`
LRU (Least Recently Used) cache implementation for image data.

**Exports:**
- `ImageCacheManager` class - Image caching with LRU eviction

**Features:**
- Size-based eviction
- Item count limits
- Hit/miss statistics
- TTL (Time-To-Live) support

#### `cache/thumbnail_cache_service.dart`
Specialized caching service for document thumbnails with device-adaptive sizing.

**Exports:**
- `ThumbnailCacheService` class - Thumbnail caching service
- `thumbnailCacheProvider` - Riverpod provider for thumbnail cache

**Features:**
- Device-tier-specific cache sizes
- Automatic cache eviction
- Statistics tracking
- Integration with document repository

### Rate Limiting & Control Flow

#### `rate_limiting.dart`
Utilities for controlling function execution rate.

**Exports:**
- `Debouncer` class - Delays execution until calls stop for a duration
- `Throttler` class - Limits execution rate to once per duration

**Use cases:**
- Search input debouncing
- Scroll event throttling
- API request rate limiting
- Preventing excessive function calls

### Data Loading

#### `lazy_loader.dart`
Pagination and lazy loading support for lists.

**Exports:**
- `LazyLoader<T>` class - Generic lazy loading with pagination

**Features:**
- Automatic pagination
- Preloading support
- Loading state management
- Error handling
- Pull-to-refresh support

### Memory Management

#### `memory_manager.dart`
Utilities for managing app memory usage.

**Exports:**
- `MemoryManager` class - Static utilities for memory optimization

**Features:**
- Clear image caches
- Set cache sizes based on device tier
- Suggest garbage collection
- Configure memory settings for device capabilities

### Optimization Utilities

#### `optimization/scroll_optimization.dart`
Device-specific scroll optimization configuration.

**Exports:**
- `ScrollOptimizationConfig` class - Scroll performance settings

**Features:**
- Device-tier-specific cache extent
- Optimized scroll physics
- Keep-alive configuration
- Repaint boundary settings

#### `optimization/image_optimization.dart`
Image loading and caching optimization utilities.

**Exports:**
- `ImageOptimization` class - Static utilities for image optimization

**Features:**
- Calculate optimal decode sizes
- Device-specific quality settings
- Memory-efficient image loading

### Optimized Widgets

#### `widgets/optimized_image.dart`
Performance-optimized image widget with automatic device adaptation.

**Exports:**
- `OptimizedImage` widget - Device-adaptive image rendering

**Features:**
- Automatic decode size optimization
- Device-tier-specific quality
- Loading transitions
- Error handling
- RepaintBoundary for performance

#### `widgets/optimized_list_view.dart`
Performance-optimized list view with device-adaptive scrolling.

**Exports:**
- `OptimizedListView` widget - Device-adaptive list rendering

**Features:**
- Automatic scroll optimization
- Pagination support via `onScrollEnd`
- Separator support
- Fixed item extent optimization
- Device-specific cache extent

### Startup & Extensions

#### `startup_optimization.dart`
App startup performance optimization utilities.

**Exports:**
- `StartupOptimization` class - Static utilities for startup optimization

**Features:**
- Track startup time
- Defer non-critical initialization
- Run initialization sequences
- Schedule tasks after first frame

#### `performance_extensions.dart`
Extension methods for BuildContext to access performance utilities.

**Exports:**
- `PerformanceContextExtension` - BuildContext extension

**Features:**
- `adjustedDuration()` - Get animation durations adjusted for device performance

## Migration Guide

### Before (Old Import)

```dart
import 'package:aiscan/core/utils/performance_utils.dart';

// Using device performance
final devicePerf = DevicePerformance();
final tier = DevicePerformance.tier;

// Using thumbnail cache
final cache = ref.read(thumbnailCacheProvider);

// Using debouncer
final debouncer = Debouncer(duration: Duration(milliseconds: 300));

// Using lazy loader
final loader = LazyLoader<Document>(
  loadPage: (page, pageSize) async => documents,
);
```

### After (New Imports)

#### Option 1: Import Specific Modules (Recommended)

```dart
// Import only what you need
import 'package:aiscan/core/performance/device_performance.dart';
import 'package:aiscan/core/performance/cache/thumbnail_cache_service.dart';
import 'package:aiscan/core/performance/rate_limiting.dart';
import 'package:aiscan/core/performance/lazy_loader.dart';

// Same usage as before
final devicePerf = DevicePerformance();
final tier = DevicePerformance.tier;
final cache = ref.read(thumbnailCacheProvider);
final debouncer = Debouncer(duration: Duration(milliseconds: 300));
final loader = LazyLoader<Document>(
  loadPage: (page, pageSize) async => documents,
);
```

#### Option 2: Import Barrel File (Convenience)

```dart
// Import all performance utilities at once
import 'package:aiscan/core/performance/performance.dart';

// Same usage as before
final devicePerf = DevicePerformance();
final tier = DevicePerformance.tier;
final cache = ref.read(thumbnailCacheProvider);
final debouncer = Debouncer(duration: Duration(milliseconds: 300));
final loader = LazyLoader<Document>(
  loadPage: (page, pageSize) async => documents,
);
```

### Real-World Migration Examples

#### Example 1: Documents Screen

**Before:**
```dart
import '../../../core/utils/performance_utils.dart';
```

**After:**
```dart
import '../../../core/performance/lazy_loader.dart';
import '../../../core/performance/rate_limiting.dart';
import '../../../core/performance/cache/thumbnail_cache_service.dart';
```

#### Example 2: Document Repository

**Before:**
```dart
import '../utils/performance_utils.dart';
```

**After:**
```dart
import '../performance/cache/thumbnail_cache_service.dart';
```

## Usage Examples

### Device Performance Detection

```dart
import 'package:aiscan/core/performance/device_performance.dart';

// Get device tier
final tier = DevicePerformance.tier;

// Adapt UI based on device capabilities
if (tier == DeviceTier.low) {
  // Use simpler UI for low-end devices
  return SimpleListView(items: items);
} else {
  // Use rich UI for better devices
  return AnimatedListView(items: items);
}

// Use with Riverpod
final devicePerf = ref.watch(devicePerformanceProvider);
final animationDuration = devicePerf.animationDuration;
```

### Performance Monitoring

```dart
import 'package:aiscan/core/performance/performance_monitor.dart';

// Monitor performance
final monitor = ref.read(performanceMonitorProvider);

// Start monitoring
await monitor.startMonitoring(
  duration: Duration(seconds: 5),
  onFrame: (fps) => print('Current FPS: $fps'),
);

// Get summary
final summary = monitor.summary;
print('Average FPS: ${summary.averageFps}');
print('Frame drops: ${summary.droppedFrameCount}');
```

### Caching

```dart
import 'package:aiscan/core/performance/cache/image_cache_manager.dart';
import 'package:aiscan/core/performance/cache/thumbnail_cache_service.dart';

// Image caching
final imageCache = ImageCacheManager(
  maxSize: 50 * 1024 * 1024, // 50MB
  maxItems: 100,
);

await imageCache.put('image_key', imageBytes);
final cachedImage = await imageCache.get('image_key');

// Thumbnail caching with Riverpod
final thumbnailCache = ref.read(thumbnailCacheProvider);
await thumbnailCache.cacheThumbnail('doc_id', thumbnailBytes);
final thumbnail = await thumbnailCache.getThumbnail('doc_id');
```

### Rate Limiting

```dart
import 'package:aiscan/core/performance/rate_limiting.dart';

// Debouncing (wait for calls to stop)
final searchDebouncer = Debouncer(
  duration: Duration(milliseconds: 300),
);

TextField(
  onChanged: (query) {
    searchDebouncer.call(() {
      // This only executes 300ms after user stops typing
      performSearch(query);
    });
  },
);

// Throttling (limit execution rate)
final scrollThrottler = Throttler(
  duration: Duration(milliseconds: 100),
);

ListView(
  onScroll: (offset) {
    scrollThrottler.call(() {
      // This executes at most once per 100ms
      updateScrollPosition(offset);
    });
  },
);
```

### Lazy Loading

```dart
import 'package:aiscan/core/performance/lazy_loader.dart';

// Create lazy loader with pagination
final documentLoader = LazyLoader<Document>(
  loadPage: (page, pageSize) async {
    final response = await api.getDocuments(
      page: page,
      limit: pageSize,
    );
    return response.documents;
  },
  pageSize: 20,
  preloadThreshold: 5, // Load next page when 5 items from end
);

// Load initial data
await documentLoader.loadNextPage();

// Access items
final documents = documentLoader.items;
final isLoading = documentLoader.isLoading;

// Use in ListView
ListView.builder(
  itemCount: documentLoader.items.length,
  itemBuilder: (context, index) {
    // Trigger preload
    if (index >= documentLoader.items.length - 5) {
      documentLoader.loadNextPage();
    }
    return DocumentTile(document: documentLoader.items[index]);
  },
);
```

### Memory Management

```dart
import 'package:aiscan/core/performance/memory_manager.dart';
import 'package:aiscan/core/performance/device_performance.dart';

// Configure for device
final deviceTier = DevicePerformance.tier;
await MemoryManager.configureForDevice(deviceTier);

// Clear caches when memory is low
await MemoryManager.clearImageCache();

// Suggest garbage collection
MemoryManager.suggestGarbageCollection();
```

### Optimized Widgets

```dart
import 'package:aiscan/core/performance/widgets/optimized_image.dart';
import 'package:aiscan/core/performance/widgets/optimized_list_view.dart';

// Optimized image widget
OptimizedImage(
  imageProvider: NetworkImage('https://example.com/image.jpg'),
  width: 200,
  height: 200,
  fit: BoxFit.cover,
);

// Optimized list view
OptimizedListView(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemTile(items[index]),
  onScrollEnd: () {
    // Load more items (pagination)
    loadMoreItems();
  },
  separated: true, // Add separators
  fixedItemExtent: 80.0, // Fixed height for better performance
);
```

### Startup Optimization

```dart
import 'package:aiscan/core/performance/startup_optimization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mark app start
  StartupOptimization.markStart();

  // Critical initialization only
  await initializeServices();

  // Mark initialized
  StartupOptimization.markInitialized();

  runApp(MyApp());

  // Defer non-critical tasks until after first frame
  StartupOptimization.deferAfterFirstFrame(() async {
    await initializeAnalytics();
    await preloadCaches();
  });

  // Or defer with delay
  StartupOptimization.deferWithDelay(
    Duration(seconds: 2),
    () async {
      await syncBackgroundData();
    },
  );
}
```

### Performance Extensions

```dart
import 'package:aiscan/core/performance/performance_extensions.dart';

// In a widget
AnimatedContainer(
  duration: context.adjustedDuration(Duration(milliseconds: 300)),
  // Animation duration automatically adjusted for device performance
  // Low-end devices get shorter durations for smoother experience
  child: child,
);
```

## Best Practices

### Import Strategy

1. **Import specific modules** when you only need a few utilities:
   ```dart
   import 'package:aiscan/core/performance/device_performance.dart';
   import 'package:aiscan/core/performance/rate_limiting.dart';
   ```

2. **Import the barrel file** when you need multiple utilities from different modules:
   ```dart
   import 'package:aiscan/core/performance/performance.dart';
   ```

3. **Avoid importing both** the barrel file and specific modules to prevent redundant imports.

### Device Adaptation

Always adapt your UI based on device capabilities:

```dart
final devicePerf = ref.watch(devicePerformanceProvider);

// Adapt cache sizes
final cacheSize = switch (devicePerf.tier) {
  DeviceTier.low => 10 * 1024 * 1024,    // 10MB
  DeviceTier.medium => 30 * 1024 * 1024, // 30MB
  DeviceTier.high => 100 * 1024 * 1024,  // 100MB
};

// Adapt animation complexity
final enableComplexAnimations = devicePerf.tier != DeviceTier.low;
```

### Caching Strategy

1. **Use appropriate cache for the data type:**
   - `ImageCacheManager` for general image data
   - `ThumbnailCacheService` for document thumbnails

2. **Set cache limits based on device:**
   ```dart
   await MemoryManager.configureForDevice(DevicePerformance.tier);
   ```

3. **Monitor cache statistics:**
   ```dart
   final stats = imageCache.getStats();
   print('Hit rate: ${stats.hitRate}');
   ```

### Rate Limiting

1. **Use Debouncer for search/input:**
   - Waits until user stops typing before executing

2. **Use Throttler for scroll/drag:**
   - Ensures function doesn't execute too frequently

3. **Always dispose rate limiters:**
   ```dart
   @override
   void dispose() {
     debouncer.dispose();
     throttler.dispose();
     super.dispose();
   }
   ```

### Performance Monitoring

1. **Monitor during development** to catch performance issues early
2. **Use in specific scenarios** rather than always-on to minimize overhead
3. **Log performance summaries** to track improvements over time

### Memory Management

1. **Clear caches on low memory warnings:**
   ```dart
   SystemChannels.lifecycle.setMessageHandler((message) async {
     if (message == AppLifecycleState.paused.toString()) {
       await MemoryManager.clearImageCache();
     }
     return null;
   });
   ```

2. **Configure on app startup:**
   ```dart
   await MemoryManager.configureForDevice(DevicePerformance.tier);
   ```

## Testing

All modules have comprehensive unit tests located in `test/core/performance/`:

- `device_performance_test.dart` - 55 tests covering device detection and tier classification
- `cache/image_cache_manager_test.dart` - Tests for image caching
- `cache/thumbnail_cache_service_test.dart` - Tests for thumbnail caching
- `rate_limiting_test.dart` - 28 tests for Debouncer and Throttler

Run tests with:
```bash
# Test all performance modules
flutter test test/core/performance/

# Test specific module
flutter test test/core/performance/device_performance_test.dart
```

## Module Dependencies

Understanding module dependencies helps with efficient imports:

```
device_performance.dart (no dependencies)
  ↓
  ├─ memory_manager.dart
  ├─ cache/thumbnail_cache_service.dart
  ├─ optimization/scroll_optimization.dart
  ├─ optimization/image_optimization.dart
  ├─ widgets/optimized_image.dart
  └─ widgets/optimized_list_view.dart

performance_monitor.dart (no dependencies)

cache/image_cache_manager.dart (no dependencies)
  ↓
  ├─ cache/thumbnail_cache_service.dart
  └─ optimization/image_optimization.dart

rate_limiting.dart (no dependencies)
lazy_loader.dart (no dependencies)
startup_optimization.dart (no dependencies)
performance_extensions.dart (depends on device_performance)
```

## Migration Checklist

When migrating from `performance_utils.dart`:

- [ ] Identify which utilities your file uses
- [ ] Replace the old import with specific module imports
- [ ] Verify no compilation errors
- [ ] Run tests to ensure functionality is preserved
- [ ] Run `dart analyze` to check for any issues
- [ ] Consider using the barrel file if importing many modules

## Performance Comparison

### Before Refactoring
- Single file: 1,579 lines
- Tightly coupled components
- Difficult to test individual utilities
- Hard to understand module boundaries

### After Refactoring
- 13 focused modules averaging ~120 lines each
- Clear separation of concerns
- Each module independently testable
- Easy to understand and maintain
- Better code reusability

## Summary

The performance modules refactoring provides:

✅ **Better Organization** - Each module has a single, clear responsibility
✅ **Improved Maintainability** - Easier to modify individual components
✅ **Enhanced Testability** - Each module can be tested in isolation
✅ **Clearer Dependencies** - Explicit imports show what each file needs
✅ **Better Documentation** - Focused documentation per module
✅ **Easier Onboarding** - New developers can understand modules quickly
✅ **Flexible Imports** - Import only what you need or use barrel file

For questions or issues, refer to the inline documentation in each module file or check the unit tests for usage examples.
