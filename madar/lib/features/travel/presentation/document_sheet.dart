import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../data/travel_service.dart';
import '../domain/documents.dart';
import '../domain/trip_timeline.dart';
import '../travel_texts.dart';
import 'widgets/travel_widgets.dart';

/// Opens the document editor (new, or [document]). Returns the draft to
/// save, or null.
Future<DocumentDraft?> showDocumentSheet(BuildContext context, {TravelDocumentRow? document, DateTime? today}) async {
  final r = await showInteractionSheet<Map<String, Object?>>(
    context,
    builder: (_) => DocumentSheet(document: document, today: today),
  );
  return r == null ? null : DocumentSheet.draftOf(r);
}

/// The document editor on the interaction kit's edit sheet: name, holder,
/// number, expiry, how early to remind, notes – with a live preview of the
/// document's icon and its expiry countdown.
class DocumentSheet extends StatelessWidget {
  const DocumentSheet({super.key, this.document, this.today});

  final TravelDocumentRow? document;

  /// "Today" of the preview (defaults to the device's).
  final DateTime? today;

  static DocumentDraft draftOf(Map<String, Object?> r) => DocumentDraft(
    name: (r['name'] as String?)?.trim() ?? '',
    holder: r['holder'] as String?,
    number: r['number'] as String?,
    expiry: r['expiry'] as DateTime?,
    remindDaysBefore: int.tryParse('${r['remind'] ?? ''}') ?? 30,
    notes: r['notes'] as String?,
  );

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tx = TravelTexts.of(context);
    final d = document;
    final now = today ?? DateTime.now();
    final current = d?.remindDaysBefore ?? 30;
    final choices = {...TravelTexts.remindChoices, current}.toList()..sort();
    return EditSheet(
      title: d == null ? l.travelDocNew : l.travelDocEdit,
      subtitle: l.travelDocSubtitle,
      icon: Icons.badge_rounded,
      saveLabel: l.travelSave,
      fields: [
        FieldSpec.text(
          'name',
          l.travelDocName,
          required: true,
          hint: l.travelDocNameHint,
          icon: Icons.description_rounded,
          autofocus: d == null,
          validator: (v, _) => (v as String?)?.trim().isEmpty ?? true ? l.travelDocNameRequired : null,
        ),
        FieldSpec.text('holder', l.travelDocHolder, hint: l.travelDocHolderHint, icon: Icons.person_rounded),
        FieldSpec.text('number', l.travelDocNumber, icon: Icons.tag_rounded),
        FieldSpec.date(
          'expiry',
          l.travelDocExpiry,
          icon: Icons.event_busy_rounded,
          firstDate: DateTime(now.year - 20),
          lastDate: DateTime(now.year + 30, 12, 31),
        ),
        FieldSpec.singleSelect(
          'remind',
          l.travelDocRemind,
          required: true,
          icon: Icons.notifications_active_rounded,
          options: [for (final c in choices) SelectOption(id: '$c', label: tx.remindLabel(c))],
        ),
        FieldSpec.multiline('notes', l.travelFieldNotes, icon: Icons.notes_rounded),
      ],
      initial: {
        'name': d?.name,
        'holder': d?.holder,
        'number': d?.number,
        'expiry': d?.expiry,
        'remind': '$current',
        'notes': d?.notes,
      },
      preview: (context, v) => _Preview(values: v, today: TravelDates.day(now)),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.values, required this.today});

  final Map<String, Object?> values;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final text = Theme.of(context).textTheme;
    final name = (values['name'] as String?)?.trim() ?? '';
    final kind = TravelDocKind.infer(name);
    final expiry = values['expiry'] as DateTime?;
    final remind = int.tryParse('${values['remind'] ?? ''}') ?? 30;
    final e = DocumentExpiry.of(expiry: expiry, remindDaysBefore: remind, today: today);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.m),
      child: Row(
        children: [
          DocMedallion(kind: kind, tone: expiryTone(e.state)),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? tx.kind(kind) : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium!.copyWith(color: name.isEmpty ? t.textTertiary : t.textPrimary),
                ),
                const SizedBox(height: Space.xs),
                TravelPill(label: tx.expiry(e, on: expiry), tone: expiryTone(e.state), dense: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A document kind's round icon tinted by its expiry tone.
class DocMedallion extends StatelessWidget {
  const DocMedallion({super.key, required this.kind, required this.tone, this.size = 44});

  final TravelDocKind kind;
  final PillTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = pillColor(tone, t);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: t.isDark ? 0.14 : 0.1),
        border: Border.all(color: c.withValues(alpha: 0.55), width: 1.2),
        boxShadow: t.isDark ? [BoxShadow(color: c.withValues(alpha: 0.25), blurRadius: 12)] : null,
      ),
      child: Icon(docKindIcon(kind), size: size * 0.46, color: c),
    );
  }
}
