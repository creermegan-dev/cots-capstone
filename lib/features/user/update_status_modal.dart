import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'cots_map_page.dart';

class UpdateStatusModal extends StatefulWidget {
  const UpdateStatusModal({super.key, required this.zone});

  final CotsZone zone;

  @override
  State<UpdateStatusModal> createState() => _UpdateStatusModalState();
}

class _UpdateStatusModalState extends State<UpdateStatusModal> {
  String _selectedStatus = 'Active';
  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTime;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _scheduledDate = DateTime(2024, 5, 20);
    _scheduledTime = const TimeOfDay(hour: 10, minute: 0);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _requiresSchedule => _selectedStatus == 'Scheduled';

  String _formatTime(BuildContext context) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      _scheduledTime,
      alwaysUse24HourFormat: false,
    );
  }

  Color _statusAccent(String status) {
    switch (status) {
      case 'Active':
        return kHigh;
      case 'Scheduled':
        return kModerate;
      case 'Cleared':
        return kLow;
      default:
        return kNavy;
    }
  }

  String _currentStatusCaption(String status) {
    switch (status) {
      case 'Active':
        return 'COTS are present in this area.';
      case 'Scheduled':
        return 'Removal planned but not yet done.';
      case 'Cleared':
        return 'No COTS detected after removal.';
      default:
        return '';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: kGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: kGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _isSaving = false);

    final sheetContext = context;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _SuccessDialog(
          zone: widget.zone,
          newStatus: _selectedStatus,
          scheduledDate:
              _requiresSchedule ? DateFormat('MMM dd, yyyy').format(_scheduledDate) : null,
          scheduledTime: _requiresSchedule ? _formatTime(sheetContext) : null,
          onDone: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentAccent = _statusAccent(widget.zone.status);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update Status',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: kNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.zone.label} (${widget.zone.id})',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'CURRENT STATUS',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: currentAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.zone.status,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _currentStatusCaption(widget.zone.status),
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),
              Text(
                'SELECT NEW STATUS',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              _StatusTile(
                label: 'Active',
                subtitle: 'COTS are present in this area.',
                color: kHigh,
                selected: _selectedStatus == 'Active',
                onTap: () => setState(() => _selectedStatus = 'Active'),
              ),
              _StatusTile(
                label: 'Scheduled',
                subtitle: 'Removal planned but not yet done.',
                color: kModerate,
                selected: _selectedStatus == 'Scheduled',
                onTap: () => setState(() => _selectedStatus = 'Scheduled'),
              ),
              _StatusTile(
                label: 'Cleared',
                subtitle: 'No COTS detected after removal.',
                color: kLow,
                selected: _selectedStatus == 'Cleared',
                onTap: () => setState(() => _selectedStatus = 'Cleared'),
              ),
              const SizedBox(height: 16),
              if (_requiresSchedule) ...[
                Text(
                  'SCHEDULED DATE & TIME (Required if status is Scheduled)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                _DateTimeTile(
                  icon: Icons.calendar_today_outlined,
                  text: DateFormat('MMM dd, yyyy').format(_scheduledDate),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 8),
                _DateTimeTile(
                  icon: Icons.access_time_outlined,
                  text: _formatTime(context),
                  onTap: _pickTime,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'NOTES (Optional)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLength: 200,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any notes here...',
                  filled: true,
                  fillColor: kGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  counterStyle: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kNavy,
                        side: const BorderSide(color: Color(0xFFCBD5E0), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? () {} : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isSaving ? Colors.grey.shade400 : kGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'SAVE CHANGES',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : kNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kGray,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kGreen, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kNavy,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({
    required this.zone,
    required this.newStatus,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.onDone,
  });

  final CotsZone zone;
  final String newStatus;
  final String? scheduledDate;
  final String? scheduledTime;
  final VoidCallback onDone;

  Color _newStatusColor() {
    switch (newStatus) {
      case 'Active':
        return kHigh;
      case 'Scheduled':
        return kModerate;
      case 'Cleared':
        return kLow;
      default:
        return kNavy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _newStatusColor();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: kLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 14),
            const Text(
              'Status Updated Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kGreen,
              ),
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.35,
                ),
                children: [
                  TextSpan(text: '${zone.name} status has been updated to '),
                  TextSpan(
                    text: newStatus,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: kGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    icon: Icons.place_outlined,
                    iconColor: Colors.grey,
                    label: 'Zone Name',
                    value: zone.name,
                    valueColor: kNavy,
                    showDivider: true,
                  ),
                  _SummaryRow(
                    icon: Icons.circle,
                    iconColor: accent,
                    label: 'New Status',
                    value: newStatus,
                    valueColor: accent,
                    showDivider: true,
                  ),
                  if (scheduledDate != null)
                    _SummaryRow(
                      icon: Icons.calendar_today_outlined,
                      iconColor: Colors.grey,
                      label: 'Scheduled Date',
                      value: scheduledDate!,
                      valueColor: kNavy,
                      showDivider: true,
                    ),
                  if (scheduledTime != null)
                    _SummaryRow(
                      icon: Icons.access_time_outlined,
                      iconColor: Colors.grey,
                      label: 'Scheduled Time',
                      value: scheduledTime!,
                      valueColor: kNavy,
                      showDivider: true,
                    ),
                  const _SummaryRow(
                    icon: Icons.person_outline,
                    iconColor: Color(0xFF9E9E9E),
                    label: 'Updated By',
                    value: 'Juan Dela Cruz',
                    valueColor: kNavy,
                    showDivider: true,
                  ),
                  _SummaryRow(
                    icon: Icons.update_outlined,
                    iconColor: Colors.grey,
                    label: 'Updated At',
                    value: DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now()),
                    valueColor: kNavy,
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'OK, GOT IT',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.showDivider,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 14, endIndent: 14),
      ],
    );
  }
}
