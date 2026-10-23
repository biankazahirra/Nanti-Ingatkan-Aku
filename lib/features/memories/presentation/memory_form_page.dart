import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants.dart';
import '../../../core/failures.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/messages.dart';
import '../../reminders/domain/reminder_repository.dart';
import '../../reminders/presentation/reminder_editor.dart';
import '../domain/memory.dart';
import '../domain/memory_validation.dart';
import 'memory_detail_page.dart';
import 'widgets.dart';

/// F1/F2 and FR-MEM-01/03/06 — one form for create and edit.
class MemoryFormPage extends ConsumerStatefulWidget {
  const MemoryFormPage({super.key, this.memory});

  /// null = create.
  final Memory? memory;

  bool get isEditing => memory != null;

  @override
  ConsumerState<MemoryFormPage> createState() => _MemoryFormPageState();
}

class _MemoryFormPageState extends ConsumerState<MemoryFormPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _personController;
  late final TextEditingController _itemController;

  final FocusNode _titleFocus = FocusNode();
  final FocusNode _bodyFocus = FocusNode();

  late MemoryCategory _category;
  DateTime? _warrantyEnd;
  bool _reminderEnabled = false;
  PendingReminder? _reminder;
  bool _saving = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    final memory = widget.memory;
    _titleController = TextEditingController(text: memory?.title ?? '');
    _bodyController = TextEditingController(text: memory?.body ?? '');
    _personController = TextEditingController(text: memory?.personName ?? '');
    _itemController = TextEditingController(text: memory?.itemName ?? '');
    _category = memory?.category ?? MemoryCategory.general;
    final warrantyEnd = memory?.warrantyEndDate;
    _warrantyEnd = warrantyEnd == null ? null : DateTime.tryParse(warrantyEnd);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _personController.dispose();
    _itemController.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _titleController.text.trim().isNotEmpty ||
      _bodyController.text.trim().isNotEmpty ||
      _personController.text.trim().isNotEmpty ||
      _itemController.text.trim().isNotEmpty ||
      _reminder != null ||
      _category != (widget.memory?.category ?? MemoryCategory.general);

  MemoryDraft get _draft => MemoryDraft(
    title: _titleController.text,
    body: _bodyController.text,
    category: _category,
    personName: _category.supportsPersonName ? _personController.text : null,
    itemName: _category.supportsItemName ? _itemController.text : null,
    warrantyEndDate: _category.supportsWarrantyEnd && _warrantyEnd != null
        ? DateFormats.isoDate(_warrantyEnd!)
        : null,
  );

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.draftDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.draftKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.draftDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final deps = ref.read(depsProvider);
    final draft = _draft;
    final errors = validateDraft(draft);
    if (errors.isNotEmpty) {
      setState(
        () => _inlineError = messageForKey(l10n, errors.first.messageKey),
      );
      switch (errors.first.field) {
        case MemoryField.title:
          _titleFocus.requestFocus();
        case MemoryField.body:
          _bodyFocus.requestFocus();
        case MemoryField.personName:
        case MemoryField.itemName:
        case MemoryField.warrantyEndDate:
          break;
      }
      return;
    }

    final pending = _reminder;
    if (_reminderEnabled && pending == null) {
      setState(() => _inlineError = l10n.reminderPick);
      return;
    }
    if (pending != null && !pending.isFuture(deps.clock.nowUtc())) {
      setState(() => _inlineError = l10n.errorDuePast);
      return;
    }

    setState(() {
      _saving = true;
      _inlineError = null;
    });

    try {
      final memory = widget.isEditing
          ? await deps.memories.update(widget.memory!.id, draft)
          : await deps.memories.create(draft);

      if (!widget.isEditing && pending != null) {
        await deps.reminders.save(
          ReminderRequest(
            memoryId: memory.id,
            dueAtUtc: pending.dueAtUtc,
            scheduledLocalDatetime: pending.scheduledLocalDatetime,
            scheduledTimezone: pending.zoneId,
          ),
        );
      }

      ref.invalidate(todayProvider);
      ref.invalidate(settingsStateProvider);

      if (!mounted) return;
      if (widget.isEditing) {
        Navigator.of(context).pop(true);
        return;
      }
      // F1 step 4 — land on the detail screen with a confirmation.
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              MemoryDetailPage(memoryId: memory.id, savedConfirmation: true),
        ),
      );
    } on Failure catch (failure) {
      // FR: keep the draft on screen, offer retry.
      setState(() {
        _saving = false;
        _inlineError = messageForKey(l10n, failure.messageKey);
      });
    } on Object {
      setState(() {
        _saving = false;
        _inlineError = l10n.errorSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deps = ref.watch(depsProvider);
    final composer = ReminderComposer(
      zone: deps.clock.zone,
      nowUtc: deps.clock.nowUtc(),
    );
    final titleLength = graphemeLength(_titleController.text);
    final bodyLength = graphemeLength(_bodyController.text);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          navigator.pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing ? l10n.captureEditTitle : l10n.captureNewTitle,
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(l10n.captureSave),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocus,
                autofocus: !widget.isEditing,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.captureTitleHint,
                  border: const OutlineInputBorder(),
                  counterText: titleLength > Limits.titleCounterThreshold
                      ? l10n.captureTitleCounter(titleLength, Limits.titleMax)
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _bodyController,
                focusNode: _bodyFocus,
                maxLines: 6,
                minLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.captureBodyHint,
                  border: const OutlineInputBorder(),
                  counterText: bodyLength > Limits.bodyMax - 500
                      ? l10n.captureBodyCounter(bodyLength, Limits.bodyMax)
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CategoryChips(
                selected: _category,
                onSelected: (category) async {
                  if (category == null) return;
                  await _changeCategory(category);
                },
              ),
            ),
            if (_category.supportsPersonName)
              _field(
                controller: _personController,
                label: l10n.fieldLentTo,
                maxLength: Limits.personNameMax,
              ),
            if (_category.supportsItemName)
              _field(
                controller: _itemController,
                label: l10n.fieldItemName,
                maxLength: Limits.itemNameMax,
              ),
            if (_category.supportsWarrantyEnd)
              ListTile(
                leading: const Icon(Icons.event_available),
                title: Text(l10n.fieldWarrantyEnd),
                subtitle: Text(
                  _warrantyEnd == null
                      ? l10n.fieldPickDate
                      : DateFormats.date(_warrantyEnd!),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickWarrantyEnd,
              ),
            if (!widget.isEditing)
              ReminderSection(
                composer: composer,
                enabled: _reminderEnabled,
                value: _reminder,
                onEnabledChanged: (enabled) async {
                  if (enabled && !await _confirmNotificationPermission()) {
                    return;
                  }
                  if (!mounted) return;
                  setState(() {
                    _reminderEnabled = enabled;
                    if (!enabled) _reminder = null;
                  });
                },
                onValueChanged: (value) => setState(() {
                  _reminder = value;
                  _inlineError = null;
                }),
                onError: (key) =>
                    setState(() => _inlineError = messageForKey(l10n, key)),
              ),
            if (_inlineError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  _inlineError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.captureSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required int maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          counterText: '${graphemeLength(controller.text)}/$maxLength',
        ),
      ),
    );
  }

  /// PRD §5.6 / FR-REM-06 — the OS prompt only follows an explanation, and only
  /// once the user has actually asked for a reminder. Declining leaves the
  /// switch off; it never blocks saving the memory itself.
  Future<bool> _confirmNotificationPermission() async {
    final l10n = AppLocalizations.of(context);
    final deps = ref.read(depsProvider);
    final granted = await ref.read(notificationPermissionProvider.future);
    if (granted) return true;
    if (!mounted) return false;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.permissionRationale),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.permissionRationaleCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.permissionRationaleContinue),
          ),
        ],
      ),
    );
    if (proceed != true) return false;
    await deps.notifications.ensurePermission();
    return true;
  }

  Future<void> _changeCategory(MemoryCategory category) async {
    final hasMetadata =
        _personController.text.trim().isNotEmpty ||
        _itemController.text.trim().isNotEmpty ||
        _warrantyEnd != null;
    if (hasMetadata) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.categoryChangeTitle),
          content: Text(l10n.categoryClearMetadata),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      _personController.clear();
      _itemController.clear();
      _warrantyEnd = null;
    }
    setState(() => _category = category);
  }

  Future<void> _pickWarrantyEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _warrantyEnd ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) {
      setState(() => _warrantyEnd = picked);
    }
  }
}
