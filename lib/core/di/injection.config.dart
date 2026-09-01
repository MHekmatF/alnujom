// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:ui' as _i264;

import 'package:get_it/get_it.dart' as _i174;
import 'package:go_router/go_router.dart' as _i583;
import 'package:injectable/injectable.dart' as _i526;
import 'package:supabase_flutter/supabase_flutter.dart' as _i454;

import '../../features/admin/account_approvals/data/datasources/supabase_account_approvals_datasource.dart'
    as _i394;
import '../../features/admin/account_approvals/data/repositories/account_approvals_repository_impl.dart'
    as _i278;
import '../../features/admin/account_approvals/domain/repositories/account_approvals_repository.dart'
    as _i120;
import '../../features/admin/account_approvals/domain/usecases/approve_account.dart'
    as _i858;
import '../../features/admin/account_approvals/domain/usecases/load_pending_queue.dart'
    as _i138;
import '../../features/admin/account_approvals/domain/usecases/reject_account.dart'
    as _i431;
import '../../features/admin/account_approvals/presentation/cubit/account_approvals_cubit.dart'
    as _i295;
import '../../features/admin/agencies/data/datasources/supabase_agencies_admin_datasource.dart'
    as _i185;
import '../../features/admin/agencies/data/repositories/agencies_admin_repository_impl.dart'
    as _i61;
import '../../features/admin/agencies/domain/repositories/agencies_admin_repository.dart'
    as _i91;
import '../../features/admin/agencies/domain/usecases/approve_agency.dart'
    as _i363;
import '../../features/admin/agencies/domain/usecases/load_agency_verification_queue.dart'
    as _i998;
import '../../features/admin/agencies/domain/usecases/reinstate_agency.dart'
    as _i940;
import '../../features/admin/agencies/domain/usecases/reject_agency.dart'
    as _i295;
import '../../features/admin/agencies/domain/usecases/suspend_agency.dart'
    as _i31;
import '../../features/admin/agencies/presentation/bloc/agency_moderation_cubit.dart'
    as _i664;
import '../../features/admin/agencies/presentation/bloc/agency_queue_bloc.dart'
    as _i916;
import '../../features/admin/analytics/data/datasources/admin_analytics_datasource.dart'
    as _i228;
import '../../features/admin/analytics/data/repositories/admin_analytics_repository_impl.dart'
    as _i865;
import '../../features/admin/analytics/domain/repositories/admin_analytics_repository.dart'
    as _i571;
import '../../features/admin/analytics/presentation/bloc/admin_analytics_cubit.dart'
    as _i1003;
import '../../features/admin/audit_logs/data/datasources/audit_logs_datasource.dart'
    as _i617;
import '../../features/admin/audit_logs/data/repositories/audit_log_repository_impl.dart'
    as _i373;
import '../../features/admin/audit_logs/domain/repositories/audit_log_repository.dart'
    as _i881;
import '../../features/admin/audit_logs/domain/usecases/load_audit_log_page.dart'
    as _i365;
import '../../features/admin/audit_logs/presentation/bloc/audit_log_cubit.dart'
    as _i48;
import '../../features/admin/dashboard/data/datasources/dashboard_counts_datasource.dart'
    as _i801;
import '../../features/admin/dashboard/data/repositories/dashboard_repository_impl.dart'
    as _i469;
import '../../features/admin/dashboard/domain/repositories/dashboard_repository.dart'
    as _i662;
import '../../features/admin/dashboard/domain/usecases/load_dashboard_counts.dart'
    as _i670;
import '../../features/admin/dashboard/presentation/bloc/dashboard_cubit.dart'
    as _i616;
import '../../features/admin/listing_review/data/datasources/supabase_listing_review_datasource.dart'
    as _i530;
import '../../features/admin/listing_review/data/repositories/listing_review_repository_impl.dart'
    as _i1072;
import '../../features/admin/listing_review/domain/repositories/listing_review_repository.dart'
    as _i155;
import '../../features/admin/listing_review/domain/usecases/apply_revision.dart'
    as _i841;
import '../../features/admin/listing_review/domain/usecases/approve_listing.dart'
    as _i404;
import '../../features/admin/listing_review/domain/usecases/feature_listing.dart'
    as _i542;
import '../../features/admin/listing_review/domain/usecases/load_listing_preview.dart'
    as _i96;
import '../../features/admin/listing_review/domain/usecases/load_pending_queue.dart'
    as _i207;
import '../../features/admin/listing_review/domain/usecases/load_pending_revisions.dart'
    as _i318;
import '../../features/admin/listing_review/domain/usecases/load_revision_diff.dart'
    as _i169;
import '../../features/admin/listing_review/domain/usecases/reject_listing.dart'
    as _i880;
import '../../features/admin/listing_review/domain/usecases/reject_revision.dart'
    as _i1048;
import '../../features/admin/listing_review/presentation/bloc/listing_preview_bloc.dart'
    as _i778;
import '../../features/admin/listing_review/presentation/bloc/pending_queue_bloc.dart'
    as _i554;
import '../../features/admin/listing_review/presentation/bloc/pending_revisions_cubit.dart'
    as _i277;
import '../../features/admin/listing_review/presentation/bloc/revision_review_bloc.dart'
    as _i992;
import '../../features/admin/reports/data/datasources/supabase_reports_admin_datasource.dart'
    as _i433;
import '../../features/admin/reports/data/repositories/reports_admin_repository_impl.dart'
    as _i303;
import '../../features/admin/reports/domain/repositories/reports_admin_repository.dart'
    as _i973;
import '../../features/admin/reports/domain/usecases/load_reports_queue.dart'
    as _i911;
import '../../features/admin/reports/domain/usecases/resolve_report.dart'
    as _i943;
import '../../features/admin/reports/domain/usecases/start_report_review.dart'
    as _i771;
import '../../features/admin/reports/presentation/bloc/report_resolve_cubit.dart'
    as _i902;
import '../../features/admin/reports/presentation/bloc/reports_queue_bloc.dart'
    as _i1051;
import '../../features/ads/admin/presentation/bloc/ads_admin_cubit.dart'
    as _i682;
import '../../features/ads/data/datasources/supabase_ads_admin_datasource.dart'
    as _i185;
import '../../features/ads/data/datasources/supabase_ads_serving_datasource.dart'
    as _i1005;
import '../../features/ads/data/repositories/ads_admin_repository_impl.dart'
    as _i634;
import '../../features/ads/data/repositories/ads_serving_repository_impl.dart'
    as _i202;
import '../../features/ads/domain/repositories/ads_admin_repository.dart'
    as _i241;
import '../../features/ads/domain/repositories/ads_serving_repository.dart'
    as _i186;
import '../../features/ads/domain/usecases/archive_ad.dart' as _i230;
import '../../features/ads/domain/usecases/create_ad.dart' as _i845;
import '../../features/ads/domain/usecases/load_ads.dart' as _i347;
import '../../features/ads/domain/usecases/load_serving_ads.dart' as _i180;
import '../../features/ads/domain/usecases/record_ad_click.dart' as _i930;
import '../../features/ads/domain/usecases/set_ad_active.dart' as _i484;
import '../../features/ads/domain/usecases/update_ad.dart' as _i502;
import '../../features/ads/domain/usecases/upload_ad_image.dart' as _i831;
import '../../features/ads/presentation/bloc/ad_slot_cubit.dart' as _i371;
import '../../features/agency/data/datasources/supabase_agency_datasource.dart'
    as _i514;
import '../../features/agency/data/repositories/agency_repository_impl.dart'
    as _i246;
import '../../features/agency/domain/repositories/agency_repository.dart'
    as _i1006;
import '../../features/agency/domain/usecases/create_agency.dart' as _i195;
import '../../features/agency/domain/usecases/invite_agency_member.dart'
    as _i917;
import '../../features/agency/domain/usecases/load_agency_analytics.dart'
    as _i570;
import '../../features/agency/domain/usecases/load_agency_by_id.dart' as _i686;
import '../../features/agency/domain/usecases/load_agency_listings.dart'
    as _i1048;
import '../../features/agency/domain/usecases/load_agency_members.dart'
    as _i144;
import '../../features/agency/domain/usecases/load_my_active_agencies.dart'
    as _i611;
import '../../features/agency/domain/usecases/load_my_agency.dart' as _i324;
import '../../features/agency/domain/usecases/load_my_agency_invitations.dart'
    as _i470;
import '../../features/agency/domain/usecases/load_my_verification_request.dart'
    as _i977;
import '../../features/agency/domain/usecases/remove_agency_member.dart'
    as _i262;
import '../../features/agency/domain/usecases/respond_agency_invitation.dart'
    as _i552;
import '../../features/agency/domain/usecases/set_agency_member_role.dart'
    as _i975;
import '../../features/agency/domain/usecases/submit_agency_verification.dart'
    as _i377;
import '../../features/agency/domain/usecases/update_agency_profile.dart'
    as _i609;
import '../../features/agency/presentation/bloc/agency_analytics_cubit.dart'
    as _i840;
import '../../features/agency/presentation/bloc/agency_home_cubit.dart'
    as _i988;
import '../../features/agency/presentation/bloc/agency_invitations_cubit.dart'
    as _i800;
import '../../features/agency/presentation/bloc/agency_listings_bloc.dart'
    as _i261;
import '../../features/agency/presentation/bloc/agency_members_bloc.dart'
    as _i71;
import '../../features/agency/presentation/bloc/agency_verification_cubit.dart'
    as _i524;
import '../../features/app_update/data/datasources/package_info_version_source.dart'
    as _i736;
import '../../features/app_update/data/datasources/supabase_manifest_datasource.dart'
    as _i523;
import '../../features/app_update/data/repositories/app_update_repository_impl.dart'
    as _i201;
import '../../features/app_update/domain/repositories/app_update_repository.dart'
    as _i756;
import '../../features/app_update/domain/usecases/check_for_update.dart'
    as _i933;
import '../../features/app_update/presentation/bloc/app_update_cubit.dart'
    as _i1067;
import '../../features/assistant/data/datasources/assistant_stats_datasource.dart'
    as _i918;
import '../../features/assistant/data/repositories/assistant_stats_repository_impl.dart'
    as _i142;
import '../../features/assistant/domain/assistant_brain.dart' as _i84;
import '../../features/assistant/domain/query_parser.dart' as _i367;
import '../../features/assistant/domain/repositories/assistant_stats_repository.dart'
    as _i554;
import '../../features/assistant/presentation/bloc/assistant_cubit.dart'
    as _i697;
import '../../features/auth/data/datasources/supabase_auth_datasource.dart'
    as _i76;
import '../../features/auth/data/repositories/auth_repository_impl.dart'
    as _i153;
import '../../features/auth/domain/repositories/auth_repository.dart' as _i787;
import '../../features/auth/domain/usecases/request_password_reset.dart'
    as _i956;
import '../../features/auth/domain/usecases/update_password.dart' as _i455;
import '../../features/auth/presentation/bloc/auth_bloc.dart' as _i797;
import '../../features/auth/presentation/bloc/password_reset_cubit.dart'
    as _i122;
import '../../features/auth/presentation/bloc/set_new_password_cubit.dart'
    as _i930;
import '../../features/chat/data/datasources/supabase_chat_datasource.dart'
    as _i572;
import '../../features/chat/data/repositories/chat_repository_impl.dart'
    as _i504;
import '../../features/chat/domain/repositories/chat_repository.dart' as _i420;
import '../../features/chat/domain/usecases/get_or_create_conversation.dart'
    as _i714;
import '../../features/chat/domain/usecases/list_conversations.dart' as _i929;
import '../../features/chat/domain/usecases/mark_conversation_read.dart'
    as _i211;
import '../../features/chat/domain/usecases/send_message.dart' as _i76;
import '../../features/chat/domain/usecases/watch_messages.dart' as _i929;
import '../../features/chat/presentation/bloc/chat_thread_cubit.dart' as _i968;
import '../../features/chat/presentation/bloc/conversations_cubit.dart'
    as _i665;
import '../../features/comparison/presentation/cubit/comparison_cubit.dart'
    as _i430;
import '../../features/crm/data/datasources/supabase_crm_datasource.dart'
    as _i802;
import '../../features/crm/data/repositories/crm_repository_impl.dart' as _i516;
import '../../features/crm/domain/repositories/crm_repository.dart' as _i677;
import '../../features/crm/presentation/bloc/crm_leads_cubit.dart' as _i835;
import '../../features/crm/presentation/bloc/lead_detail_cubit.dart' as _i1026;
import '../../features/currencies/data/datasources/supabase_currencies_datasource.dart'
    as _i311;
import '../../features/currencies/data/repositories/currencies_repository_impl.dart'
    as _i148;
import '../../features/currencies/domain/repositories/currencies_repository.dart'
    as _i505;
import '../../features/currencies/domain/usecases/count_dependent_exchange_rates.dart'
    as _i905;
import '../../features/currencies/domain/usecases/create_currency.dart'
    as _i1003;
import '../../features/currencies/domain/usecases/delete_currency.dart' as _i43;
import '../../features/currencies/domain/usecases/list_currencies.dart'
    as _i996;
import '../../features/currencies/domain/usecases/list_exchange_rate_history.dart'
    as _i776;
import '../../features/currencies/domain/usecases/load_currency_detail.dart'
    as _i510;
import '../../features/currencies/domain/usecases/load_latest_rates_for_base.dart'
    as _i957;
import '../../features/currencies/domain/usecases/set_exchange_rate.dart'
    as _i488;
import '../../features/currencies/domain/usecases/update_currency.dart'
    as _i540;
import '../../features/currencies/presentation/bloc/currencies_list_bloc.dart'
    as _i176;
import '../../features/currencies/presentation/bloc/currency_form_bloc.dart'
    as _i657;
import '../../features/currencies/presentation/bloc/exchange_rate_history_bloc.dart'
    as _i949;
import '../../features/currencies/presentation/bloc/set_exchange_rate_bloc.dart'
    as _i293;
import '../../features/favorites/data/datasources/supabase_favorites_datasource.dart'
    as _i8;
import '../../features/favorites/data/repositories/favorites_repository_impl.dart'
    as _i144;
import '../../features/favorites/domain/repositories/favorites_repository.dart'
    as _i212;
import '../../features/favorites/domain/usecases/add_favorite.dart' as _i705;
import '../../features/favorites/domain/usecases/load_favorite_ids.dart'
    as _i896;
import '../../features/favorites/domain/usecases/load_favorites.dart' as _i1041;
import '../../features/favorites/domain/usecases/remove_favorite.dart' as _i828;
import '../../features/favorites/presentation/bloc/favorites_cubit.dart'
    as _i991;
import '../../features/favorites/presentation/bloc/favorites_page_bloc.dart'
    as _i171;
import '../../features/home/data/datasources/supabase_home_feed_datasource.dart'
    as _i732;
import '../../features/home/data/repositories/home_feed_repository_impl.dart'
    as _i857;
import '../../features/home/domain/repositories/home_feed_repository.dart'
    as _i433;
import '../../features/home/domain/usecases/load_featured_listings.dart'
    as _i240;
import '../../features/home/domain/usecases/load_home_feed.dart' as _i321;
import '../../features/home/presentation/bloc/featured_listings_cubit.dart'
    as _i665;
import '../../features/home/presentation/bloc/home_bloc.dart' as _i202;
import '../../features/inquiries/data/datasources/supabase_inquiries_datasource.dart'
    as _i1043;
import '../../features/inquiries/data/repositories/inquiry_repository_impl.dart'
    as _i614;
import '../../features/inquiries/data/repositories/lead_event_repository_impl.dart'
    as _i33;
import '../../features/inquiries/domain/repositories/inquiry_repository.dart'
    as _i272;
import '../../features/inquiries/domain/repositories/lead_event_repository.dart'
    as _i866;
import '../../features/inquiries/domain/usecases/check_owns_approved_listing.dart'
    as _i704;
import '../../features/inquiries/domain/usecases/load_inbox_unread_count.dart'
    as _i868;
import '../../features/inquiries/domain/usecases/load_inquiry_detail.dart'
    as _i1054;
import '../../features/inquiries/domain/usecases/load_inquiry_inbox.dart'
    as _i155;
import '../../features/inquiries/domain/usecases/record_lead_event.dart'
    as _i615;
import '../../features/inquiries/domain/usecases/submit_inquiry.dart' as _i73;
import '../../features/inquiries/domain/usecases/update_inquiry_status.dart'
    as _i684;
import '../../features/inquiries/presentation/bloc/contact_cta_cubit.dart'
    as _i95;
import '../../features/inquiries/presentation/bloc/inquiries_unread_cubit.dart'
    as _i74;
import '../../features/inquiries/presentation/bloc/inquiry_detail_bloc.dart'
    as _i1;
import '../../features/inquiries/presentation/bloc/inquiry_form_bloc.dart'
    as _i193;
import '../../features/inquiries/presentation/bloc/inquiry_inbox_bloc.dart'
    as _i264;
import '../../features/listing_details/data/datasources/overpass_nearby_amenities_datasource.dart'
    as _i676;
import '../../features/listing_details/data/datasources/supabase_listing_details_datasource.dart'
    as _i1006;
import '../../features/listing_details/data/datasources/supabase_market_insights_datasource.dart'
    as _i111;
import '../../features/listing_details/data/datasources/supabase_similar_listings_datasource.dart'
    as _i913;
import '../../features/listing_details/data/repositories/listing_details_repository_impl.dart'
    as _i677;
import '../../features/listing_details/data/repositories/market_insights_repository_impl.dart'
    as _i190;
import '../../features/listing_details/data/repositories/nearby_amenities_repository_impl.dart'
    as _i897;
import '../../features/listing_details/data/repositories/similar_listings_repository_impl.dart'
    as _i474;
import '../../features/listing_details/domain/repositories/listing_details_repository.dart'
    as _i895;
import '../../features/listing_details/domain/repositories/market_insights_repository.dart'
    as _i392;
import '../../features/listing_details/domain/repositories/nearby_amenities_repository.dart'
    as _i823;
import '../../features/listing_details/domain/repositories/similar_listings_repository.dart'
    as _i888;
import '../../features/listing_details/domain/usecases/load_listing_details.dart'
    as _i281;
import '../../features/listing_details/domain/usecases/load_similar_listings.dart'
    as _i981;
import '../../features/listing_details/presentation/bloc/listing_details_bloc.dart'
    as _i935;
import '../../features/listing_details/presentation/bloc/market_insights_cubit.dart'
    as _i290;
import '../../features/listing_details/presentation/bloc/nearby_amenities_cubit.dart'
    as _i568;
import '../../features/listing_details/presentation/bloc/similar_listings_cubit.dart'
    as _i255;
import '../../features/listing_form/data/datasources/supabase_listing_media_datasource.dart'
    as _i214;
import '../../features/listing_form/data/datasources/supabase_listing_revision_datasource.dart'
    as _i1020;
import '../../features/listing_form/data/datasources/supabase_listings_datasource.dart'
    as _i207;
import '../../features/listing_form/data/repositories/listing_revisions_repository_impl.dart'
    as _i736;
import '../../features/listing_form/data/repositories/listings_repository_impl.dart'
    as _i946;
import '../../features/listing_form/domain/entities/listing.dart' as _i699;
import '../../features/listing_form/domain/repositories/listing_revisions_repository.dart'
    as _i902;
import '../../features/listing_form/domain/repositories/listings_repository.dart'
    as _i340;
import '../../features/listing_form/domain/usecases/begin_revision.dart' as _i7;
import '../../features/listing_form/domain/usecases/delete_draft.dart' as _i814;
import '../../features/listing_form/domain/usecases/delete_media.dart' as _i732;
import '../../features/listing_form/domain/usecases/derive_area_centroid.dart'
    as _i906;
import '../../features/listing_form/domain/usecases/find_open_revision.dart'
    as _i994;
import '../../features/listing_form/domain/usecases/load_media_for_listing.dart'
    as _i406;
import '../../features/listing_form/domain/usecases/load_or_create_draft.dart'
    as _i802;
import '../../features/listing_form/domain/usecases/load_revision.dart'
    as _i657;
import '../../features/listing_form/domain/usecases/reorder_media.dart'
    as _i1022;
import '../../features/listing_form/domain/usecases/save_form_step.dart'
    as _i874;
import '../../features/listing_form/domain/usecases/save_revision.dart'
    as _i222;
import '../../features/listing_form/domain/usecases/set_main_image.dart'
    as _i629;
import '../../features/listing_form/domain/usecases/submit_listing.dart'
    as _i829;
import '../../features/listing_form/domain/usecases/submit_revision.dart'
    as _i62;
import '../../features/listing_form/domain/usecases/upload_image.dart'
    as _i1062;
import '../../features/listing_form/domain/usecases/upload_panorama.dart'
    as _i206;
import '../../features/listing_form/domain/usecases/upload_staged_media.dart'
    as _i520;
import '../../features/listing_form/domain/usecases/upload_video.dart' as _i490;
import '../../features/listing_form/domain/usecases/validate_submit_payload.dart'
    as _i396;
import '../../features/listing_form/presentation/bloc/listing_form_bloc.dart'
    as _i315;
import '../../features/listing_form/presentation/util/video_processor.dart'
    as _i957;
import '../../features/locations/data/datasources/supabase_locations_datasource.dart'
    as _i665;
import '../../features/locations/data/repositories/locations_repository_impl.dart'
    as _i178;
import '../../features/locations/domain/repositories/locations_repository.dart'
    as _i704;
import '../../features/locations/domain/usecases/count_city_dependents.dart'
    as _i655;
import '../../features/locations/domain/usecases/count_governorate_dependents.dart'
    as _i58;
import '../../features/locations/domain/usecases/create_area.dart' as _i880;
import '../../features/locations/domain/usecases/create_city.dart' as _i206;
import '../../features/locations/domain/usecases/create_governorate.dart'
    as _i1027;
import '../../features/locations/domain/usecases/delete_area.dart' as _i662;
import '../../features/locations/domain/usecases/delete_city.dart' as _i239;
import '../../features/locations/domain/usecases/delete_governorate.dart'
    as _i937;
import '../../features/locations/domain/usecases/list_all_areas.dart' as _i548;
import '../../features/locations/domain/usecases/list_all_cities.dart' as _i450;
import '../../features/locations/domain/usecases/list_areas_for_city.dart'
    as _i358;
import '../../features/locations/domain/usecases/list_cities_for_governorate.dart'
    as _i53;
import '../../features/locations/domain/usecases/list_governorates.dart'
    as _i533;
import '../../features/locations/domain/usecases/load_area_detail.dart'
    as _i292;
import '../../features/locations/domain/usecases/load_city_detail.dart'
    as _i645;
import '../../features/locations/domain/usecases/load_governorate_detail.dart'
    as _i441;
import '../../features/locations/domain/usecases/update_area.dart' as _i188;
import '../../features/locations/domain/usecases/update_city.dart' as _i1058;
import '../../features/locations/domain/usecases/update_governorate.dart'
    as _i1054;
import '../../features/locations/presentation/bloc/city_detail_bloc.dart'
    as _i1073;
import '../../features/locations/presentation/bloc/governorate_detail_bloc.dart'
    as _i796;
import '../../features/locations/presentation/bloc/location_form_bloc.dart'
    as _i419;
import '../../features/locations/presentation/bloc/location_picker_bloc.dart'
    as _i610;
import '../../features/locations/presentation/bloc/locations_list_bloc.dart'
    as _i669;
import '../../features/map/data/datasources/supabase_map_datasource.dart'
    as _i245;
import '../../features/map/data/repositories/map_repository_impl.dart' as _i457;
import '../../features/map/domain/repositories/map_repository.dart' as _i973;
import '../../features/map/domain/usecases/load_map_markers.dart' as _i842;
import '../../features/map/presentation/bloc/map_bloc.dart' as _i437;
import '../../features/notifications/data/datasources/supabase_notifications_datasource.dart'
    as _i1059;
import '../../features/notifications/data/datasources/supabase_push_token_datasource.dart'
    as _i445;
import '../../features/notifications/data/repositories/notifications_repository_impl.dart'
    as _i201;
import '../../features/notifications/data/repositories/push_token_repository_impl.dart'
    as _i566;
import '../../features/notifications/domain/repositories/notifications_repository.dart'
    as _i563;
import '../../features/notifications/domain/repositories/push_token_repository.dart'
    as _i6;
import '../../features/notifications/domain/usecases/deregister_push_token.dart'
    as _i181;
import '../../features/notifications/domain/usecases/load_notifications.dart'
    as _i1019;
import '../../features/notifications/domain/usecases/load_unread_count.dart'
    as _i873;
import '../../features/notifications/domain/usecases/mark_all_notifications_read.dart'
    as _i852;
import '../../features/notifications/domain/usecases/mark_notification_read.dart'
    as _i29;
import '../../features/notifications/domain/usecases/register_push_token.dart'
    as _i397;
import '../../features/notifications/presentation/bloc/notification_badge_cubit.dart'
    as _i558;
import '../../features/notifications/presentation/bloc/notifications_cubit.dart'
    as _i66;
import '../../features/onboarding/data/datasources/onboarding_seen_storage.dart'
    as _i144;
import '../../features/onboarding/data/repositories/onboarding_repository_impl.dart'
    as _i452;
import '../../features/onboarding/domain/repositories/onboarding_repository.dart'
    as _i430;
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart'
    as _i807;
import '../../features/profile/data/datasources/supabase_profile_datasource.dart'
    as _i825;
import '../../features/profile/data/repositories/profile_repository_impl.dart'
    as _i334;
import '../../features/profile/domain/repositories/profile_repository.dart'
    as _i894;
import '../../features/profile/domain/usecases/load_assigned_roles.dart'
    as _i941;
import '../../features/profile/domain/usecases/load_pii.dart' as _i363;
import '../../features/profile/domain/usecases/load_profile.dart' as _i1052;
import '../../features/profile/domain/usecases/request_account_deletion.dart'
    as _i231;
import '../../features/profile/domain/usecases/update_pii.dart' as _i281;
import '../../features/profile/domain/usecases/update_profile.dart' as _i78;
import '../../features/profile/presentation/cubit/account_deletion_cubit.dart'
    as _i617;
import '../../features/profile/presentation/cubit/profile_cubit.dart' as _i36;
import '../../features/publisher_dashboard/data/datasources/publisher_analytics_datasource.dart'
    as _i855;
import '../../features/publisher_dashboard/data/datasources/publisher_dashboard_counts_datasource.dart'
    as _i157;
import '../../features/publisher_dashboard/data/datasources/supabase_publisher_dashboard_datasource.dart'
    as _i333;
import '../../features/publisher_dashboard/data/repositories/publisher_analytics_repository_impl.dart'
    as _i945;
import '../../features/publisher_dashboard/data/repositories/publisher_dashboard_counts_repository_impl.dart'
    as _i815;
import '../../features/publisher_dashboard/data/repositories/publisher_dashboard_repository_impl.dart'
    as _i240;
import '../../features/publisher_dashboard/domain/repositories/publisher_analytics_repository.dart'
    as _i934;
import '../../features/publisher_dashboard/domain/repositories/publisher_dashboard_counts_repository.dart'
    as _i563;
import '../../features/publisher_dashboard/domain/repositories/publisher_dashboard_repository.dart'
    as _i754;
import '../../features/publisher_dashboard/domain/usecases/list_my_listings.dart'
    as _i891;
import '../../features/publisher_dashboard/domain/usecases/load_moderation_history.dart'
    as _i919;
import '../../features/publisher_dashboard/domain/usecases/load_most_recent_rejection.dart'
    as _i564;
import '../../features/publisher_dashboard/domain/usecases/load_publisher_daily_lead_totals.dart'
    as _i895;
import '../../features/publisher_dashboard/domain/usecases/load_publisher_dashboard_counts.dart'
    as _i373;
import '../../features/publisher_dashboard/domain/usecases/load_publisher_listing_breakdown.dart'
    as _i1026;
import '../../features/publisher_dashboard/domain/usecases/renew_listing.dart'
    as _i576;
import '../../features/publisher_dashboard/presentation/bloc/moderation_history_cubit.dart'
    as _i711;
import '../../features/publisher_dashboard/presentation/bloc/my_listings_bloc.dart'
    as _i417;
import '../../features/publisher_dashboard/presentation/bloc/publisher_analytics_cubit.dart'
    as _i741;
import '../../features/publisher_dashboard/presentation/bloc/publisher_charts_cubit.dart'
    as _i710;
import '../../features/publisher_dashboard/presentation/bloc/publisher_dashboard_summary_cubit.dart'
    as _i803;
import '../../features/recently_viewed/data/local/recently_viewed_store.dart'
    as _i43;
import '../../features/recently_viewed/presentation/bloc/recently_viewed_cubit.dart'
    as _i57;
import '../../features/reels/data/datasources/supabase_reels_datasource.dart'
    as _i496;
import '../../features/reels/data/repositories/reels_repository_impl.dart'
    as _i1070;
import '../../features/reels/domain/repositories/reels_repository.dart'
    as _i695;
import '../../features/reels/domain/usecases/load_reels.dart' as _i283;
import '../../features/reels/presentation/bloc/reels_feed_cubit.dart' as _i516;
import '../../features/reels/presentation/bloc/reels_rail_cubit.dart' as _i847;
import '../../features/reports/data/datasources/supabase_reports_datasource.dart'
    as _i231;
import '../../features/reports/data/repositories/reports_repository_impl.dart'
    as _i227;
import '../../features/reports/domain/repositories/reports_repository.dart'
    as _i808;
import '../../features/reports/domain/usecases/load_my_report_for_listing.dart'
    as _i682;
import '../../features/reports/domain/usecases/load_my_reports.dart' as _i991;
import '../../features/reports/domain/usecases/submit_report.dart' as _i684;
import '../../features/reports/presentation/cubit/listing_report_status_cubit.dart'
    as _i1007;
import '../../features/reports/presentation/cubit/my_reports_bloc.dart'
    as _i749;
import '../../features/reports/presentation/cubit/report_submission_cubit.dart'
    as _i980;
import '../../features/reviews/data/datasources/supabase_reviews_datasource.dart'
    as _i638;
import '../../features/reviews/data/repositories/reviews_repository_impl.dart'
    as _i388;
import '../../features/reviews/domain/repositories/reviews_repository.dart'
    as _i412;
import '../../features/reviews/domain/usecases/load_seller_trust.dart' as _i557;
import '../../features/reviews/domain/usecases/submit_review.dart' as _i225;
import '../../features/reviews/presentation/bloc/seller_trust_cubit.dart'
    as _i49;
import '../../features/search/data/datasources/recent_searches_storage.dart'
    as _i193;
import '../../features/search/data/datasources/supabase_saved_searches_datasource.dart'
    as _i782;
import '../../features/search/data/datasources/supabase_search_datasource.dart'
    as _i713;
import '../../features/search/data/repositories/saved_searches_repository_impl.dart'
    as _i735;
import '../../features/search/data/repositories/search_repository_impl.dart'
    as _i1017;
import '../../features/search/domain/repositories/saved_searches_repository.dart'
    as _i732;
import '../../features/search/domain/repositories/search_repository.dart'
    as _i357;
import '../../features/search/domain/usecases/delete_saved_search_usecase.dart'
    as _i912;
import '../../features/search/domain/usecases/list_saved_searches_usecase.dart'
    as _i847;
import '../../features/search/domain/usecases/save_search_usecase.dart'
    as _i388;
import '../../features/search/domain/usecases/search_listings_usecase.dart'
    as _i190;
import '../../features/search/presentation/bloc/search_bloc.dart' as _i552;
import '../../features/search/presentation/cubit/recent_searches_cubit.dart'
    as _i929;
import '../../features/search/presentation/cubit/saved_searches_cubit.dart'
    as _i602;
import '../../features/settings/admin/presentation/bloc/app_settings_editor_cubit.dart'
    as _i676;
import '../../features/settings/data/datasources/supabase_app_settings_datasource.dart'
    as _i835;
import '../../features/settings/data/repositories/app_settings_repository_impl.dart'
    as _i1061;
import '../../features/settings/domain/repositories/app_settings_repository.dart'
    as _i673;
import '../../features/settings/domain/usecases/load_all_settings.dart'
    as _i415;
import '../../features/settings/domain/usecases/load_public_settings.dart'
    as _i838;
import '../../features/settings/domain/usecases/update_setting.dart' as _i349;
import '../../features/settings/presentation/bloc/app_settings_cubit.dart'
    as _i557;
import '../../features/super_admin/data/datasources/supabase_role_catalog_datasource.dart'
    as _i1064;
import '../../features/super_admin/data/datasources/supabase_user_search_datasource.dart'
    as _i24;
import '../../features/super_admin/data/repositories/role_catalog_repository_impl.dart'
    as _i564;
import '../../features/super_admin/data/repositories/user_search_repository_impl.dart'
    as _i884;
import '../../features/super_admin/domain/repositories/role_catalog_repository.dart'
    as _i681;
import '../../features/super_admin/domain/repositories/user_search_repository.dart'
    as _i765;
import '../../features/super_admin/domain/usecases/assign_role_to_user.dart'
    as _i650;
import '../../features/super_admin/domain/usecases/delete_role.dart' as _i1036;
import '../../features/super_admin/domain/usecases/list_roles.dart' as _i1018;
import '../../features/super_admin/domain/usecases/load_affected_user_count.dart'
    as _i702;
import '../../features/super_admin/domain/usecases/load_permission_catalog.dart'
    as _i518;
import '../../features/super_admin/domain/usecases/load_role_detail.dart'
    as _i176;
import '../../features/super_admin/domain/usecases/load_role_user_ids.dart'
    as _i144;
import '../../features/super_admin/domain/usecases/load_user_assignments.dart'
    as _i646;
import '../../features/super_admin/domain/usecases/mutate_role.dart' as _i315;
import '../../features/super_admin/domain/usecases/revoke_role_from_user.dart'
    as _i950;
import '../../features/super_admin/domain/usecases/search_users.dart' as _i143;
import '../../features/super_admin/presentation/bloc/assign_role_bloc.dart'
    as _i669;
import '../../features/super_admin/presentation/bloc/role_editor_bloc.dart'
    as _i885;
import '../../features/super_admin/presentation/bloc/roles_list_bloc.dart'
    as _i329;
import '../../features/viewings/data/datasources/supabase_viewings_datasource.dart'
    as _i222;
import '../../features/viewings/data/repositories/viewings_repository_impl.dart'
    as _i495;
import '../../features/viewings/domain/repositories/viewings_repository.dart'
    as _i503;
import '../../features/viewings/domain/usecases/load_my_viewings.dart' as _i644;
import '../../features/viewings/domain/usecases/request_viewing.dart' as _i285;
import '../../features/viewings/domain/usecases/update_viewing_status.dart'
    as _i725;
import '../../features/viewings/presentation/cubit/viewings_cubit.dart'
    as _i812;
import '../analytics/analytics_service.dart' as _i726;
import '../analytics/sentry_analytics_service.dart' as _i172;
import '../config/env_config.dart' as _i373;
import '../data/repositories/permission_catalog_repository_impl.dart' as _i739;
import '../listing/listing_coordinates_reader.dart' as _i452;
import '../localization/locale_cubit.dart' as _i960;
import '../logging/app_logger.dart' as _i354;
import '../logging/console_logger.dart' as _i1026;
import '../logging/crash_reporter.dart' as _i237;
import '../logging/sentry_crash_reporter.dart' as _i889;
import '../messaging/push_messaging_service.dart' as _i563;
import '../network/realtime_signals.dart' as _i591;
import '../network/realtime_signals_impl.dart' as _i854;
import '../network/supabase_client_wrapper.dart' as _i752;
import '../network/supabase_client_wrapper_impl.dart' as _i748;
import '../notifications/local_reminder_scheduler.dart' as _i562;
import '../notifications/push_notification_channel.dart' as _i1066;
import '../security/permission_catalog_repository.dart' as _i1015;
import '../security/permission_checker.dart' as _i650;
import '../storage/preferences_store.dart' as _i753;
import '../storage/secure_preferences_store.dart' as _i190;
import '../theme/palette_cubit.dart' as _i394;
import '../theme/theme_cubit.dart' as _i611;
import 'injection.dart' as _i464;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt $initGetIt(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final supabaseModule = _$SupabaseModule();
  final routerModule = _$RouterModule();
  gh.factory<_i736.PackageInfoVersionSource>(
    () => const _i736.PackageInfoVersionSource(),
  );
  gh.factory<_i367.QueryParser>(() => const _i367.QueryParser());
  gh.factory<_i676.OverpassNearbyAmenitiesDatasource>(
    () => const _i676.OverpassNearbyAmenitiesDatasource(),
  );
  gh.factory<_i214.SupabaseListingMediaDatasource>(
    () => _i214.SupabaseListingMediaDatasource(),
  );
  gh.factory<_i396.ValidateSubmitPayload>(
    () => const _i396.ValidateSubmitPayload(),
  );
  gh.factory<_i957.VideoProcessor>(() => _i957.VideoProcessor());
  gh.factory<_i665.SupabaseLocationsDatasource>(
    () => _i665.SupabaseLocationsDatasource(),
  );
  gh.singleton<_i373.EnvConfig>(() => const _i373.EnvConfig());
  gh.lazySingleton<_i454.SupabaseClient>(() => supabaseModule.supabaseClient());
  gh.lazySingleton<_i394.SupabaseAccountApprovalsDatasource>(
    () => _i394.SupabaseAccountApprovalsDatasource(),
  );
  gh.lazySingleton<_i430.ComparisonCubit>(() => _i430.ComparisonCubit());
  gh.lazySingleton<_i825.SupabaseProfileDataSource>(
    () => _i825.SupabaseProfileDataSource(),
  );
  gh.lazySingleton<_i1064.SupabaseRoleCatalogDataSource>(
    () => _i1064.SupabaseRoleCatalogDataSource(),
  );
  gh.lazySingleton<_i24.SupabaseUserSearchDataSource>(
    () => _i24.SupabaseUserSearchDataSource(),
  );
  gh.factory<_i122.PasswordResetCubit>(
    () => _i122.PasswordResetCubit(gh<_i956.RequestPasswordReset>()),
  );
  gh.lazySingleton<_i726.AnalyticsService>(
    () => _i172.SentryAnalyticsService(),
  );
  gh.lazySingleton<_i1015.PermissionCatalogRepository>(
    () => _i739.PermissionCatalogRepositoryImpl(),
  );
  gh.lazySingleton<_i650.PermissionChecker>(
    () => _i650.PermissionChecker(gh<_i1015.PermissionCatalogRepository>()),
  );
  gh.lazySingleton<_i237.CrashReporter>(() => _i889.SentryCrashReporter());
  gh.lazySingleton<_i354.AppLogger>(() => _i1026.ConsoleLogger());
  gh.lazySingleton<_i591.RealtimeSignals>(
    () => _i854.RealtimeSignalsImpl(gh<_i354.AppLogger>()),
  );
  gh.factory<_i185.SupabaseAgenciesAdminDatasource>(
    () => _i185.SupabaseAgenciesAdminDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i228.AdminAnalyticsDatasource>(
    () => _i228.AdminAnalyticsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i617.AuditLogsDatasource>(
    () => _i617.AuditLogsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i801.DashboardCountsDatasource>(
    () => _i801.DashboardCountsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i433.SupabaseReportsAdminDatasource>(
    () => _i433.SupabaseReportsAdminDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i185.SupabaseAdsAdminDatasource>(
    () => _i185.SupabaseAdsAdminDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i1005.SupabaseAdsServingDatasource>(
    () => _i1005.SupabaseAdsServingDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i514.SupabaseAgencyDatasource>(
    () => _i514.SupabaseAgencyDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i523.SupabaseManifestDatasource>(
    () => _i523.SupabaseManifestDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i918.AssistantStatsDatasource>(
    () => _i918.AssistantStatsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i572.SupabaseChatDatasource>(
    () => _i572.SupabaseChatDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i802.SupabaseCrmDatasource>(
    () => _i802.SupabaseCrmDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i311.SupabaseCurrenciesDatasource>(
    () => _i311.SupabaseCurrenciesDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i8.SupabaseFavoritesDatasource>(
    () => _i8.SupabaseFavoritesDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i732.SupabaseHomeFeedDatasource>(
    () => _i732.SupabaseHomeFeedDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i1043.SupabaseInquiriesDatasource>(
    () => _i1043.SupabaseInquiriesDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i1006.SupabaseListingDetailsDatasource>(
    () => _i1006.SupabaseListingDetailsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i111.SupabaseMarketInsightsDatasource>(
    () => _i111.SupabaseMarketInsightsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i913.SupabaseSimilarListingsDatasource>(
    () => _i913.SupabaseSimilarListingsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i245.SupabaseMapDatasource>(
    () => _i245.SupabaseMapDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i1059.SupabaseNotificationsDatasource>(
    () => _i1059.SupabaseNotificationsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i445.SupabasePushTokenDatasource>(
    () => _i445.SupabasePushTokenDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i855.PublisherAnalyticsDatasource>(
    () => _i855.PublisherAnalyticsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i157.PublisherDashboardCountsDatasource>(
    () => _i157.PublisherDashboardCountsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i333.SupabasePublisherDashboardDatasource>(
    () =>
        _i333.SupabasePublisherDashboardDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i496.SupabaseReelsDatasource>(
    () => _i496.SupabaseReelsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i231.SupabaseReportsDatasource>(
    () => _i231.SupabaseReportsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i638.SupabaseReviewsDatasource>(
    () => _i638.SupabaseReviewsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i782.SupabaseSavedSearchesDatasource>(
    () => _i782.SupabaseSavedSearchesDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i713.SupabaseSearchDatasource>(
    () => _i713.SupabaseSearchDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i835.SupabaseAppSettingsDatasource>(
    () => _i835.SupabaseAppSettingsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.factory<_i222.SupabaseViewingsDatasource>(
    () => _i222.SupabaseViewingsDatasource(gh<_i454.SupabaseClient>()),
  );
  gh.lazySingleton<_i677.CrmRepository>(
    () => _i516.CrmRepositoryImpl(gh<_i802.SupabaseCrmDatasource>()),
  );
  gh.lazySingleton<_i881.AuditLogRepository>(
    () => _i373.AuditLogRepositoryImpl(
      gh<_i617.AuditLogsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factory<_i272.InquiryRepository>(
    () => _i614.InquiryRepositoryImpl(gh<_i1043.SupabaseInquiriesDatasource>()),
  );
  gh.factory<_i973.MapRepository>(
    () => _i457.MapRepositoryImpl(gh<_i245.SupabaseMapDatasource>()),
  );
  gh.lazySingleton<_i756.AppUpdateRepository>(
    () => _i201.AppUpdateRepositoryImpl(
      gh<_i523.SupabaseManifestDatasource>(),
      gh<_i736.PackageInfoVersionSource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i571.AdminAnalyticsRepository>(
    () => _i865.AdminAnalyticsRepositoryImpl(
      gh<_i228.AdminAnalyticsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i695.ReelsRepository>(
    () => _i1070.ReelsRepositoryImpl(gh<_i496.SupabaseReelsDatasource>()),
  );
  gh.lazySingleton<_i662.DashboardRepository>(
    () => _i469.DashboardRepositoryImpl(
      gh<_i801.DashboardCountsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i681.RoleCatalogRepository>(
    () => _i564.RoleCatalogRepositoryImpl(
      gh<_i1064.SupabaseRoleCatalogDataSource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factoryParam<_i95.ContactCtaCubit, _i699.Listing, dynamic>(
    (listing, _) => _i95.ContactCtaCubit(listing),
  );
  gh.factory<_i866.LeadEventRepository>(
    () =>
        _i33.LeadEventRepositoryImpl(gh<_i1043.SupabaseInquiriesDatasource>()),
  );
  gh.lazySingleton<_i563.NotificationsRepository>(
    () => _i201.NotificationsRepositoryImpl(
      gh<_i1059.SupabaseNotificationsDatasource>(),
    ),
  );
  gh.lazySingleton<_i120.AccountApprovalsRepository>(
    () => _i278.AccountApprovalsRepositoryImpl(
      gh<_i394.SupabaseAccountApprovalsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i186.AdsServingRepository>(
    () => _i202.AdsServingRepositoryImpl(
      gh<_i1005.SupabaseAdsServingDatasource>(),
    ),
  );
  gh.factory<_i1003.AdminAnalyticsCubit>(
    () => _i1003.AdminAnalyticsCubit(gh<_i571.AdminAnalyticsRepository>()),
  );
  gh.factory<_i357.SearchRepository>(
    () => _i1017.SearchRepositoryImpl(gh<_i713.SupabaseSearchDatasource>()),
  );
  gh.lazySingleton<_i753.PreferencesStore>(
    () => _i190.SecurePreferencesStore(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i554.AssistantStatsRepository>(
    () => _i142.AssistantStatsRepositoryImpl(
      gh<_i918.AssistantStatsDatasource>(),
    ),
  );
  gh.lazySingleton<_i894.ProfileRepository>(
    () => _i334.ProfileRepositoryImpl(
      gh<_i825.SupabaseProfileDataSource>(),
      gh<_i354.AppLogger>(),
    ),
    dispose: (i) => i.dispose(),
  );
  gh.factory<_i808.ReportsRepository>(
    () => _i227.ReportsRepositoryImpl(gh<_i231.SupabaseReportsDatasource>()),
  );
  gh.lazySingleton<_i673.AppSettingsRepository>(
    () => _i1061.AppSettingsRepositoryImpl(
      gh<_i835.SupabaseAppSettingsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factory<_i283.LoadReels>(
    () => _i283.LoadReels(gh<_i695.ReelsRepository>()),
  );
  gh.lazySingleton<_i1006.AgencyRepository>(
    () => _i246.AgencyRepositoryImpl(gh<_i514.SupabaseAgencyDatasource>()),
  );
  gh.lazySingleton<_i704.LocationsRepository>(
    () => _i178.LocationsRepositoryImpl(
      gh<_i665.SupabaseLocationsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i452.ListingCoordinatesReader>(
    () => _i452.ListingCoordinatesReader(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i562.LocalReminderScheduler>(
    () => _i562.LocalReminderScheduler(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i1066.PushNotificationChannel>(
    () => _i1066.PushNotificationChannel(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i76.SupabaseAuthDataSource>(
    () => _i76.SupabaseAuthDataSource(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i144.OnboardingSeenStorage>(
    () => _i144.OnboardingSeenStorage(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i43.RecentlyViewedStore>(
    () => _i43.RecentlyViewedStore(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i193.RecentSearchesStorage>(
    () => _i193.RecentSearchesStorage(gh<_i354.AppLogger>()),
  );
  gh.factory<_i933.CheckForUpdate>(
    () => _i933.CheckForUpdate(gh<_i756.AppUpdateRepository>()),
  );
  gh.factory<_i195.CreateAgency>(
    () => _i195.CreateAgency(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i917.InviteAgencyMember>(
    () => _i917.InviteAgencyMember(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i570.LoadAgencyAnalytics>(
    () => _i570.LoadAgencyAnalytics(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i686.LoadAgencyById>(
    () => _i686.LoadAgencyById(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i1048.LoadAgencyListings>(
    () => _i1048.LoadAgencyListings(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i144.LoadAgencyMembers>(
    () => _i144.LoadAgencyMembers(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i611.LoadMyActiveAgencies>(
    () => _i611.LoadMyActiveAgencies(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i324.LoadMyAgency>(
    () => _i324.LoadMyAgency(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i470.LoadMyAgencyInvitations>(
    () => _i470.LoadMyAgencyInvitations(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i977.LoadMyVerificationRequest>(
    () => _i977.LoadMyVerificationRequest(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i262.RemoveAgencyMember>(
    () => _i262.RemoveAgencyMember(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i552.RespondAgencyInvitation>(
    () => _i552.RespondAgencyInvitation(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i975.SetAgencyMemberRole>(
    () => _i975.SetAgencyMemberRole(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i377.SubmitAgencyVerification>(
    () => _i377.SubmitAgencyVerification(gh<_i1006.AgencyRepository>()),
  );
  gh.factory<_i609.UpdateAgencyProfile>(
    () => _i609.UpdateAgencyProfile(gh<_i1006.AgencyRepository>()),
  );
  gh.lazySingleton<_i752.SupabaseClientWrapper>(
    () => _i748.SupabaseClientWrapperImpl(gh<_i354.AppLogger>()),
  );
  gh.lazySingleton<_i823.NearbyAmenitiesRepository>(
    () => _i897.NearbyAmenitiesRepositoryImpl(
      gh<_i676.OverpassNearbyAmenitiesDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factory<_i190.SearchListingsUseCase>(
    () => _i190.SearchListingsUseCase(gh<_i357.SearchRepository>()),
  );
  gh.factory<_i530.SupabaseListingReviewDatasource>(
    () => _i530.SupabaseListingReviewDatasource(
      gh<_i454.SupabaseClient>(),
      gh<_i452.ListingCoordinatesReader>(),
    ),
  );
  gh.factory<_i212.FavoritesRepository>(
    () => _i144.FavoritesRepositoryImpl(gh<_i8.SupabaseFavoritesDatasource>()),
  );
  gh.lazySingleton<_i392.MarketInsightsRepository>(
    () => _i190.MarketInsightsRepositoryImpl(
      gh<_i111.SupabaseMarketInsightsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i563.PublisherDashboardCountsRepository>(
    () => _i815.PublisherDashboardCountsRepositoryImpl(
      gh<_i157.PublisherDashboardCountsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i420.ChatRepository>(
    () => _i504.ChatRepositoryImpl(gh<_i572.SupabaseChatDatasource>()),
  );
  gh.factory<_i842.LoadMapMarkers>(
    () => _i842.LoadMapMarkers(gh<_i973.MapRepository>()),
  );
  gh.factory<_i180.LoadServingAds>(
    () => _i180.LoadServingAds(gh<_i186.AdsServingRepository>()),
  );
  gh.factory<_i930.RecordAdClick>(
    () => _i930.RecordAdClick(gh<_i186.AdsServingRepository>()),
  );
  gh.factory<_i568.NearbyAmenitiesCubit>(
    () => _i568.NearbyAmenitiesCubit(gh<_i823.NearbyAmenitiesRepository>()),
  );
  gh.factory<_i290.MarketInsightsCubit>(
    () => _i290.MarketInsightsCubit(gh<_i392.MarketInsightsRepository>()),
  );
  gh.factory<_i71.AgencyMembersBloc>(
    () => _i71.AgencyMembersBloc(
      gh<_i144.LoadAgencyMembers>(),
      gh<_i917.InviteAgencyMember>(),
      gh<_i975.SetAgencyMemberRole>(),
      gh<_i262.RemoveAgencyMember>(),
    ),
  );
  gh.lazySingleton<_i503.ViewingsRepository>(
    () => _i495.ViewingsRepositoryImpl(gh<_i222.SupabaseViewingsDatasource>()),
  );
  gh.factory<_i365.LoadAuditLogPage>(
    () => _i365.LoadAuditLogPage(gh<_i881.AuditLogRepository>()),
  );
  gh.factory<_i670.LoadDashboardCounts>(
    () => _i670.LoadDashboardCounts(gh<_i662.DashboardRepository>()),
  );
  gh.lazySingleton<_i430.OnboardingRepository>(
    () => _i452.OnboardingRepositoryImpl(gh<_i144.OnboardingSeenStorage>()),
  );
  gh.lazySingleton<_i934.PublisherAnalyticsRepository>(
    () => _i945.PublisherAnalyticsRepositoryImpl(
      gh<_i855.PublisherAnalyticsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i91.AgenciesAdminRepository>(
    () => _i61.AgenciesAdminRepositoryImpl(
      gh<_i185.SupabaseAgenciesAdminDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factory<_i895.LoadPublisherDailyLeadTotals>(
    () => _i895.LoadPublisherDailyLeadTotals(
      gh<_i934.PublisherAnalyticsRepository>(),
    ),
  );
  gh.factory<_i1026.LoadPublisherListingBreakdown>(
    () => _i1026.LoadPublisherListingBreakdown(
      gh<_i934.PublisherAnalyticsRepository>(),
    ),
  );
  gh.factory<_i710.PublisherChartsCubit>(
    () => _i710.PublisherChartsCubit(gh<_i934.PublisherAnalyticsRepository>()),
  );
  gh.factory<_i941.LoadAssignedRoles>(
    () => _i941.LoadAssignedRoles(gh<_i894.ProfileRepository>()),
  );
  gh.factory<_i363.LoadPii>(() => _i363.LoadPii(gh<_i894.ProfileRepository>()));
  gh.factory<_i1052.LoadProfile>(
    () => _i1052.LoadProfile(gh<_i894.ProfileRepository>()),
  );
  gh.factory<_i231.RequestAccountDeletion>(
    () => _i231.RequestAccountDeletion(gh<_i894.ProfileRepository>()),
  );
  gh.factory<_i281.UpdatePii>(
    () => _i281.UpdatePii(gh<_i894.ProfileRepository>()),
  );
  gh.factory<_i78.UpdateProfile>(
    () => _i78.UpdateProfile(gh<_i894.ProfileRepository>()),
  );
  gh.lazySingleton<_i505.CurrenciesRepository>(
    () => _i148.CurrenciesRepositoryImpl(
      gh<_i311.SupabaseCurrenciesDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i765.UserSearchRepository>(
    () => _i884.UserSearchRepositoryImpl(
      gh<_i24.SupabaseUserSearchDataSource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factory<_i732.SavedSearchesRepository>(
    () => _i735.SavedSearchesRepositoryImpl(
      gh<_i782.SupabaseSavedSearchesDatasource>(),
    ),
  );
  gh.factory<_i800.AgencyInvitationsCubit>(
    () => _i800.AgencyInvitationsCubit(
      gh<_i470.LoadMyAgencyInvitations>(),
      gh<_i686.LoadAgencyById>(),
      gh<_i552.RespondAgencyInvitation>(),
    ),
  );
  gh.lazySingleton<_i6.PushTokenRepository>(
    () =>
        _i566.PushTokenRepositoryImpl(gh<_i445.SupabasePushTokenDatasource>()),
  );
  gh.factory<_i373.LoadPublisherDashboardCounts>(
    () => _i373.LoadPublisherDashboardCounts(
      gh<_i563.PublisherDashboardCountsRepository>(),
    ),
  );
  gh.factory<_i615.RecordLeadEvent>(
    () => _i615.RecordLeadEvent(gh<_i866.LeadEventRepository>()),
  );
  gh.factory<_i524.AgencyVerificationCubit>(
    () => _i524.AgencyVerificationCubit(
      gh<_i686.LoadAgencyById>(),
      gh<_i377.SubmitAgencyVerification>(),
      gh<_i977.LoadMyVerificationRequest>(),
    ),
  );
  gh.lazySingleton<_i412.ReviewsRepository>(
    () => _i388.ReviewsRepositoryImpl(
      gh<_i638.SupabaseReviewsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i888.SimilarListingsRepository>(
    () => _i474.SimilarListingsRepositoryImpl(
      gh<_i913.SupabaseSimilarListingsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.lazySingleton<_i754.PublisherDashboardRepository>(
    () => _i240.PublisherDashboardRepositoryImpl(
      gh<_i333.SupabasePublisherDashboardDatasource>(),
    ),
  );
  gh.factory<_i363.ApproveAgency>(
    () => _i363.ApproveAgency(gh<_i91.AgenciesAdminRepository>()),
  );
  gh.factory<_i998.LoadAgencyVerificationQueue>(
    () => _i998.LoadAgencyVerificationQueue(gh<_i91.AgenciesAdminRepository>()),
  );
  gh.factory<_i940.ReinstateAgency>(
    () => _i940.ReinstateAgency(gh<_i91.AgenciesAdminRepository>()),
  );
  gh.factory<_i295.RejectAgency>(
    () => _i295.RejectAgency(gh<_i91.AgenciesAdminRepository>()),
  );
  gh.factory<_i31.SuspendAgency>(
    () => _i31.SuspendAgency(gh<_i91.AgenciesAdminRepository>()),
  );
  gh.lazySingleton<_i973.ReportsAdminRepository>(
    () => _i303.ReportsAdminRepositoryImpl(
      gh<_i433.SupabaseReportsAdminDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factory<_i988.AgencyHomeCubit>(
    () => _i988.AgencyHomeCubit(
      gh<_i324.LoadMyAgency>(),
      gh<_i611.LoadMyActiveAgencies>(),
      gh<_i195.CreateAgency>(),
      gh<_i470.LoadMyAgencyInvitations>(),
      gh<_i686.LoadAgencyById>(),
      gh<_i552.RespondAgencyInvitation>(),
    ),
  );
  gh.lazySingleton<_i433.HomeFeedRepository>(
    () => _i857.HomeFeedRepositoryImpl(gh<_i732.SupabaseHomeFeedDatasource>()),
  );
  gh.factory<_i48.AuditLogCubit>(
    () => _i48.AuditLogCubit(gh<_i365.LoadAuditLogPage>()),
  );
  gh.factory<_i981.LoadSimilarListings>(
    () => _i981.LoadSimilarListings(gh<_i888.SimilarListingsRepository>()),
  );
  gh.lazySingleton<_i895.ListingDetailsRepository>(
    () => _i677.ListingDetailsRepositoryImpl(
      gh<_i1006.SupabaseListingDetailsDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factory<_i840.AgencyAnalyticsCubit>(
    () => _i840.AgencyAnalyticsCubit(gh<_i570.LoadAgencyAnalytics>()),
  );
  gh.factory<_i704.CheckOwnsApprovedListing>(
    () => _i704.CheckOwnsApprovedListing(gh<_i272.InquiryRepository>()),
  );
  gh.factory<_i868.LoadInboxUnreadCount>(
    () => _i868.LoadInboxUnreadCount(gh<_i272.InquiryRepository>()),
  );
  gh.factory<_i1054.LoadInquiryDetail>(
    () => _i1054.LoadInquiryDetail(gh<_i272.InquiryRepository>()),
  );
  gh.factory<_i155.LoadInquiryInbox>(
    () => _i155.LoadInquiryInbox(gh<_i272.InquiryRepository>()),
  );
  gh.factory<_i73.SubmitInquiry>(
    () => _i73.SubmitInquiry(gh<_i272.InquiryRepository>()),
  );
  gh.factory<_i684.UpdateInquiryStatus>(
    () => _i684.UpdateInquiryStatus(gh<_i272.InquiryRepository>()),
  );
  gh.factory<_i891.ListMyListings>(
    () => _i891.ListMyListings(gh<_i754.PublisherDashboardRepository>()),
  );
  gh.factory<_i919.LoadModerationHistoryUseCase>(
    () => _i919.LoadModerationHistoryUseCase(
      gh<_i754.PublisherDashboardRepository>(),
    ),
  );
  gh.factory<_i564.LoadMostRecentRejectionUseCase>(
    () => _i564.LoadMostRecentRejectionUseCase(
      gh<_i754.PublisherDashboardRepository>(),
    ),
  );
  gh.factory<_i576.RenewListing>(
    () => _i576.RenewListing(gh<_i754.PublisherDashboardRepository>()),
  );
  gh.lazySingleton<_i241.AdsAdminRepository>(
    () => _i634.AdsAdminRepositoryImpl(gh<_i185.SupabaseAdsAdminDatasource>()),
  );
  gh.factory<_i1036.DeleteRole>(
    () => _i1036.DeleteRole(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i1018.ListRoles>(
    () => _i1018.ListRoles(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i702.LoadAffectedUserCount>(
    () => _i702.LoadAffectedUserCount(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i518.LoadPermissionCatalog>(
    () => _i518.LoadPermissionCatalog(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i176.LoadRoleDetail>(
    () => _i176.LoadRoleDetail(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i144.LoadRoleUserIds>(
    () => _i144.LoadRoleUserIds(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i315.MutateRole>(
    () => _i315.MutateRole(gh<_i681.RoleCatalogRepository>()),
  );
  gh.factory<_i261.AgencyListingsBloc>(
    () => _i261.AgencyListingsBloc(gh<_i1048.LoadAgencyListings>()),
  );
  gh.factory<_i655.CountCityDependents>(
    () => _i655.CountCityDependents(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i58.CountGovernorateDependents>(
    () => _i58.CountGovernorateDependents(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i880.CreateArea>(
    () => _i880.CreateArea(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i206.CreateCity>(
    () => _i206.CreateCity(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i1027.CreateGovernorate>(
    () => _i1027.CreateGovernorate(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i662.DeleteArea>(
    () => _i662.DeleteArea(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i239.DeleteCity>(
    () => _i239.DeleteCity(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i937.DeleteGovernorate>(
    () => _i937.DeleteGovernorate(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i548.ListAllAreas>(
    () => _i548.ListAllAreas(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i450.ListAllCities>(
    () => _i450.ListAllCities(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i358.ListAreasForCity>(
    () => _i358.ListAreasForCity(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i53.ListCitiesForGovernorate>(
    () => _i53.ListCitiesForGovernorate(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i533.ListGovernorates>(
    () => _i533.ListGovernorates(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i292.LoadAreaDetail>(
    () => _i292.LoadAreaDetail(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i645.LoadCityDetail>(
    () => _i645.LoadCityDetail(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i441.LoadGovernorateDetail>(
    () => _i441.LoadGovernorateDetail(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i188.UpdateArea>(
    () => _i188.UpdateArea(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i1058.UpdateCity>(
    () => _i1058.UpdateCity(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i1054.UpdateGovernorate>(
    () => _i1054.UpdateGovernorate(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i711.ModerationHistoryCubit>(
    () =>
        _i711.ModerationHistoryCubit(gh<_i919.LoadModerationHistoryUseCase>()),
  );
  gh.factory<_i644.LoadMyViewings>(
    () => _i644.LoadMyViewings(gh<_i503.ViewingsRepository>()),
  );
  gh.factory<_i285.RequestViewing>(
    () => _i285.RequestViewing(gh<_i503.ViewingsRepository>()),
  );
  gh.factory<_i725.UpdateViewingStatus>(
    () => _i725.UpdateViewingStatus(gh<_i503.ViewingsRepository>()),
  );
  gh.factory<_i905.CountDependentExchangeRates>(
    () => _i905.CountDependentExchangeRates(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i1003.CreateCurrency>(
    () => _i1003.CreateCurrency(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i43.DeleteCurrency>(
    () => _i43.DeleteCurrency(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i996.ListCurrencies>(
    () => _i996.ListCurrencies(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i776.ListExchangeRateHistory>(
    () => _i776.ListExchangeRateHistory(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i510.LoadCurrencyDetail>(
    () => _i510.LoadCurrencyDetail(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i488.SetExchangeRate>(
    () => _i488.SetExchangeRate(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i540.UpdateCurrency>(
    () => _i540.UpdateCurrency(gh<_i505.CurrenciesRepository>()),
  );
  gh.lazySingleton<_i957.LoadLatestRatesForBase>(
    () => _i957.LoadLatestRatesForBase(gh<_i505.CurrenciesRepository>()),
  );
  gh.factory<_i617.AccountDeletionCubit>(
    () => _i617.AccountDeletionCubit(gh<_i231.RequestAccountDeletion>()),
  );
  gh.factory<_i181.DeregisterPushToken>(
    () => _i181.DeregisterPushToken(gh<_i6.PushTokenRepository>()),
  );
  gh.factory<_i397.RegisterPushToken>(
    () => _i397.RegisterPushToken(gh<_i6.PushTokenRepository>()),
  );
  gh.factory<_i858.ApproveAccount>(
    () => _i858.ApproveAccount(gh<_i120.AccountApprovalsRepository>()),
  );
  gh.factory<_i138.LoadPendingQueue>(
    () => _i138.LoadPendingQueue(gh<_i120.AccountApprovalsRepository>()),
  );
  gh.factory<_i431.RejectAccount>(
    () => _i431.RejectAccount(gh<_i120.AccountApprovalsRepository>()),
  );
  gh.factory<_i705.AddFavorite>(
    () => _i705.AddFavorite(gh<_i212.FavoritesRepository>()),
  );
  gh.factory<_i896.LoadFavoriteIds>(
    () => _i896.LoadFavoriteIds(gh<_i212.FavoritesRepository>()),
  );
  gh.factory<_i1041.LoadFavorites>(
    () => _i1041.LoadFavorites(gh<_i212.FavoritesRepository>()),
  );
  gh.factory<_i828.RemoveFavorite>(
    () => _i828.RemoveFavorite(gh<_i212.FavoritesRepository>()),
  );
  gh.factory<_i650.AssignRoleToUser>(
    () => _i650.AssignRoleToUser(gh<_i765.UserSearchRepository>()),
  );
  gh.factory<_i646.LoadUserAssignments>(
    () => _i646.LoadUserAssignments(gh<_i765.UserSearchRepository>()),
  );
  gh.factory<_i950.RevokeRoleFromUser>(
    () => _i950.RevokeRoleFromUser(gh<_i765.UserSearchRepository>()),
  );
  gh.factory<_i143.SearchUsers>(
    () => _i143.SearchUsers(gh<_i765.UserSearchRepository>()),
  );
  gh.factory<_i264.InquiryInboxBloc>(
    () => _i264.InquiryInboxBloc(gh<_i155.LoadInquiryInbox>()),
  );
  gh.factory<_i911.LoadReportsQueue>(
    () => _i911.LoadReportsQueue(gh<_i973.ReportsAdminRepository>()),
  );
  gh.factory<_i943.ResolveReport>(
    () => _i943.ResolveReport(gh<_i973.ReportsAdminRepository>()),
  );
  gh.factory<_i771.StartReportReview>(
    () => _i771.StartReportReview(gh<_i973.ReportsAdminRepository>()),
  );
  gh.factory<_i714.GetOrCreateConversation>(
    () => _i714.GetOrCreateConversation(gh<_i420.ChatRepository>()),
  );
  gh.factory<_i929.ListConversations>(
    () => _i929.ListConversations(gh<_i420.ChatRepository>()),
  );
  gh.factory<_i211.MarkConversationRead>(
    () => _i211.MarkConversationRead(gh<_i420.ChatRepository>()),
  );
  gh.factory<_i76.SendMessage>(
    () => _i76.SendMessage(gh<_i420.ChatRepository>()),
  );
  gh.factory<_i929.WatchMessages>(
    () => _i929.WatchMessages(gh<_i420.ChatRepository>()),
  );
  gh.lazySingleton<_i155.ListingReviewRepository>(
    () => _i1072.ListingReviewRepositoryImpl(
      gh<_i530.SupabaseListingReviewDatasource>(),
      gh<_i354.AppLogger>(),
    ),
  );
  gh.factoryParam<_i960.LocaleCubit, _i264.Locale?, dynamic>(
    (initialLocale, _) => _i960.LocaleCubit(
      gh<_i753.PreferencesStore>(),
      gh<_i354.AppLogger>(),
      initialLocale,
    ),
  );
  gh.factory<_i552.SearchBloc>(
    () => _i552.SearchBloc(gh<_i190.SearchListingsUseCase>()),
  );
  gh.factory<_i1019.LoadNotifications>(
    () => _i1019.LoadNotifications(gh<_i563.NotificationsRepository>()),
  );
  gh.factory<_i873.LoadUnreadCount>(
    () => _i873.LoadUnreadCount(gh<_i563.NotificationsRepository>()),
  );
  gh.factory<_i852.MarkAllNotificationsRead>(
    () => _i852.MarkAllNotificationsRead(gh<_i563.NotificationsRepository>()),
  );
  gh.factory<_i29.MarkNotificationRead>(
    () => _i29.MarkNotificationRead(gh<_i563.NotificationsRepository>()),
  );
  gh.factory<_i394.PaletteCubit>(
    () =>
        _i394.PaletteCubit(gh<_i753.PreferencesStore>(), gh<_i354.AppLogger>()),
  );
  gh.factory<_i611.ThemeCubit>(
    () => _i611.ThemeCubit(gh<_i753.PreferencesStore>(), gh<_i354.AppLogger>()),
  );
  gh.factory<_i1020.SupabaseListingRevisionDatasource>(
    () => _i1020.SupabaseListingRevisionDatasource(
      gh<_i452.ListingCoordinatesReader>(),
    ),
  );
  gh.factory<_i207.SupabaseListingsDatasource>(
    () =>
        _i207.SupabaseListingsDatasource(gh<_i452.ListingCoordinatesReader>()),
  );
  gh.factory<_i741.PublisherAnalyticsCubit>(
    () => _i741.PublisherAnalyticsCubit(
      gh<_i895.LoadPublisherDailyLeadTotals>(),
      gh<_i1026.LoadPublisherListingBreakdown>(),
    ),
  );
  gh.factoryParam<_i193.InquiryFormBloc, String, dynamic>(
    (_listingId, _) =>
        _i193.InquiryFormBloc(gh<_i73.SubmitInquiry>(), _listingId),
  );
  gh.factory<_i557.LoadSellerTrust>(
    () => _i557.LoadSellerTrust(gh<_i412.ReviewsRepository>()),
  );
  gh.factory<_i225.SubmitReview>(
    () => _i225.SubmitReview(gh<_i412.ReviewsRepository>()),
  );
  gh.factory<_i230.ArchiveAd>(
    () => _i230.ArchiveAd(gh<_i241.AdsAdminRepository>()),
  );
  gh.factory<_i845.CreateAd>(
    () => _i845.CreateAd(gh<_i241.AdsAdminRepository>()),
  );
  gh.factory<_i347.LoadAds>(
    () => _i347.LoadAds(gh<_i241.AdsAdminRepository>()),
  );
  gh.factory<_i484.SetAdActive>(
    () => _i484.SetAdActive(gh<_i241.AdsAdminRepository>()),
  );
  gh.factory<_i502.UpdateAd>(
    () => _i502.UpdateAd(gh<_i241.AdsAdminRepository>()),
  );
  gh.factory<_i831.UploadAdImage>(
    () => _i831.UploadAdImage(gh<_i241.AdsAdminRepository>()),
  );
  gh.factory<_i84.AssistantBrain>(
    () => _i84.RuleBasedAssistantBrain(
      gh<_i367.QueryParser>(),
      gh<_i533.ListGovernorates>(),
      gh<_i450.ListAllCities>(),
      gh<_i548.ListAllAreas>(),
      gh<_i554.AssistantStatsRepository>(),
    ),
  );
  gh.factory<_i49.SellerTrustCubit>(
    () => _i49.SellerTrustCubit(
      gh<_i557.LoadSellerTrust>(),
      gh<_i225.SubmitReview>(),
    ),
  );
  gh.factory<_i295.AccountApprovalsCubit>(
    () => _i295.AccountApprovalsCubit(
      gh<_i138.LoadPendingQueue>(),
      gh<_i858.ApproveAccount>(),
      gh<_i431.RejectAccount>(),
    ),
  );
  gh.factory<_i516.ReelsFeedCubit>(
    () => _i516.ReelsFeedCubit(gh<_i283.LoadReels>()),
  );
  gh.factory<_i847.ReelsRailCubit>(
    () => _i847.ReelsRailCubit(gh<_i283.LoadReels>()),
  );
  gh.factory<_i171.FavoritesPageBloc>(
    () => _i171.FavoritesPageBloc(gh<_i1041.LoadFavorites>()),
  );
  gh.factory<_i616.DashboardCubit>(
    () => _i616.DashboardCubit(
      gh<_i670.LoadDashboardCounts>(),
      gh<_i591.RealtimeSignals>(),
    ),
  );
  gh.factory<_i906.DeriveAreaCentroid>(
    () => _i906.DeriveAreaCentroid(gh<_i704.LocationsRepository>()),
  );
  gh.factory<_i36.ProfileCubit>(
    () => _i36.ProfileCubit(
      gh<_i1052.LoadProfile>(),
      gh<_i78.UpdateProfile>(),
      gh<_i363.LoadPii>(),
      gh<_i281.UpdatePii>(),
      gh<_i941.LoadAssignedRoles>(),
    ),
  );
  gh.factory<_i415.LoadAllSettings>(
    () => _i415.LoadAllSettings(gh<_i673.AppSettingsRepository>()),
  );
  gh.factory<_i838.LoadPublicSettings>(
    () => _i838.LoadPublicSettings(gh<_i673.AppSettingsRepository>()),
  );
  gh.factory<_i349.UpdateSetting>(
    () => _i349.UpdateSetting(gh<_i673.AppSettingsRepository>()),
  );
  gh.factory<_i1073.CityDetailBloc>(
    () => _i1073.CityDetailBloc(
      gh<_i645.LoadCityDetail>(),
      gh<_i441.LoadGovernorateDetail>(),
      gh<_i358.ListAreasForCity>(),
    ),
  );
  gh.factory<_i255.SimilarListingsCubit>(
    () => _i255.SimilarListingsCubit(
      gh<_i981.LoadSimilarListings>(),
      gh<_i996.ListCurrencies>(),
    ),
  );
  gh.lazySingleton<_i787.AuthRepository>(
    () => _i153.AuthRepositoryImpl(
      gh<_i76.SupabaseAuthDataSource>(),
      gh<_i894.ProfileRepository>(),
      gh<_i354.AppLogger>(),
      gh<_i838.LoadPublicSettings>(),
      gh<_i505.CurrenciesRepository>(),
    ),
    dispose: (i) => i.dispose(),
  );
  gh.factory<_i803.PublisherDashboardSummaryCubit>(
    () => _i803.PublisherDashboardSummaryCubit(
      gh<_i373.LoadPublisherDashboardCounts>(),
      gh<_i591.RealtimeSignals>(),
    ),
  );
  gh.factory<_i929.RecentSearchesCubit>(
    () => _i929.RecentSearchesCubit(gh<_i193.RecentSearchesStorage>()),
  );
  gh.lazySingleton<_i558.NotificationBadgeCubit>(
    () => _i558.NotificationBadgeCubit(gh<_i873.LoadUnreadCount>()),
  );
  gh.factory<_i371.AdSlotCubit>(
    () => _i371.AdSlotCubit(gh<_i180.LoadServingAds>()),
  );
  gh.lazySingleton<_i57.RecentlyViewedCubit>(
    () => _i57.RecentlyViewedCubit(gh<_i43.RecentlyViewedStore>()),
  );
  gh.factory<_i669.AssignRoleBloc>(
    () => _i669.AssignRoleBloc(
      gh<_i143.SearchUsers>(),
      gh<_i646.LoadUserAssignments>(),
      gh<_i650.AssignRoleToUser>(),
      gh<_i950.RevokeRoleFromUser>(),
      gh<_i1018.ListRoles>(),
    ),
  );
  gh.factory<_i968.ChatThreadCubit>(
    () => _i968.ChatThreadCubit(
      gh<_i929.WatchMessages>(),
      gh<_i76.SendMessage>(),
      gh<_i211.MarkConversationRead>(),
    ),
  );
  gh.factory<_i455.UpdatePassword>(
    () => _i455.UpdatePassword(gh<_i787.AuthRepository>()),
  );
  gh.factory<_i419.LocationFormBloc>(
    () => _i419.LocationFormBloc(
      gh<_i441.LoadGovernorateDetail>(),
      gh<_i645.LoadCityDetail>(),
      gh<_i292.LoadAreaDetail>(),
      gh<_i1027.CreateGovernorate>(),
      gh<_i1054.UpdateGovernorate>(),
      gh<_i206.CreateCity>(),
      gh<_i1058.UpdateCity>(),
      gh<_i880.CreateArea>(),
      gh<_i188.UpdateArea>(),
    ),
  );
  gh.lazySingleton<_i1067.AppUpdateCubit>(
    () => _i1067.AppUpdateCubit(gh<_i933.CheckForUpdate>()),
  );
  gh.factory<_i807.OnboardingCubit>(
    () => _i807.OnboardingCubit(gh<_i430.OnboardingRepository>()),
  );
  gh.factory<_i902.ReportResolveCubit>(
    () => _i902.ReportResolveCubit(
      gh<_i771.StartReportReview>(),
      gh<_i943.ResolveReport>(),
    ),
  );
  gh.lazySingleton<_i74.InquiriesUnreadCubit>(
    () => _i74.InquiriesUnreadCubit(
      gh<_i868.LoadInboxUnreadCount>(),
      gh<_i704.CheckOwnsApprovedListing>(),
    ),
  );
  gh.factory<_i176.CurrenciesListBloc>(
    () => _i176.CurrenciesListBloc(
      gh<_i996.ListCurrencies>(),
      gh<_i957.LoadLatestRatesForBase>(),
    ),
  );
  gh.factory<_i293.SetExchangeRateBloc>(
    () => _i293.SetExchangeRateBloc(gh<_i488.SetExchangeRate>()),
  );
  gh.factory<_i912.DeleteSavedSearchUseCase>(
    () => _i912.DeleteSavedSearchUseCase(gh<_i732.SavedSearchesRepository>()),
  );
  gh.factory<_i847.ListSavedSearchesUseCase>(
    () => _i847.ListSavedSearchesUseCase(gh<_i732.SavedSearchesRepository>()),
  );
  gh.factory<_i388.SaveSearchUseCase>(
    () => _i388.SaveSearchUseCase(gh<_i732.SavedSearchesRepository>()),
  );
  gh.factory<_i1.InquiryDetailBloc>(
    () => _i1.InquiryDetailBloc(
      gh<_i1054.LoadInquiryDetail>(),
      gh<_i684.UpdateInquiryStatus>(),
      gh<_i74.InquiriesUnreadCubit>(),
    ),
  );
  gh.factory<_i682.LoadMyReportForListing>(
    () => _i682.LoadMyReportForListing(gh<_i808.ReportsRepository>()),
  );
  gh.factory<_i991.LoadMyReports>(
    () => _i991.LoadMyReports(gh<_i808.ReportsRepository>()),
  );
  gh.factory<_i684.SubmitReport>(
    () => _i684.SubmitReport(gh<_i808.ReportsRepository>()),
  );
  gh.factory<_i930.SetNewPasswordCubit>(
    () => _i930.SetNewPasswordCubit(gh<_i455.UpdatePassword>()),
  );
  gh.factory<_i1051.ReportsQueueBloc>(
    () => _i1051.ReportsQueueBloc(gh<_i911.LoadReportsQueue>()),
  );
  gh.factory<_i812.ViewingsCubit>(
    () => _i812.ViewingsCubit(
      gh<_i644.LoadMyViewings>(),
      gh<_i285.RequestViewing>(),
      gh<_i725.UpdateViewingStatus>(),
    ),
  );
  gh.factory<_i437.MapBloc>(() => _i437.MapBloc(gh<_i842.LoadMapMarkers>()));
  gh.factory<_i885.RoleEditorBloc>(
    () => _i885.RoleEditorBloc(
      gh<_i176.LoadRoleDetail>(),
      gh<_i518.LoadPermissionCatalog>(),
      gh<_i315.MutateRole>(),
    ),
  );
  gh.factory<_i329.RolesListBloc>(
    () => _i329.RolesListBloc(gh<_i1018.ListRoles>()),
  );
  gh.factory<_i835.CrmLeadsCubit>(
    () => _i835.CrmLeadsCubit(
      gh<_i677.CrmRepository>(),
      gh<_i562.LocalReminderScheduler>(),
    ),
  );
  gh.factory<_i664.AgencyModerationCubit>(
    () => _i664.AgencyModerationCubit(
      gh<_i363.ApproveAgency>(),
      gh<_i295.RejectAgency>(),
      gh<_i31.SuspendAgency>(),
      gh<_i940.ReinstateAgency>(),
    ),
  );
  gh.factory<_i240.LoadFeaturedListings>(
    () => _i240.LoadFeaturedListings(gh<_i433.HomeFeedRepository>()),
  );
  gh.factory<_i321.LoadHomeFeed>(
    () => _i321.LoadHomeFeed(gh<_i433.HomeFeedRepository>()),
  );
  gh.factory<_i1026.LeadDetailCubit>(
    () => _i1026.LeadDetailCubit(
      gh<_i677.CrmRepository>(),
      gh<_i562.LocalReminderScheduler>(),
      gh<_i1054.LoadInquiryDetail>(),
      gh<_i714.GetOrCreateConversation>(),
    ),
  );
  gh.lazySingleton<_i902.ListingRevisionsRepository>(
    () => _i736.ListingRevisionsRepositoryImpl(
      gh<_i1020.SupabaseListingRevisionDatasource>(),
    ),
  );
  gh.factory<_i949.ExchangeRateHistoryBloc>(
    () => _i949.ExchangeRateHistoryBloc(gh<_i776.ListExchangeRateHistory>()),
  );
  gh.lazySingleton<_i557.AppSettingsCubit>(
    () => _i557.AppSettingsCubit(gh<_i838.LoadPublicSettings>()),
  );
  gh.factory<_i66.NotificationsCubit>(
    () => _i66.NotificationsCubit(
      gh<_i1019.LoadNotifications>(),
      gh<_i29.MarkNotificationRead>(),
      gh<_i852.MarkAllNotificationsRead>(),
    ),
  );
  gh.factory<_i1007.ListingReportStatusCubit>(
    () => _i1007.ListingReportStatusCubit(gh<_i682.LoadMyReportForListing>()),
  );
  gh.factory<_i841.ApplyRevision>(
    () => _i841.ApplyRevision(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.factory<_i318.LoadPendingRevisions>(
    () => _i318.LoadPendingRevisions(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.factory<_i169.LoadRevisionDiff>(
    () => _i169.LoadRevisionDiff(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.factory<_i1048.RejectRevision>(
    () => _i1048.RejectRevision(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.factory<_i7.BeginRevision>(
    () => _i7.BeginRevision(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.factory<_i994.FindOpenRevision>(
    () => _i994.FindOpenRevision(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.factory<_i657.LoadRevision>(
    () => _i657.LoadRevision(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.factory<_i222.SaveRevision>(
    () => _i222.SaveRevision(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.factory<_i62.SubmitRevision>(
    () => _i62.SubmitRevision(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.factory<_i520.UploadStagedImage>(
    () => _i520.UploadStagedImage(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.factory<_i520.UploadStagedPanorama>(
    () => _i520.UploadStagedPanorama(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.factory<_i520.UploadStagedVideo>(
    () => _i520.UploadStagedVideo(gh<_i902.ListingRevisionsRepository>()),
  );
  gh.lazySingleton<_i340.ListingsRepository>(
    () => _i946.ListingsRepositoryImpl(
      gh<_i207.SupabaseListingsDatasource>(),
      gh<_i214.SupabaseListingMediaDatasource>(),
    ),
  );
  gh.factory<_i796.GovernorateDetailBloc>(
    () => _i796.GovernorateDetailBloc(
      gh<_i441.LoadGovernorateDetail>(),
      gh<_i53.ListCitiesForGovernorate>(),
    ),
  );
  gh.factory<_i610.LocationPickerBloc>(
    () => _i610.LocationPickerBloc(
      gh<_i533.ListGovernorates>(),
      gh<_i53.ListCitiesForGovernorate>(),
      gh<_i358.ListAreasForCity>(),
    ),
  );
  gh.factory<_i602.SavedSearchesCubit>(
    () => _i602.SavedSearchesCubit(
      gh<_i847.ListSavedSearchesUseCase>(),
      gh<_i388.SaveSearchUseCase>(),
      gh<_i912.DeleteSavedSearchUseCase>(),
    ),
  );
  gh.factory<_i281.LoadListingDetails>(
    () => _i281.LoadListingDetails(gh<_i895.ListingDetailsRepository>()),
  );
  gh.factory<_i676.AppSettingsEditorCubit>(
    () => _i676.AppSettingsEditorCubit(
      gh<_i415.LoadAllSettings>(),
      gh<_i349.UpdateSetting>(),
    ),
  );
  gh.factory<_i665.FeaturedListingsCubit>(
    () => _i665.FeaturedListingsCubit(gh<_i240.LoadFeaturedListings>()),
  );
  gh.factory<_i669.LocationsListBloc>(
    () => _i669.LocationsListBloc(gh<_i533.ListGovernorates>()),
  );
  gh.factory<_i749.MyReportsBloc>(
    () => _i749.MyReportsBloc(gh<_i991.LoadMyReports>()),
  );
  gh.factory<_i657.CurrencyFormBloc>(
    () => _i657.CurrencyFormBloc(
      gh<_i1003.CreateCurrency>(),
      gh<_i540.UpdateCurrency>(),
      gh<_i510.LoadCurrencyDetail>(),
    ),
  );
  gh.factory<_i404.ApproveListingUseCase>(
    () => _i404.ApproveListingUseCase(gh<_i155.ListingReviewRepository>()),
  );
  gh.factory<_i542.FeatureListingUseCase>(
    () => _i542.FeatureListingUseCase(gh<_i155.ListingReviewRepository>()),
  );
  gh.factory<_i96.LoadListingPreviewUseCase>(
    () => _i96.LoadListingPreviewUseCase(gh<_i155.ListingReviewRepository>()),
  );
  gh.factory<_i207.LoadPendingQueueUseCase>(
    () => _i207.LoadPendingQueueUseCase(gh<_i155.ListingReviewRepository>()),
  );
  gh.factory<_i880.RejectListingUseCase>(
    () => _i880.RejectListingUseCase(gh<_i155.ListingReviewRepository>()),
  );
  gh.factory<_i916.AgencyQueueBloc>(
    () => _i916.AgencyQueueBloc(gh<_i998.LoadAgencyVerificationQueue>()),
  );
  gh.factory<_i417.MyListingsBloc>(
    () => _i417.MyListingsBloc(
      gh<_i891.ListMyListings>(),
      gh<_i576.RenewListing>(),
    ),
  );
  gh.factory<_i682.AdsAdminCubit>(
    () => _i682.AdsAdminCubit(
      gh<_i347.LoadAds>(),
      gh<_i845.CreateAd>(),
      gh<_i502.UpdateAd>(),
      gh<_i484.SetAdActive>(),
      gh<_i230.ArchiveAd>(),
      gh<_i831.UploadAdImage>(),
    ),
  );
  gh.factory<_i992.RevisionReviewBloc>(
    () => _i992.RevisionReviewBloc(
      gh<_i169.LoadRevisionDiff>(),
      gh<_i841.ApplyRevision>(),
      gh<_i1048.RejectRevision>(),
    ),
  );
  gh.factory<_i665.ConversationsCubit>(
    () => _i665.ConversationsCubit(gh<_i929.ListConversations>()),
  );
  gh.factory<_i697.AssistantCubit>(
    () => _i697.AssistantCubit(gh<_i84.AssistantBrain>()),
  );
  gh.factory<_i980.ReportSubmissionCubit>(
    () => _i980.ReportSubmissionCubit(gh<_i684.SubmitReport>()),
  );
  gh.factory<_i202.HomeBloc>(() => _i202.HomeBloc(gh<_i321.LoadHomeFeed>()));
  gh.lazySingleton<_i797.AuthBloc>(
    () => _i797.AuthBloc(
      gh<_i787.AuthRepository>(),
      gh<_i894.ProfileRepository>(),
      gh<_i650.PermissionChecker>(),
      gh<_i397.RegisterPushToken>(),
      gh<_i181.DeregisterPushToken>(),
      gh<_i563.PushMessagingService>(),
      gh<_i591.RealtimeSignals>(),
    ),
    dispose: (i) => i.dispose(),
  );
  gh.factory<_i814.DeleteDraft>(
    () => _i814.DeleteDraft(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i732.DeleteMedia>(
    () => _i732.DeleteMedia(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i406.LoadMediaForListing>(
    () => _i406.LoadMediaForListing(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i802.LoadOrCreateDraft>(
    () => _i802.LoadOrCreateDraft(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i1022.ReorderMedia>(
    () => _i1022.ReorderMedia(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i874.SaveFormStep>(
    () => _i874.SaveFormStep(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i629.SetMainImage>(
    () => _i629.SetMainImage(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i829.SubmitListing>(
    () => _i829.SubmitListing(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i1062.UploadImage>(
    () => _i1062.UploadImage(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i206.UploadPanorama>(
    () => _i206.UploadPanorama(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i490.UploadVideo>(
    () => _i490.UploadVideo(gh<_i340.ListingsRepository>()),
  );
  gh.factory<_i315.ListingFormBloc>(
    () => _i315.ListingFormBloc(
      gh<_i874.SaveFormStep>(),
      gh<_i829.SubmitListing>(),
      gh<_i814.DeleteDraft>(),
      gh<_i906.DeriveAreaCentroid>(),
      gh<_i396.ValidateSubmitPayload>(),
      gh<_i340.ListingsRepository>(),
      gh<_i1062.UploadImage>(),
      gh<_i490.UploadVideo>(),
      gh<_i206.UploadPanorama>(),
      gh<_i1022.ReorderMedia>(),
      gh<_i629.SetMainImage>(),
      gh<_i732.DeleteMedia>(),
      gh<_i406.LoadMediaForListing>(),
      gh<_i611.LoadMyActiveAgencies>(),
      gh<_i557.AppSettingsCubit>(),
      gh<_i957.VideoProcessor>(),
      gh<_i7.BeginRevision>(),
      gh<_i657.LoadRevision>(),
      gh<_i222.SaveRevision>(),
      gh<_i62.SubmitRevision>(),
      gh<_i520.UploadStagedImage>(),
      gh<_i520.UploadStagedVideo>(),
      gh<_i520.UploadStagedPanorama>(),
    ),
  );
  gh.factory<_i554.PendingQueueBloc>(
    () => _i554.PendingQueueBloc(gh<_i207.LoadPendingQueueUseCase>()),
  );
  gh.lazySingleton<_i583.GoRouter>(
    () => routerModule.router(gh<_i354.AppLogger>(), gh<_i797.AuthBloc>()),
  );
  gh.factory<_i277.PendingRevisionsCubit>(
    () => _i277.PendingRevisionsCubit(gh<_i318.LoadPendingRevisions>()),
  );
  gh.factory<_i778.ListingPreviewBloc>(
    () => _i778.ListingPreviewBloc(
      gh<_i96.LoadListingPreviewUseCase>(),
      gh<_i404.ApproveListingUseCase>(),
      gh<_i880.RejectListingUseCase>(),
      gh<_i542.FeatureListingUseCase>(),
    ),
  );
  gh.lazySingleton<_i991.FavoritesCubit>(
    () => _i991.FavoritesCubit(
      gh<_i896.LoadFavoriteIds>(),
      gh<_i705.AddFavorite>(),
      gh<_i828.RemoveFavorite>(),
      gh<_i797.AuthBloc>(),
    ),
    dispose: (i) => i.dispose(),
  );
  gh.factory<_i935.ListingDetailsBloc>(
    () => _i935.ListingDetailsBloc(
      gh<_i281.LoadListingDetails>(),
      gh<_i797.AuthBloc>(),
    ),
  );
  return getIt;
}

class _$SupabaseModule extends _i464.SupabaseModule {}

class _$RouterModule extends _i464.RouterModule {}
