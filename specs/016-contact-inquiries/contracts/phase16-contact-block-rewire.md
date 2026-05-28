# Contract — `ContactBlock` rewire

**Owner**: Sub-Phase H (`lib/features/listing_details/presentation/widgets/contact_block.dart`).

**Consumers**: Phase 13's `ListingDetailsPage._SuccessBody`.

## What changes vs Phase 13

The widget tree (three `OutlinedButton.icon` widgets — Call, WhatsApp, Send Inquiry — with their existing icons, label styles, ordering, and surrounding `Column` layout) is **preserved verbatim** per FR-001. Only the three tap-handler functions change:

- **Before (Phase 13)**: Each `onPressed` called `_showComingSoon(context, ...)` which floated a snackbar.
- **After (Phase 16)**: Each `onPressed` runs the real handler per FR-002..FR-005.

## Constructor signature change

```dart
// Phase 13
const ContactBlock({super.key})

// Phase 16
const ContactBlock({super.key, required this.listing})
final Listing listing;
```

The `Listing` argument supplies `phone`, `whatsapp`, `publisherUserId` to the wrapped `ContactCtaCubit`.

## Widget tree

```dart
@override
Widget build(BuildContext context) {
  return BlocProvider<ContactCtaCubit>(
    create: (_) => getIt<ContactCtaCubit>(param1: listing),
    child: BlocBuilder<ContactCtaCubit, ContactCtaState>(
      builder: (context, state) {
        if (state.isSelfContact) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header text (REUSED — l10n.cta_call from Phase 13)
            Text(l10n.cta_call, ...),
            const SizedBox(height: AppSpacing.sm),
            // Call CTA (visible only when phone set)
            if (state.showCall)
              OutlinedButton.icon(
                onPressed: () => _onCallPressed(context, state.phone!),
                icon: const Icon(Icons.phone_outlined),
                label: Text(l10n.cta_call),
              ),
            const SizedBox(height: AppSpacing.sm),
            // WhatsApp CTA (always rendered; enabled depends on whatsapp field)
            OutlinedButton.icon(
              onPressed: state.whatsappEnabled
                  ? () => _onWhatsAppPressed(context, state.whatsapp!)
                  : null,
              icon: const Icon(Icons.chat_outlined),
              label: Text(l10n.cta_whatsapp),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Send Inquiry CTA
            OutlinedButton.icon(
              onPressed: () => _onSendInquiryPressed(context),
              icon: const Icon(Icons.email_outlined),
              label: Text(l10n.cta_send_inquiry),
            ),
          ],
        );
      },
    ),
  );
}
```

## Handler bodies

```dart
Future<void> _onCallPressed(BuildContext context, String phone) async {
  final result = await getIt<RecordLeadEvent>()(
    listingId: listing.id,
    eventType: LeadEventType.phoneRevealed,
  );
  if (result.isFailure) {
    // Show localized error but still attempt launch (the event is the spec's intent;
    // a failed event log shouldn't block the user's ability to call)
  }
  final launched = await launchUrl(Uri.parse('tel:$phone'));
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.contact_dialer_unavailable)),
    );
  }
}

Future<void> _onWhatsAppPressed(BuildContext context, String whatsapp) async {
  await getIt<RecordLeadEvent>()(
    listingId: listing.id,
    eventType: LeadEventType.whatsappClicked,
  );
  final e164NoPlus = whatsapp.replaceAll('+', '');
  final launched = await launchUrl(
    Uri.parse('https://wa.me/$e164NoPlus'),
    mode: LaunchMode.externalApplication,
  );
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.contact_whatsapp_app_unavailable)),
    );
  }
}

void _onSendInquiryPressed(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => InquiryFormSheet(listingId: listing.id),
  );
}
```

## Self-contact behavior

When `auth.uid() == listing.publisherUserId`, the cubit emits `isSelfContact: true` and the widget renders `SizedBox.shrink()`. The Phase 13 layout above the contact block (gallery, title, price, location) renders unaffected; the contact section simply disappears.

## Stability surface

**Frozen**: the three-button tap order (Call, WhatsApp, Send Inquiry), the icons, the label sources (Phase 13 ARB keys `cta_call`, `cta_whatsapp`, `cta_send_inquiry`).

**Allowed**: adding new tap-handler behavior (e.g., Phase 22 push notification subscription on the inquiry submission path) — provided the visible widget tree is unchanged.
