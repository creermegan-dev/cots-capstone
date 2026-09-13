import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/auth_navigation.dart';
import '../models/admin_alert_models.dart';
import '../theme/admin_theme.dart';
import '../layout/admin_breakpoints.dart';
import '../layout/admin_responsive_chrome.dart';
import '../widgets/admin_alert_action_dialogs.dart';
import '../widgets/admin_back_icon_button.dart';
import 'admin_shell_screen.dart';

class AdminAlertDetailsScreen extends StatefulWidget {
  const AdminAlertDetailsScreen({super.key, required this.data});

  final AdminAlertDetailsData data;

  @override
  State<AdminAlertDetailsScreen> createState() => _AdminAlertDetailsScreenState();
}

class _AdminAlertDetailsScreenState extends State<AdminAlertDetailsScreen> {
  late AdminAlertStatus _status;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _status = widget.data.status;
  }

  Future<void> _logout() async {
    await confirmAndSignOut(context);
  }

  void _onSidebarSelect(int index) {
    if (index == 4) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminShellScreen(initialIndex: index),
      ),
    );
  }

  void _openFullImage() {
    final url = widget.data.imageUrl;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, p) {
                    if (p == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMarkInProgress() async {
    final ok = await showMarkInProgressConfirmDialog(context);
    if (!mounted || !ok) return;
    setState(() => _status = AdminAlertStatus.inProgress);
  }

  Future<void> _onMarkResolved() async {
    final ok = await showMarkResolvedConfirmDialog(context);
    if (!mounted || !ok) return;
    setState(() => _status = AdminAlertStatus.resolved);
  }

  void _onAlertDetailsRefresh() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Alert details refreshed.'),
      ),
    );
    setState(() {});
    final center = LatLng(widget.data.latitude, widget.data.longitude);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(center, 11);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final st = _status.colors;
    return adminThemedSubtree(
      context,
      child: AdminResponsiveChrome(
        selectedNavIndex: 4,
        onNavSelect: _onSidebarSelect,
        onLogout: _logout,
        pageTitle: 'Alert Details',
        showBackButton: true,
        onBack: () => Navigator.of(context).maybePop(),
        body: LayoutBuilder(
          builder: (context, c) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: AdminBreakpoints.pagePadding(c.maxWidth),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _header(context),
                      const SizedBox(height: 18),
                      _summaryStrip(d, st),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, c2) {
                          final narrow = c2.maxWidth < 1080;
                              final mid = [
                                _alertInfoCard(d),
                                _alertMessageCard(d),
                                _confidenceDetailsCard(d),
                              ];
                              if (narrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [...mid.expand((w) => [w, const SizedBox(height: 14)])]..removeLast(),
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: mid[0]),
                                  const SizedBox(width: 14),
                                  Expanded(child: mid[1]),
                                  const SizedBox(width: 14),
                                  Expanded(child: mid[2]),
                                ],
                              );
                            },
                          ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, c3) {
                          final narrow = c3.maxWidth < 1080;
                              final bot = [
                                _evidenceCard(d),
                                _locationCard(d),
                                _notesCard(d),
                              ];
                              if (narrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [...bot.expand((w) => [w, const SizedBox(height: 14)])]..removeLast(),
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: bot[0]),
                                  const SizedBox(width: 14),
                                  Expanded(child: bot[1]),
                                  const SizedBox(width: 14),
                                  Expanded(child: bot[2]),
                                ],
                              );
                            },
                          ),
                      const SizedBox(height: 22),
                      _actionRow(),
                      const SizedBox(height: 16),
                      Text(
                        'Only authorized administrators and assigned personnel can update the status of this alert.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AdminColors.muted.withValues(alpha: 0.85),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminBackIconButton(onPressed: () => Navigator.of(context).pop()),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {},
              icon: AdminDateTimeTokens.dateChipIcon(),
              label: Text(AdminDateTimeTokens.demoDateRangeLabel, style: AdminDateTimeTokens.dateRangeChipTextStyle),
              style: AdminDateTimeTokens.dateRangeOutlinedButtonStyle(),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _onAlertDetailsRefresh,
              icon: AdminDateTimeTokens.refreshIcon,
              label: const Text('Refresh', style: AdminDateTimeTokens.refreshChipTextStyle),
              style: AdminDateTimeTokens.refreshOutlinedButtonStyle(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Alert Details',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
        ),
        const SizedBox(height: 6),
        Text(
          'Detailed information about the selected alert.',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AdminColors.muted.withValues(alpha: 0.95)),
        ),
      ],
    );
  }

  Widget _summaryStrip(AdminAlertDetailsData d, (Color, Color) st) {
    return _shell(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final stacked = w < 1000;
          final sev = d.severity.color;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sum1(d),
                const SizedBox(height: 14),
                _sum2(d, sev),
                const SizedBox(height: 14),
                _sum3(st),
                const SizedBox(height: 14),
                _sum4(d),
                const SizedBox(height: 14),
                _sum5(d),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 26, child: _sum1(d)),
              _vdiv(),
              Expanded(flex: 24, child: _sum2(d, sev)),
              _vdiv(),
              Expanded(flex: 12, child: _sum3(st)),
              _vdiv(),
              Expanded(flex: 18, child: _sum4(d)),
              _vdiv(),
              Expanded(flex: 18, child: _sum5(d)),
            ],
          );
        },
      ),
    );
  }

  Widget _vdiv() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: VerticalDivider(width: 1, thickness: 1, color: Colors.black.withValues(alpha: 0.06)),
      );

  Widget _sum1(AdminAlertDetailsData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _miniLabel('ALERT ID'),
        Text(
          d.id,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, height: 1.2, color: AdminColors.headerTitle),
        ),
        const SizedBox(height: 10),
        _miniLabel('TYPE'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(d.type.icon, size: 18, color: d.type.iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                d.type.label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  height: 1.25,
                  color: d.type.iconColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _miniLabel('ZONE'),
        Text(
          d.zoneTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            height: 1.3,
            color: AdminColors.headerTitle,
          ),
        ),
      ],
    );
  }

  Widget _sum2(AdminAlertDetailsData d, Color sev) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: sev.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sev.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 16, color: sev),
              const SizedBox(width: 6),
              Text(d.severity.label, style: TextStyle(color: sev, fontWeight: FontWeight.w900, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.statRed.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.whyHighTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AdminColors.headerTitle)),
              const SizedBox(height: 6),
              Text(d.whyHighDescription, style: TextStyle(fontSize: 12, height: 1.35, color: AdminColors.muted.withValues(alpha: 0.92))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sum3((Color, Color) st) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _miniLabel('STATUS'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: st.$2, borderRadius: BorderRadius.circular(20)),
          child: Text(_status.label, style: TextStyle(color: st.$1, fontWeight: FontWeight.w900, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _sum4(AdminAlertDetailsData d) {
    final p = d.confidencePercent / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _miniLabel('CONFIDENCE'),
        Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: p,
                      strokeWidth: 5,
                      backgroundColor: AdminColors.statBlue.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(AdminColors.statBlue),
                    ),
                  ),
                  Text(
                    '${d.confidencePercent}%',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, height: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'High Confidence',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      height: 1.2,
                      color: AdminColors.statRed,
                    ),
                  ),
                  Text(d.confidenceBlurb, style: TextStyle(fontSize: 11, color: AdminColors.muted.withValues(alpha: 0.9), height: 1.3)),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AdminColors.statBlue,
                    ),
                    child: const Text('Learn more about confidence', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sum5(AdminAlertDetailsData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _miniLabel('DETECTED ON'),
        Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 16, color: AdminColors.statBlue),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                d.detectedOn,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.25,
                  color: AdminColors.statRed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _miniLabel('ALERTED ON'),
        Row(
          children: [
            const Icon(Icons.notifications_active_outlined, size: 16, color: AdminColors.statBlue),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                d.alertedOn,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.25,
                  color: AdminColors.statRed,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _miniLabel(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        t,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AdminColors.muted.withValues(alpha: 0.75)),
      ),
    );
  }

  Widget _alertInfoCard(AdminAlertDetailsData d) {
    return _titledCard(
      'Alert Information',
      Icons.info_outline_rounded,
      [
        _kv('Site / Area', d.siteArea),
        _kv('Depth', '${d.depthM} meters'),
        _kv('Observer', d.observer),
        _kv('Detection Method', d.detectionMethod),
        _kv('Water Visibility', d.waterVisibility),
        _kv('Remarks', d.remarks),
      ],
    );
  }

  Widget _alertMessageCard(AdminAlertDetailsData d) {
    return _titledCard(
      'Alert Message',
      Icons.chat_bubble_outline_rounded,
      [
        Text(d.messageHeading, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.headerTitle)),
        const SizedBox(height: 6),
        Text('${d.cotsCount} COTS detected', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AdminColors.statGreen)),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyan.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What does this mean?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 6),
              Text(d.whatDoesThisMean, style: TextStyle(fontSize: 12.5, height: 1.4, color: AdminColors.headerTitle.withValues(alpha: 0.9))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _kv('Density', '${d.density.toStringAsFixed(1)} /100 m²'),
        _kv('Threshold', '${d.threshold.toStringAsFixed(0)} /100 m²'),
        _kv('Risk Level', d.riskLevel, valueColor: AdminColors.statRed),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.statRed.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recommended Intervention', style: TextStyle(fontWeight: FontWeight.w900, color: AdminColors.statRed, fontSize: 13)),
              const SizedBox(height: 6),
              Text(d.actionRecommended, style: TextStyle(fontSize: 12.5, height: 1.35, color: AdminColors.headerTitle.withValues(alpha: 0.9))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _confidenceDetailsCard(AdminAlertDetailsData d) {
    return _titledCard(
      'Confidence Details',
      Icons.analytics_outlined,
      [
        Text('${d.confidencePercent}% (High Confidence)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 12),
        _kv('Image Quality', d.imageQuality),
        _kv('Visibility Index', d.visibilityIndex),
        _kv('Detection Clarity', d.detectionClarity),
        _kv('Algorithm Model', d.algorithmModel),
        const SizedBox(height: 10),
        Text(d.confidenceLongDescription, style: TextStyle(fontSize: 12.5, height: 1.4, color: AdminColors.muted.withValues(alpha: 0.92))),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AdminColors.statBlue,
          ),
          child: const Text('Learn more about confidence levels', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _evidenceCard(AdminAlertDetailsData d) {
    return _titledCard(
      'Evidence Image',
      Icons.image_outlined,
      [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.network(
              d.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, p) {
                if (p == null) return child;
                return Container(color: const Color(0xFFE8EEF5), child: const Center(child: CircularProgressIndicator()));
              },
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFE8EEF5),
                alignment: Alignment.center,
                child: const Icon(Icons.photo_outlined, size: 48),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(d.imageCaption, style: TextStyle(fontSize: 12, color: AdminColors.muted.withValues(alpha: 0.9))),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openFullImage,
          icon: const Icon(Icons.open_in_full_rounded, size: 18),
          label: const Text('View Full Image'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminColors.statBlue,
            side: BorderSide(color: AdminColors.statBlue.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _locationCard(AdminAlertDetailsData d) {
    final center = LatLng(d.latitude, d.longitude);
    return _titledCard(
      'Location',
      Icons.map_outlined,
      [
        _kv('Latitude', '${d.latitude.toStringAsFixed(6)}° N'),
        _kv('Longitude', '${d.longitude.toStringAsFixed(6)}° E'),
        _kv('Zone', d.zoneTitle.split('—').first.trim()),
        _kv('Site / Area', d.siteArea),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 11,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'cots_monitor',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: center,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: AdminColors.statRed, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Column(
                    children: [
                      _zoomBtn(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                      const SizedBox(height: 6),
                      _zoomBtn(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _zoomBtn(IconData i, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 36, height: 36, child: Icon(i, size: 20)),
      ),
    );
  }

  Widget _notesCard(AdminAlertDetailsData d) {
    return _titledCard(
      'Notes',
      Icons.sticky_note_2_outlined,
      [
        Text(d.notes, style: TextStyle(fontSize: 14, height: 1.45, color: AdminColors.headerTitle.withValues(alpha: 0.9))),
      ],
    );
  }

  Widget _kv(String k, String v, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.85))),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AdminColors.headerTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titledCard(String title, IconData icon, List<Widget> children) {
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AdminColors.statBlue),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminColors.headerTitle)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _actionRow() {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionBtn(
          label: 'Mark as In Progress',
          icon: Icons.play_circle_outline_rounded,
          fg: AdminColors.statBlue,
          onPressed: _status == AdminAlertStatus.inProgress || _status == AdminAlertStatus.resolved ? null : _onMarkInProgress,
        ),
        _ActionBtn(
          label: 'Mark as Resolved',
          icon: Icons.check_circle_outline_rounded,
          fg: AdminColors.statGreen,
          onPressed: _status == AdminAlertStatus.resolved ? null : _onMarkResolved,
        ),
        _ActionBtn(
          label: 'Close Alert',
          icon: Icons.close_rounded,
          fg: AdminColors.statRed,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({required this.label, required this.icon, required this.fg, required this.onPressed});
  final String label;
  final IconData icon;
  final Color fg;
  final VoidCallback? onPressed;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.45,
        child: OutlinedButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: 18),
          label: Text(widget.label),
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.fg,
            side: BorderSide(color: widget.fg.withValues(alpha: enabled && _hover ? 0.75 : 0.45)),
            backgroundColor: enabled && _hover ? widget.fg.withValues(alpha: 0.06) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
