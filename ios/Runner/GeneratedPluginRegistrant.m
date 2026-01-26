//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<aes_encrypt_file/AesEncryptFilePlugin.h>)
#import <aes_encrypt_file/AesEncryptFilePlugin.h>
#else
@import aes_encrypt_file;
#endif

#if __has_include(<audioplayers_darwin/AudioplayersDarwinPlugin.h>)
#import <audioplayers_darwin/AudioplayersDarwinPlugin.h>
#else
@import audioplayers_darwin;
#endif

#if __has_include(<file_picker/FilePickerPlugin.h>)
#import <file_picker/FilePickerPlugin.h>
#else
@import file_picker;
#endif

#if __has_include(<flutter_native_splash/FlutterNativeSplashPlugin.h>)
#import <flutter_native_splash/FlutterNativeSplashPlugin.h>
#else
@import flutter_native_splash;
#endif

#if __has_include(<flutter_secure_storage_darwin/FlutterSecureStorageDarwinPlugin.h>)
#import <flutter_secure_storage_darwin/FlutterSecureStorageDarwinPlugin.h>
#else
@import flutter_secure_storage_darwin;
#endif

#if __has_include(<flutter_tesseract_ocr/FlutterTesseractOcrPlugin.h>)
#import <flutter_tesseract_ocr/FlutterTesseractOcrPlugin.h>
#else
@import flutter_tesseract_ocr;
#endif

#if __has_include(<google_mlkit_commons/GoogleMlKitCommonsPlugin.h>)
#import <google_mlkit_commons/GoogleMlKitCommonsPlugin.h>
#else
@import google_mlkit_commons;
#endif

#if __has_include(<google_mlkit_document_scanner/GoogleMlKitDocumentScannerPlugin.h>)
#import <google_mlkit_document_scanner/GoogleMlKitDocumentScannerPlugin.h>
#else
@import google_mlkit_document_scanner;
#endif

#if __has_include(<google_mlkit_text_recognition/GoogleMlKitTextRecognitionPlugin.h>)
#import <google_mlkit_text_recognition/GoogleMlKitTextRecognitionPlugin.h>
#else
@import google_mlkit_text_recognition;
#endif

#if __has_include(<local_auth_darwin/LocalAuthPlugin.h>)
#import <local_auth_darwin/LocalAuthPlugin.h>
#else
@import local_auth_darwin;
#endif

#if __has_include(<native_camera_sound/NativeCameraSoundPlugin.h>)
#import <native_camera_sound/NativeCameraSoundPlugin.h>
#else
@import native_camera_sound;
#endif

#if __has_include(<permission_handler_apple/PermissionHandlerPlugin.h>)
#import <permission_handler_apple/PermissionHandlerPlugin.h>
#else
@import permission_handler_apple;
#endif

#if __has_include(<printing/PrintingPlugin.h>)
#import <printing/PrintingPlugin.h>
#else
@import printing;
#endif

#if __has_include(<share_plus/FPPSharePlusPlugin.h>)
#import <share_plus/FPPSharePlusPlugin.h>
#else
@import share_plus;
#endif

#if __has_include(<shared_preferences_foundation/SharedPreferencesPlugin.h>)
#import <shared_preferences_foundation/SharedPreferencesPlugin.h>
#else
@import shared_preferences_foundation;
#endif

#if __has_include(<sqflite_darwin/SqflitePlugin.h>)
#import <sqflite_darwin/SqflitePlugin.h>
#else
@import sqflite_darwin;
#endif

#if __has_include(<sqflite_sqlcipher/SqfliteSqlCipherPlugin.h>)
#import <sqflite_sqlcipher/SqfliteSqlCipherPlugin.h>
#else
@import sqflite_sqlcipher;
#endif

#if __has_include(<sqlcipher_flutter_libs/Sqlite3FlutterLibsPlugin.h>)
#import <sqlcipher_flutter_libs/Sqlite3FlutterLibsPlugin.h>
#else
@import sqlcipher_flutter_libs;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [AesEncryptFilePlugin registerWithRegistrar:[registry registrarForPlugin:@"AesEncryptFilePlugin"]];
  [AudioplayersDarwinPlugin registerWithRegistrar:[registry registrarForPlugin:@"AudioplayersDarwinPlugin"]];
  [FilePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FilePickerPlugin"]];
  [FlutterNativeSplashPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterNativeSplashPlugin"]];
  [FlutterSecureStorageDarwinPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterSecureStorageDarwinPlugin"]];
  [FlutterTesseractOcrPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterTesseractOcrPlugin"]];
  [GoogleMlKitCommonsPlugin registerWithRegistrar:[registry registrarForPlugin:@"GoogleMlKitCommonsPlugin"]];
  [GoogleMlKitDocumentScannerPlugin registerWithRegistrar:[registry registrarForPlugin:@"GoogleMlKitDocumentScannerPlugin"]];
  [GoogleMlKitTextRecognitionPlugin registerWithRegistrar:[registry registrarForPlugin:@"GoogleMlKitTextRecognitionPlugin"]];
  [LocalAuthPlugin registerWithRegistrar:[registry registrarForPlugin:@"LocalAuthPlugin"]];
  [NativeCameraSoundPlugin registerWithRegistrar:[registry registrarForPlugin:@"NativeCameraSoundPlugin"]];
  [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
  [PrintingPlugin registerWithRegistrar:[registry registrarForPlugin:@"PrintingPlugin"]];
  [FPPSharePlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPSharePlusPlugin"]];
  [SharedPreferencesPlugin registerWithRegistrar:[registry registrarForPlugin:@"SharedPreferencesPlugin"]];
  [SqflitePlugin registerWithRegistrar:[registry registrarForPlugin:@"SqflitePlugin"]];
  [SqfliteSqlCipherPlugin registerWithRegistrar:[registry registrarForPlugin:@"SqfliteSqlCipherPlugin"]];
  [Sqlite3FlutterLibsPlugin registerWithRegistrar:[registry registrarForPlugin:@"Sqlite3FlutterLibsPlugin"]];
}

@end
