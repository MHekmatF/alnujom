import 'package:flutter/material.dart';

/// Shown in place of any widget that throws while building, in release and
/// profile builds (wired as `ErrorWidget.builder` in `main.dart`).
///
/// Flutter's own release ErrorWidget is a bare grey rectangle, and with no
/// crash-reporter DSN configured the exception reaches neither the screen nor
/// the log — so a broken screen looks exactly like a blank one. That is how an
/// unregistered dependency once shipped unnoticed until someone walked the app
/// on a device. This at least gives the failure a face.
///
/// **Deliberately self-contained.** It uses raw colours, an inline text style
/// and hardcoded Arabic instead of the design tokens and the ARBs, because any
/// of those may be exactly what failed — reaching for `AppColors.of(context)`
/// or `AppStrings.of(context)` here risks throwing inside the error handler and
/// looping. Both linters exempt this one file for that reason; do not copy the
/// pattern anywhere else.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF4F6FA),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: Color(0xFFC43D3D)),
              SizedBox(height: 12),
              Text(
                'تعذّر عرض هذه الشاشة',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0E1A2E),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'ارجع وحاول مرة أخرى.',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF5B6577)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
