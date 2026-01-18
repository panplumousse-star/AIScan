import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/contact_permission_service.dart';
import 'contact_data_extractor.dart';

/// Riverpod provider for [ContactService].
final contactServiceProvider = Provider<ContactService>((ref) {
  final permissionService = ref.watch(contactPermissionServiceProvider);
  return ContactService(permissionService: permissionService);
});

/// Result of a contact creation operation.
sealed class ContactCreationResult {
  const ContactCreationResult();
}

/// Contact was created successfully.
class ContactCreationSuccess extends ContactCreationResult {
  const ContactCreationSuccess({
    required this.contactId,
    required this.contactName,
  });

  /// The ID of the created contact in the system.
  final String contactId;

  /// The display name of the created contact.
  final String contactName;
}

/// Contact creation failed due to an error.
class ContactCreationFailure extends ContactCreationResult {
  const ContactCreationFailure({
    required this.message,
    this.cause,
  });

  /// Human-readable error message.
  final String message;

  /// The underlying exception, if any.
  final Object? cause;
}

/// Contact creation was cancelled (e.g., permission denied).
class ContactCreationCancelled extends ContactCreationResult {
  const ContactCreationCancelled({this.reason});

  /// Optional reason for cancellation.
  final String? reason;
}

/// Data to create a new contact.
///
/// This class represents the user's selection from the extracted data,
/// where they can choose which items to include in the contact.
class ContactCreationData {
  const ContactCreationData({
    required this.name,
    this.selectedEmails = const [],
    this.selectedPhones = const [],
    this.selectedAddresses = const [],
    this.organization,
    this.notes,
  });

  /// The contact's display name.
  final String name;

  /// Selected email addresses to include.
  final List<String> selectedEmails;

  /// Selected phone numbers to include.
  final List<String> selectedPhones;

  /// Selected addresses to include.
  final List<String> selectedAddresses;

  /// Optional organization/company name.
  final String? organization;

  /// Optional notes.
  final String? notes;

  /// Creates from extracted data with all items selected.
  factory ContactCreationData.fromExtracted(
    ExtractedContactData extracted, {
    String? name,
  }) {
    return ContactCreationData(
      name: name ?? extracted.possibleName ?? 'Unknown',
      selectedEmails: extracted.emails,
      selectedPhones: extracted.phoneNumbers,
      selectedAddresses: extracted.addresses,
    );
  }

  /// Returns true if there's any contact data to save.
  bool get hasData =>
      name.isNotEmpty &&
      (selectedEmails.isNotEmpty ||
          selectedPhones.isNotEmpty ||
          selectedAddresses.isNotEmpty);

  ContactCreationData copyWith({
    String? name,
    List<String>? selectedEmails,
    List<String>? selectedPhones,
    List<String>? selectedAddresses,
    String? organization,
    String? notes,
    bool clearOrganization = false,
    bool clearNotes = false,
  }) {
    return ContactCreationData(
      name: name ?? this.name,
      selectedEmails: selectedEmails ?? this.selectedEmails,
      selectedPhones: selectedPhones ?? this.selectedPhones,
      selectedAddresses: selectedAddresses ?? this.selectedAddresses,
      organization:
          clearOrganization ? null : (organization ?? this.organization),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}

/// Service for creating contacts on the device.
///
/// Uses the flutter_contacts package to interact with the system contacts
/// and requires appropriate permissions.
///
/// ## Usage
/// ```dart
/// final service = ref.read(contactServiceProvider);
///
/// // Check permission first
/// if (await service.hasPermission()) {
///   final result = await service.createContact(data);
///   if (result is ContactCreationSuccess) {
///     // Contact created successfully
///   }
/// }
/// ```
class ContactService {
  /// Creates a [ContactService] with the given permission service.
  const ContactService({
    required ContactPermissionService permissionService,
  }) : _permissionService = permissionService;

  final ContactPermissionService _permissionService;

  /// Checks if contact permission is granted.
  Future<bool> hasPermission() async {
    final state = await _permissionService.checkPermission();
    return state == ContactPermissionState.granted ||
        state == ContactPermissionState.sessionOnly;
  }

  /// Requests contact permission from the user.
  ///
  /// Returns the resulting permission state.
  Future<ContactPermissionState> requestPermission() async {
    if (await _permissionService.isFirstTimeRequest()) {
      return _permissionService.requestSystemPermission();
    }
    return _permissionService.checkPermission();
  }

  /// Checks if permission is blocked and requires settings redirect.
  Future<bool> isPermissionBlocked() async {
    return _permissionService.isPermissionBlocked();
  }

  /// Opens app settings for the user to grant permission.
  Future<bool> openSettings() async {
    return _permissionService.openSettings();
  }

  /// Clears permission cache (call after returning from settings).
  void clearPermissionCache() {
    _permissionService.clearCache();
  }

  /// Creates a new contact with the given data.
  ///
  /// This method:
  /// 1. Validates the input data
  /// 2. Checks for permission
  /// 3. Creates the contact using flutter_contacts
  /// 4. Returns the result
  ///
  /// Returns [ContactCreationSuccess] if the contact was created,
  /// [ContactCreationFailure] if an error occurred, or
  /// [ContactCreationCancelled] if permission was denied.
  Future<ContactCreationResult> createContact(ContactCreationData data) async {
    // Validate input
    if (data.name.trim().isEmpty) {
      return const ContactCreationFailure(
        message: 'Contact name cannot be empty',
      );
    }

    if (!data.hasData) {
      return const ContactCreationFailure(
        message: 'No contact information provided',
      );
    }

    // Check permission
    final hasContactPermission = await hasPermission();
    if (!hasContactPermission) {
      return const ContactCreationCancelled(
        reason: 'Contact permission not granted',
      );
    }

    try {
      // Build the contact
      final contact = Contact(
        name: _buildName(data.name),
        emails: data.selectedEmails
            .map((e) => Email(e, label: EmailLabel.work))
            .toList(),
        phones: data.selectedPhones
            .map((p) => Phone(p, label: PhoneLabel.mobile))
            .toList(),
        addresses: data.selectedAddresses
            .map((a) => Address(a, label: AddressLabel.work))
            .toList(),
        organizations: data.organization != null
            ? [Organization(company: data.organization!)]
            : [],
        notes: data.notes != null ? [Note(data.notes!)] : [],
      );

      // Insert the contact
      final newContact = await FlutterContacts.insertContact(contact);

      return ContactCreationSuccess(
        contactId: newContact.id,
        contactName: newContact.displayName,
      );
    } catch (e) {
      return ContactCreationFailure(
        message: 'Failed to create contact',
        cause: e,
      );
    }
  }

  /// Builds a Name object from a display name string.
  Name _buildName(String displayName) {
    final parts = displayName.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty) {
      return Name(first: displayName);
    }

    if (parts.length == 1) {
      return Name(first: parts[0]);
    }

    // First word is first name, rest is last name
    final firstName = parts[0];
    final lastName = parts.sublist(1).join(' ');

    return Name(
      first: firstName,
      last: lastName,
    );
  }

  /// Opens the system contact editor with pre-filled data.
  ///
  /// This allows the user to review and edit the contact before saving.
  /// Returns the created contact ID if saved, or null if cancelled.
  Future<String?> openContactEditor(ContactCreationData data) async {
    final hasContactPermission = await hasPermission();
    if (!hasContactPermission) {
      return null;
    }

    try {
      final contact = Contact(
        name: _buildName(data.name),
        emails: data.selectedEmails
            .map((e) => Email(e, label: EmailLabel.work))
            .toList(),
        phones: data.selectedPhones
            .map((p) => Phone(p, label: PhoneLabel.mobile))
            .toList(),
        addresses: data.selectedAddresses
            .map((a) => Address(a, label: AddressLabel.work))
            .toList(),
        organizations: data.organization != null
            ? [Organization(company: data.organization!)]
            : [],
        notes: data.notes != null ? [Note(data.notes!)] : [],
      );

      // Open external form for user to edit
      final result = await FlutterContacts.openExternalInsert(contact);
      return result?.id;
    } catch (e) {
      return null;
    }
  }
}
