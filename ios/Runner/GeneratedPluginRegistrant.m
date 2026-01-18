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

#if __has_include(<flutter_contacts/FlutterContactsPlugin.h>)
#import <flutter_contacts/FlutterContactsPlugin.h>
#else
@import flutter_contacts;
#endif

#if __has_include(<flutter_secure_storage/FlutterSecureStoragePlugin.h>)
#import <flutter_secure_storage/FlutterSecureStoragePlugin.h>
#else
@import flutter_secure_storage;
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

#if __has_include(<path_provider_foundation/PathProviderPlugin.h>)
#import <path_provider_foundation/PathProviderPlugin.h>
#else
@import path_provider_foundation;
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

#if __has_include(<sqflite_darwin/SqflitePlugin.h>)
#import <sqflite_darwin/SqflitePlugin.h>
#else
@import sqflite_darwin;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [AesEncryptFilePlugin registerWithRegistrar:[registry registrarForPlugin:@"AesEncryptFilePlugin"]];
  [AudioplayersDarwinPlugin registerWithRegistrar:[registry registrarForPlugin:@"AudioplayersDarwinPlugin"]];
  [FlutterContactsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterContactsPlugin"]];
  [FlutterSecureStoragePlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterSecureStoragePlugin"]];
  [FlutterTesseractOcrPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterTesseractOcrPlugin"]];
  [GoogleMlKitCommonsPlugin registerWithRegistrar:[registry registrarForPlugin:@"GoogleMlKitCommonsPlugin"]];
  [GoogleMlKitDocumentScannerPlugin registerWithRegistrar:[registry registrarForPlugin:@"GoogleMlKitDocumentScannerPlugin"]];
  [GoogleMlKitTextRecognitionPlugin registerWithRegistrar:[registry registrarForPlugin:@"GoogleMlKitTextRecognitionPlugin"]];
  [LocalAuthPlugin registerWithRegistrar:[registry registrarForPlugin:@"LocalAuthPlugin"]];
  [NativeCameraSoundPlugin registerWithRegistrar:[registry registrarForPlugin:@"NativeCameraSoundPlugin"]];
  [PathProviderPlugin registerWithRegistrar:[registry registrarForPlugin:@"PathProviderPlugin"]];
  [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
  [PrintingPlugin registerWithRegistrar:[registry registrarForPlugin:@"PrintingPlugin"]];
  [FPPSharePlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPSharePlusPlugin"]];
  [SqflitePlugin registerWithRegistrar:[registry registrarForPlugin:@"SqflitePlugin"]];
}

@end
