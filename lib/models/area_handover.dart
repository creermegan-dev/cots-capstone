/// Stage 4 (claude/agreed_workflow_decisions.md): hand over this area.
class AreaHandover {
  const AreaHandover({
    required this.id,
    required this.areaCode,
    required this.areaName,
    required this.fromDiverUid,
    required this.fromDiverName,
    required this.startedReason,
    required this.reason,
    required this.note,
    required this.status,
    this.requestedAt,
    this.offerId,
    this.offerStatus,
    this.toDiverUid,
    this.toDiverName,
    this.monthNote,
    this.canRespond = false,
    this.canCancel = false,
    this.canOffer = false,
  });

  factory AreaHandover.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key]?.toString();
      return value == null || value.isEmpty ? null : value;
    }

    return AreaHandover(
      id: json['id']?.toString() ?? '',
      areaCode: json['area_code']?.toString() ?? '',
      areaName: json['area_name']?.toString() ?? '',
      fromDiverUid: json['from_diver_uid']?.toString() ?? '',
      fromDiverName: json['from_diver_name']?.toString() ?? '',
      startedReason: json['started_reason']?.toString() ?? 'diver_request',
      reason: json['reason']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      status: json['status']?.toString() ?? 'requested',
      requestedAt: DateTime.tryParse(json['requested_at']?.toString() ?? ''),
      offerId: text('offer_id'),
      offerStatus: text('offer_status'),
      toDiverUid: text('to_diver_uid'),
      toDiverName: text('to_diver_name'),
      monthNote: text('month_note'),
      canRespond: json['can_respond'] == true,
      canCancel: json['can_cancel'] == true,
      canOffer: json['can_offer'] == true,
    );
  }

  final String id;
  final String areaCode;
  final String areaName;
  final String fromDiverUid;
  final String fromDiverName;

  /// 'diver_request' or 'missed_months' (started by the Expert).
  final String startedReason;
  final String reason;

  /// Optional handover note from the original Diver to the next one.
  final String note;

  /// 'requested', 'offered', 'accepted' or 'cancelled'.
  final String status;
  final DateTime? requestedAt;
  final String? offerId;
  final String? offerStatus;
  final String? toDiverUid;
  final String? toDiverName;

  /// The agreed note about this month, while an offer is open.
  final String? monthNote;
  final bool canRespond;
  final bool canCancel;
  final bool canOffer;

  bool get isOpen => status == 'requested' || status == 'offered';
  bool get startedByExpert => startedReason == 'missed_months';

  String get statusLabel => switch (status) {
        'requested' => offerStatus == 'declined'
            ? '${toDiverName ?? 'The Diver'} declined. The Expert will choose another Diver.'
            : 'Waiting for the Expert to choose a new Diver.',
        'offered' =>
          'Offered to ${toDiverName ?? 'a Diver'}. Waiting for their answer.',
        'accepted' => 'Handed over to ${toDiverName ?? 'a new Diver'}.',
        'cancelled' => 'Cancelled.',
        _ => status,
      };
}

/// An assigned area and its missed monthly visits in a row.
class AreaMissedMonths {
  const AreaMissedMonths({
    required this.areaCode,
    required this.areaName,
    required this.mainDiverName,
    required this.missedMonths,
    required this.openHandover,
  });

  factory AreaMissedMonths.fromJson(Map<String, dynamic> json) =>
      AreaMissedMonths(
        areaCode: json['area_code']?.toString() ?? '',
        areaName: json['area_name']?.toString() ?? '',
        mainDiverName: json['main_diver_name']?.toString() ?? '',
        missedMonths: (json['missed_months'] as num?)?.round() ?? 0,
        openHandover: json['open_handover'] == true,
      );

  /// Agreed: the Expert can start a handover after 5 missed months in a row.
  static const monthsBeforeHandover = 5;

  final String areaCode;
  final String areaName;
  final String mainDiverName;
  final int missedMonths;
  final bool openHandover;

  bool get canStartHandover =>
      missedMonths >= monthsBeforeHandover && !openHandover;
}
