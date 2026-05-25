# Phase 16 Contracts — Index

Each contract file in this directory locks the interface between Phase 16's producers (backend migrations, RPCs, views, triggers) and consumers (Flutter feature code, future phases). The full per-contract bodies are checked in alongside this index.

## Backend contracts

| File | Owner | Consumers |
|------|-------|-----------|
| [phase16-inquiries-table.md](phase16-inquiries-table.md) | Sub-Phase B | Sub-Phases C, D, E (all read or write this table via views/RPCs); Phase 18 reports/moderation may add new policies. |
| [phase16-lead-events-table.md](phase16-lead-events-table.md) | Sub-Phase B | Sub-Phases C, D, E; Phase 17 favorites adds `favorite_added` writes; Phase 20 admin dashboard reads aggregate counts. |
| [phase16-inquiries-policies.md](phase16-inquiries-policies.md) | Sub-Phase C | Every read/write code path; the three-tier rule is the load-bearing security contract. |
| [phase16-lead-events-policies.md](phase16-lead-events-policies.md) | Sub-Phase C | Every read code path; the metadata-masking rule is the load-bearing privacy contract. |
| [phase16-enforce-inquiry-transition-trigger.md](phase16-enforce-inquiry-transition-trigger.md) | Sub-Phase B | Every UPDATE on `inquiries.status` regardless of caller — admin, publisher, or future moderation tooling. |
| [phase16-decrypt-inquirer-phone-fn.md](phase16-decrypt-inquirer-phone-fn.md) | Sub-Phase D | `v_inquiries_inbox` view's projection; Sub-Phase E `loadInbox` + `loadDetail`; the function self-gates per-call. |
| [phase16-submit-inquiry-rpc.md](phase16-submit-inquiry-rpc.md) | Sub-Phase D | Sub-Phase E `submitInquiry` data path; the only client write-path for inquiries. |
| [phase16-record-lead-event-rpc.md](phase16-record-lead-event-rpc.md) | Sub-Phase D | Sub-Phase H `ContactBlock` Call/WhatsApp handlers; the only client write-path for tap events. |
| [phase16-get-inbox-unread-count-rpc.md](phase16-get-inbox-unread-count-rpc.md) | Sub-Phase D | Sub-Phase F `InquiriesUnreadCubit` + Sub-Phase H home AppBar action. |
| [phase16-v-inquiries-inbox-view.md](phase16-v-inquiries-inbox-view.md) | Sub-Phase C | Sub-Phase E `SupabaseInquiriesDatasource.loadInbox` + `loadDetail`. |
| [phase16-v-lead-events-views.md](phase16-v-lead-events-views.md) | Sub-Phase C | Sub-Phase E `loadLeadEventsByListing`; Phase 20 admin dashboard. |

## Frontend / wiring contracts

| File | Owner | Consumers |
|------|-------|-----------|
| [phase16-contact-block-rewire.md](phase16-contact-block-rewire.md) | Sub-Phase H | The listing details page (Phase 13). |
| [phase16-inquiry-form-sheet.md](phase16-inquiry-form-sheet.md) | Sub-Phase F | `ContactBlock` "Send inquiry" handler (Sub-Phase H). |
| [phase16-inbox-page-composition.md](phase16-inbox-page-composition.md) | Sub-Phase F | The route registered in Sub-Phase A. |
| [phase16-home-appbar-inbox-action.md](phase16-home-appbar-inbox-action.md) | Sub-Phase H | The home page (Phase 13). |
| [phase16-admin-oversight-overlay.md](phase16-admin-oversight-overlay.md) | Sub-Phase F | Phase 20 admin dashboard tile. |

## Contract scope

Each contract specifies:

- **What** the interface is (signature, columns, fields, behavior).
- **Pre-conditions** (what must be true before the interface is callable / readable).
- **Post-conditions** (what is guaranteed about the result).
- **Failure modes** (which error codes / SQLSTATEs / `Failure` shapes the consumer must handle).
- **Stability surface** (which parts are frozen for downstream consumers vs which may change).

Per Constitution Principle X (Testable AI Workflow), every contract is verifiable via the corresponding entry in `data-model.md`'s FR/SC verification map and the steps in `quickstart.md`.
