// Phase 29 (029-crm-reels-growth) — W2: admin analytics domain entities.
// Pure Dart (Constitution IX). The four chart series backing the admin
// analytics page. Each admin chart RPC re-gates server-side and returns ZERO
// rows when the caller lacks the permission, so an empty list here simply means
// "no data / not permitted" and the page renders an empty hint (never an error).

/// A single (month, total) point — listings or profiles created in that month.
class AdminMonthlyTotal {
  const AdminMonthlyTotal({required this.month, required this.total});

  /// The first day of the calendar month (date only).
  final DateTime month;

  /// Total rows created in [month] (>= 0).
  final int total;
}

/// A single (day, total) point — lead events recorded on that day.
class AdminDailyTotal {
  const AdminDailyTotal({required this.day, required this.total});

  /// The calendar day (date only).
  final DateTime day;

  /// Total lead events recorded on [day] (>= 0; gap-filled days carry 0).
  final int total;
}

/// Active listings in one governorate, with its bilingual display name.
class AdminGovernorateTotal {
  const AdminGovernorateTotal({
    required this.nameAr,
    required this.nameEn,
    required this.total,
  });

  /// Arabic display name (always present per the governorates schema).
  final String nameAr;

  /// English display name (may be empty — Arabic is the required value).
  final String nameEn;

  /// Active (approved) listings in this governorate.
  final int total;
}

/// The full admin-analytics payload: four independent series. Any may be empty
/// (no data, or the caller lacks that section's permission).
class AdminAnalytics {
  const AdminAnalytics({
    required this.listingsByMonth,
    required this.profilesByMonth,
    required this.leadEventsByDay,
    required this.listingsByGovernorate,
  });

  /// Listings created per month (gap-filled, oldest → newest).
  final List<AdminMonthlyTotal> listingsByMonth;

  /// Profiles created per month (gap-filled, oldest → newest).
  final List<AdminMonthlyTotal> profilesByMonth;

  /// Lead events per day (gap-filled, oldest → newest).
  final List<AdminDailyTotal> leadEventsByDay;

  /// Active listings per governorate, busiest first (top 10).
  final List<AdminGovernorateTotal> listingsByGovernorate;

  /// An empty payload — handy as an optimistic placeholder.
  static const empty = AdminAnalytics(
    listingsByMonth: [],
    profilesByMonth: [],
    leadEventsByDay: [],
    listingsByGovernorate: [],
  );
}
