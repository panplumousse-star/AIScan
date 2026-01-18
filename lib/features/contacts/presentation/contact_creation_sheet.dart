import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/contact_permission_dialog.dart';
import '../../../core/permissions/contact_permission_service.dart';
import '../domain/contact_data_extractor.dart';
import '../domain/contact_service.dart';

/// Shows the contact creation bottom sheet.
///
/// Displays the extracted contact data and allows the user to:
/// - Select which items to include in the contact
/// - Edit the contact name
/// - Create the contact
///
/// Returns `true` if a contact was created, `false` otherwise.
Future<bool> showContactCreationSheet(
  BuildContext context, {
  required ExtractedContactData extractedData,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ContactCreationSheet(extractedData: extractedData),
  );
  return result ?? false;
}

/// Bottom sheet widget for creating a contact from extracted OCR data.
class ContactCreationSheet extends ConsumerStatefulWidget {
  /// Creates a [ContactCreationSheet] with the extracted data.
  const ContactCreationSheet({
    super.key,
    required this.extractedData,
  });

  /// The extracted contact data from OCR.
  final ExtractedContactData extractedData;

  @override
  ConsumerState<ContactCreationSheet> createState() => _ContactCreationSheetState();
}

class _ContactCreationSheetState extends ConsumerState<ContactCreationSheet> {
  late TextEditingController _nameController;
  late Set<String> _selectedEmails;
  late Set<String> _selectedPhones;
  late Set<String> _selectedAddresses;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.extractedData.possibleName ?? '',
    );
    _selectedEmails = widget.extractedData.emails.toSet();
    _selectedPhones = widget.extractedData.phoneNumbers.toSet();
    _selectedAddresses = widget.extractedData.addresses.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _hasSelection =>
      _selectedEmails.isNotEmpty ||
      _selectedPhones.isNotEmpty ||
      _selectedAddresses.isNotEmpty;

  bool get _canCreate =>
      _nameController.text.trim().isNotEmpty && _hasSelection && !_isCreating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.contact_page_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Create Contact',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Select the information to include in the new contact',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Divider(height: 24),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Name input
                    _buildNameInput(context),
                    const SizedBox(height: 24),
                    // Emails section
                    if (widget.extractedData.emails.isNotEmpty) ...[
                      _buildSection(
                        context,
                        title: 'Emails',
                        icon: Icons.email_outlined,
                        items: widget.extractedData.emails,
                        selectedItems: _selectedEmails,
                        onToggle: (email) {
                          setState(() {
                            if (_selectedEmails.contains(email)) {
                              _selectedEmails.remove(email);
                            } else {
                              _selectedEmails.add(email);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Phone numbers section
                    if (widget.extractedData.phoneNumbers.isNotEmpty) ...[
                      _buildSection(
                        context,
                        title: 'Phone Numbers',
                        icon: Icons.phone_outlined,
                        items: widget.extractedData.phoneNumbers,
                        selectedItems: _selectedPhones,
                        onToggle: (phone) {
                          setState(() {
                            if (_selectedPhones.contains(phone)) {
                              _selectedPhones.remove(phone);
                            } else {
                              _selectedPhones.add(phone);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Addresses section
                    if (widget.extractedData.addresses.isNotEmpty) ...[
                      _buildSection(
                        context,
                        title: 'Addresses',
                        icon: Icons.location_on_outlined,
                        items: widget.extractedData.addresses,
                        selectedItems: _selectedAddresses,
                        onToggle: (address) {
                          setState(() {
                            if (_selectedAddresses.contains(address)) {
                              _selectedAddresses.remove(address);
                            } else {
                              _selectedAddresses.add(address);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Bottom padding for keyboard
                    SizedBox(height: bottomPadding + 100),
                  ],
                ),
              ),
              // Action bar
              _buildActionBar(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNameInput(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Contact Name',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Enter contact name',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<String> items,
    required Set<String> selectedItems,
    required void Function(String) onToggle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${selectedItems.length}/${items.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _buildCheckboxTile(
              context,
              value: item,
              isSelected: selectedItems.contains(item),
              onToggle: () => onToggle(item),
            )),
      ],
    );
  }

  Widget _buildCheckboxTile(
    BuildContext context, {
    required String value,
    required bool isSelected,
    required VoidCallback onToggle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer.withOpacity(0.5)
            : colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 22,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isCreating ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _canCreate ? _createContact : null,
              icon: _isCreating
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.person_add),
              label: Text(_isCreating ? 'Creating...' : 'Create Contact'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createContact() async {
    if (!_canCreate) return;

    setState(() => _isCreating = true);

    final contactService = ref.read(contactServiceProvider);

    // Check/request permission
    if (!await contactService.hasPermission()) {
      final state = await contactService.requestPermission();

      if (state != ContactPermissionState.granted &&
          state != ContactPermissionState.sessionOnly) {
        // Check if blocked
        if (await contactService.isPermissionBlocked()) {
          if (!mounted) return;
          final shouldOpenSettings = await showContactSettingsDialog(context);
          if (shouldOpenSettings == true) {
            await contactService.openSettings();
            contactService.clearPermissionCache();
          }
        }
        setState(() => _isCreating = false);
        if (mounted) {
          showContactPermissionDeniedSnackbar(context);
        }
        return;
      }
    }

    // Create contact data
    final data = ContactCreationData(
      name: _nameController.text.trim(),
      selectedEmails: _selectedEmails.toList(),
      selectedPhones: _selectedPhones.toList(),
      selectedAddresses: _selectedAddresses.toList(),
    );

    // Create the contact
    final result = await contactService.createContact(data);

    setState(() => _isCreating = false);

    if (!mounted) return;

    switch (result) {
      case ContactCreationSuccess(:final contactName):
        showContactCreatedSnackbar(context, contactName);
        Navigator.pop(context, true);
      case ContactCreationFailure(:final message):
        showContactCreationErrorSnackbar(context);
        debugPrint('Contact creation failed: $message');
      case ContactCreationCancelled():
        showContactPermissionDeniedSnackbar(context);
    }
  }
}
