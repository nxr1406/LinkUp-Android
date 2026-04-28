import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';

// ─────────────────────────────────────────────
//  Shared helpers
// ─────────────────────────────────────────────
class AppLockService {
  static const _kEnabled = 'app_lock_enabled';
  static const _kPin    = 'app_lock_pin';

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kEnabled) ?? false;
  }

  static Future<String?> getPin() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kPin);
  }

  static Future<void> enable(String pin) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, true);
    await p.setString(_kPin, pin);
  }

  static Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, false);
    await p.remove(_kPin);
  }

  static Future<void> changePin(String newPin) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPin, newPin);
  }
}

// ─────────────────────────────────────────────
//  Mode enum
// ─────────────────────────────────────────────
enum AppLockMode { unlock, setNew, confirmNew, changeOld, changeNew, changeConfirm }

// ─────────────────────────────────────────────
//  Main PIN screen
// ─────────────────────────────────────────────
class AppLockScreen extends StatefulWidget {
  /// true  → user is opening the app and must enter their PIN
  /// false → user is in settings (set/change/disable)
  final bool isUnlocking;

  const AppLockScreen({super.key, this.isUnlocking = true});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _firstPin = '';
  AppLockMode _mode = AppLockMode.unlock;
  String? _errorText;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // indigo from the design reference
  static const Color _accent = Color(0xFF5C6BC0);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _accentRed = Color(0xFFEF5350);
  static const int _pinLen = 4;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _initMode();
  }

  Future<void> _initMode() async {
    if (widget.isUnlocking) {
      setState(() => _mode = AppLockMode.unlock);
    } else {
      final enabled = await AppLockService.isEnabled();
      setState(() => _mode = enabled ? AppLockMode.changeOld : AppLockMode.setNew);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── PIN input ──────────────────────────────
  void _onKey(String k) {
    if (_pin.length >= _pinLen) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += k;
      _errorText = null;
    });
    if (_pin.length == _pinLen) {
      Future.delayed(const Duration(milliseconds: 120), _evaluate);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  // ── Evaluate filled PIN ────────────────────
  Future<void> _evaluate() async {
    switch (_mode) {
      case AppLockMode.unlock:
        await _handleUnlock();
      case AppLockMode.setNew:
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _mode = AppLockMode.confirmNew;
        });
      case AppLockMode.confirmNew:
        if (_pin == _firstPin) {
          await AppLockService.enable(_pin);
          if (mounted) Navigator.pop(context, true);
        } else {
          _shake('PINs do not match. Try again.');
          setState(() => _mode = AppLockMode.setNew);
        }
      case AppLockMode.changeOld:
        final saved = await AppLockService.getPin();
        if (_pin == saved) {
          setState(() { _pin = ''; _mode = AppLockMode.changeNew; });
        } else {
          _shake('Incorrect PIN');
        }
      case AppLockMode.changeNew:
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _mode = AppLockMode.changeConfirm;
        });
      case AppLockMode.changeConfirm:
        if (_pin == _firstPin) {
          await AppLockService.changePin(_pin);
          if (mounted) Navigator.pop(context, true);
        } else {
          _shake('PINs do not match. Try again.');
          setState(() => _mode = AppLockMode.changeNew);
        }
    }
  }

  Future<void> _handleUnlock() async {
    final saved = await AppLockService.getPin();
    if (_pin == saved) {
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } else {
      _shake('Incorrect PIN');
    }
  }

  void _shake(String msg) {
    HapticFeedback.vibrate();
    setState(() { _errorText = msg; _pin = ''; });
    _shakeCtrl.forward(from: 0);
  }

  // ── Label per mode ─────────────────────────
  String get _title {
    switch (_mode) {
      case AppLockMode.unlock:      return 'Enter PIN';
      case AppLockMode.setNew:      return 'Set new PIN';
      case AppLockMode.confirmNew:  return 'Confirm PIN';
      case AppLockMode.changeOld:   return 'Enter current PIN';
      case AppLockMode.changeNew:   return 'Enter new PIN';
      case AppLockMode.changeConfirm: return 'Confirm new PIN';
    }
  }

  Color get _dotActiveColor {
    if (_errorText != null) return _accentRed;
    switch (_mode) {
      case AppLockMode.confirmNew:
      case AppLockMode.changeConfirm:
        return _accentGreen;
      default:
        return _accent;
    }
  }

  // ─────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const dark = false;
    final bg = dark ? const Color(0xFF0F0F14) : const Color(0xFFF0F1FF);
    final surface = dark ? const Color(0xFF1A1A2E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          // ── top bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              if (!widget.isUnlocking)
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded_ios_new_rounded_new,
                      color: dark ? Colors.white70 : Colors.black54, size: 20),
                  onPressed: () => Navigator.pop(context, false),
                ),
              const Spacer(),
            ]),
          ),

          const Spacer(flex: 2),

          // ── logo / title ──
          _PinLogo(dark: dark, accent: _accent),
          const SizedBox(height: 20),
          Text(
            _title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white : const Color(0xFF1A1A2E),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: _errorText != null ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              _errorText ?? '',
              style: TextStyle(
                  color: _accentRed, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),

          const SizedBox(height: 36),

          // ── dot indicators ──
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) =>
                Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLen, (i) {
                final filled = i < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? _dotActiveColor : Colors.transparent,
                    border: Border.all(
                      color: filled
                          ? _dotActiveColor
                          : (dark ? Colors.white30 : const Color(0xFFBBBBCC)),
                      width: 2,
                    ),
                    boxShadow: filled
                        ? [BoxShadow(color: _dotActiveColor.withOpacity(0.35),
                            blurRadius: 8, spreadRadius: 1)]
                        : [],
                  ),
                );
              }),
            ),
          ),

          const Spacer(flex: 3),

          // ── keypad ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: _Keypad(
              dark: dark,
              surface: surface,
              accent: _accent,
              onKey: _onKey,
              onDelete: _onDelete,
            ),
          ),

          const SizedBox(height: 16),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Small logo widget (matching design reference)
// ─────────────────────────────────────────────
class _PinLogo extends StatelessWidget {
  final bool dark;
  final Color accent;
  const _PinLogo({required this.dark, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withOpacity(0.6)],
        ),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.35), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: const Icon(Icons.lock_rounded_rounded, color: Colors.white, size: 30),
    );
  }
}

// ─────────────────────────────────────────────
//  Numeric keypad
// ─────────────────────────────────────────────
class _Keypad extends StatelessWidget {
  final bool dark;
  final Color surface;
  final Color accent;
  final void Function(String) onKey;
  final VoidCallback onDelete;

  const _Keypad({
    required this.dark,
    required this.surface,
    required this.accent,
    required this.onKey,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: row.map((k) {
              if (k.isEmpty) return const SizedBox(width: 72, height: 72);
              return _Key(
                label: k,
                dark: dark,
                surface: surface,
                accent: accent,
                onTap: k == '⌫' ? () => onDelete() : () => onKey(k),
                isDelete: k == '⌫',
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _Key extends StatefulWidget {
  final String label;
  final bool dark, isDelete;
  final Color surface, accent;
  final VoidCallback onTap;

  const _Key({
    required this.label,
    required this.dark,
    required this.surface,
    required this.accent,
    required this.onTap,
    this.isDelete = false,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = _pressed
        ? widget.accent.withOpacity(widget.dark ? 0.3 : 0.15)
        : widget.surface;

    return GestureDetector(
      onTapDown: (_) { setState(() => _pressed = true); widget.onTap(); },
      onTapUp: (_) => Future.delayed(
          const Duration(milliseconds: 120), () { if (mounted) setState(() => _pressed = false); }),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.dark ? 0.3 : 0.08),
              blurRadius: _pressed ? 2 : 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: widget.dark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: widget.isDelete
            ? Icon(Icons.backspace_outlined,
                color: widget.dark ? Colors.white70 : Colors.black54, size: 22)
            : Text(
                widget.label,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                  color: widget.dark ? Colors.white : const Color(0xFF1A1A2E),
                  height: 1,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Settings tile widget (used in profile_screen)
// ─────────────────────────────────────────────
class AppLockSettingsTile extends StatefulWidget {
  final bool dark;
  const AppLockSettingsTile({super.key, required this.dark});

  @override
  State<AppLockSettingsTile> createState() => _AppLockSettingsTileState();
}

class _AppLockSettingsTileState extends State<AppLockSettingsTile> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await AppLockService.isEnabled();
    if (mounted) setState(() => _enabled = e);
  }

  Future<void> _toggle() async {
    if (_enabled) {
      // Verify current PIN before disabling
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const AppLockScreen(isUnlocking: true),
        ),
      );
      if (ok == true) {
        await AppLockService.disable();
        if (mounted) setState(() => _enabled = false);
        _snack('App Lock disabled');
      }
    } else {
      // Set new PIN
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const AppLockScreen(isUnlocking: false),
        ),
      );
      if (ok == true) {
        if (mounted) setState(() => _enabled = true);
        _snack('App Lock enabled');
      }
    }
  }

  Future<void> _changePin() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AppLockScreen(isUnlocking: false),
      ),
    );
    if (ok == true && mounted) _snack('PIN changed successfully');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = AppColors.textPrimary(widget.dark);
    final ts = AppColors.textSecondary(widget.dark);

    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.lock_rounded_rounded, color: AppColors.primary, size: 22),
          title: Text('App Lock',
              style: TextStyle(color: tc, fontSize: 15, fontWeight: FontWeight.w500)),
          subtitle: Text(
            _enabled ? 'PIN lock is active' : 'Protect app with a PIN',
            style: TextStyle(color: ts, fontSize: 12),
          ),
          trailing: LinkUpToggle(
            value: _enabled,
            onChanged: (_) => _toggle(),
          ),
        ),
        if (_enabled)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            title: Text('Change PIN',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            trailing: Icon(Icons.arrow_forward_ios,
                color: AppColors.primary, size: 14),
            onTap: _changePin,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Wrapper that shows PIN screen on app resume
// ─────────────────────────────────────────────
class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkLock() async {
    final enabled = await AppLockService.isEnabled();
    if (mounted) setState(() { _locked = enabled; _checked = true; });
    if (enabled && mounted) _showLock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AppLockService.isEnabled().then((e) {
        if (e && mounted) setState(() => _locked = true);
      });
    }
    if (state == AppLifecycleState.resumed && _locked) {
      _showLock();
    }
  }

  Future<void> _showLock() async {
    if (!mounted) return;
    final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => const AppLockScreen(isUnlocking: true),
      ),
    );
    if (ok == true && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox();
    return widget.child;
  }
}

// ─────────────────────────────────────────────
//  Shared LinkUpToggle — matches uploaded iOS design
//  ON : pink track + big white thumb right
//  OFF: light grey track + big white thumb left (neumorphic shadow)
// ─────────────────────────────────────────────
class LinkUpToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const LinkUpToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // track: 51 wide × 31 tall — thumb: 27 diameter — margin: 2
    const double trackW  = 51;
    const double trackH  = 31;
    const double thumbD  = 27;
    const double margin  = 2;

    final offTrack  = const Color(0xFFE5E5EA);
    final onTrack   = AppColors.primary;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: trackW,
        height: trackH,
        child: Stack(
          children: [
            // ── Track ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeInOut,
              width: trackW,
              height: trackH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(trackH / 2),
                color: value ? onTrack : offTrack,
                boxShadow: value
                    ? [
                        BoxShadow(
                          color: onTrack.withOpacity(0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        // inner shadow illusion: dark bottom-right
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
            ),

            // ── Thumb ──
            AnimatedPositioned(
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeInOut,
              left: value ? trackW - thumbD - margin : margin,
              top: (trackH - thumbD) / 2,
              child: Container(
                width: thumbD,
                height: thumbD,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    // main drop shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                    // subtle top highlight
                    BoxShadow(
                      color: Colors.white.withOpacity(0.90),
                      blurRadius: 1,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
