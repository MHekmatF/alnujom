-- Say the permissions in Arabic.
--
-- Review 2026-09-05 §4 G13 (plan A33). The role editor is an Arabic-first
-- admin screen whose primary label per permission is the database's English
-- `description` ("Approve a submitted listing."). Translating in the database
-- rather than the app (decision F2) means every surface that ever shows a
-- permission — the role editor today, an audit view or a web console
-- tomorrow — shows the same words, and a new permission ships with its Arabic
-- in the same migration that creates it.
--
-- `description_ar` is nullable so a future key without a translation degrades
-- to the English text rather than failing; the seed below covers all 24.

ALTER TABLE public.permissions ADD COLUMN IF NOT EXISTS description_ar text;

UPDATE public.permissions p SET description_ar = v.ar
FROM (VALUES
  ('ads.manage',          'إدارة الإعلانات الترويجية واللافتات.'),
  ('agencies.approve',    'الموافقة على طلبات المكاتب العقارية.'),
  ('agencies.suspend',    'تعليق مكتب عقاري معتمد.'),
  ('agencies.view',       'عرض دليل المكاتب العقارية.'),
  ('audit_logs.view',     'قراءة سجل الأحداث.'),
  ('currencies.manage',   'إدارة أسعار الصرف والعملات المدعومة.'),
  ('inquiries.view_all',  'عرض الاستفسارات لدى جميع الناشرين.'),
  ('listings.approve',    'الموافقة على إعلان مُرسَل للمراجعة.'),
  ('listings.delete_any', 'حذف أي إعلان بغضّ النظر عن ناشره.'),
  ('listings.edit_any',   'تعديل أي إعلان بغضّ النظر عن ناشره.'),
  ('listings.reject',     'رفض إعلان مُرسَل للمراجعة.'),
  ('listings.view_all',   'عرض جميع الإعلانات لدى كل الناشرين.'),
  ('locations.manage',    'إدارة المحافظات والمدن والمناطق السورية.'),
  ('permissions.manage',  'تعديل جدول الصلاحيات (غير مستخدم حالياً).'),
  ('reports.manage',      'معالجة البلاغات.'),
  ('roles.create',        'إنشاء أدوار مخصصة.'),
  ('roles.delete',        'حذف الأدوار غير النظامية.'),
  ('roles.update',        'تعديل الأدوار وصلاحياتها وتعييناتها.'),
  ('roles.view',          'قراءة قائمة الأدوار.'),
  ('settings.manage',     'تعديل إعدادات التطبيق العامة.'),
  ('users.approve',       'الموافقة على طلب اعتماد حساب.'),
  ('users.reject',        'رفض طلب اعتماد حساب.'),
  ('users.suspend',       'تعليق حساب مستخدم معتمد.'),
  ('users.view',          'الاطلاع على ملفات المستخدمين الآخرين.')
) AS v(key, ar)
WHERE p.key = v.key;

COMMENT ON COLUMN public.permissions.description_ar IS
  'Arabic description shown on Arabic-first admin screens (plan A33). Nullable: a missing translation falls back to description.';

NOTIFY pgrst, 'reload schema';
