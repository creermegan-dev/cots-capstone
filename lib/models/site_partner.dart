/// Stage 10: site partners (2 main Divers per site).
///
/// Main Diver 1 is the first Diver to record COTS at a site. The site partner
/// is Main Diver 2: a Diver invited by Main Diver 1 (who accepted), or a Diver
/// who recorded at the site, approved by the Expert.

/// A site with its main Divers, as the signed-in person may see it.
class SiteTeam {
  const SiteTeam({
    required this.areaCode,
    required this.areaName,
    required this.mainDiverUid,
    required this.mainDiverName,
    this.partnerUid,
    this.partnerName,
    this.canInvite = false,
    this.canLeave = false,
  });

  factory SiteTeam.fromJson(Map<String, dynamic> json) => SiteTeam(
        areaCode: json['area_code']?.toString() ?? '',
        areaName: json['area_name']?.toString() ?? '',
        mainDiverUid: json['main_diver_uid']?.toString() ?? '',
        mainDiverName: json['main_diver_name']?.toString() ?? '',
        partnerUid: json['partner_uid']?.toString(),
        partnerName: json['partner_name']?.toString(),
        canInvite: json['can_invite'] == true,
        canLeave: json['can_leave'] == true,
      );

  final String areaCode;
  final String areaName;
  final String mainDiverUid;
  final String mainDiverName;
  final String? partnerUid;
  final String? partnerName;

  /// True for Main Diver 1 while the site partner place is empty.
  final bool canInvite;

  /// Stage 11: true for the site partner ("Leave site").
  final bool canLeave;

  /// e.g. "Maria Santos, Juan Dela Cruz (site partner)".
  String get mainDiversText => partnerName == null
      ? mainDiverName
      : '$mainDiverName, $partnerName (site partner)';
}

/// One request to become a site's partner.
class SitePartnerRequest {
  const SitePartnerRequest({
    required this.id,
    required this.areaCode,
    required this.areaName,
    required this.candidateUid,
    required this.candidateName,
    required this.source,
    required this.status,
    this.invitedByName,
    this.mainDiverName = '',
    this.createdAt,
    this.queuedAt,
    this.canRespond = false,
    this.canDecide = false,
  });

  factory SitePartnerRequest.fromJson(Map<String, dynamic> json) =>
      SitePartnerRequest(
        id: json['id']?.toString() ?? '',
        areaCode: json['area_code']?.toString() ?? '',
        areaName: json['area_name']?.toString() ?? '',
        candidateUid: json['candidate_uid']?.toString() ?? '',
        candidateName: json['candidate_name']?.toString() ?? '',
        source: json['source']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        invitedByName: json['invited_by_name']?.toString(),
        mainDiverName: json['main_diver_name']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        queuedAt: DateTime.tryParse(json['queued_at']?.toString() ?? ''),
        canRespond: json['can_respond'] == true,
        canDecide: json['can_decide'] == true,
      );

  final String id;
  final String areaCode;
  final String areaName;
  final String candidateUid;
  final String candidateName;

  /// 'invited' (by Main Diver 1) or 'recorded' (recorded COTS at the site).
  final String source;

  /// invited, invite_declined, waiting_expert, approved, declined or closed.
  final String status;
  final String? invitedByName;
  final String mainDiverName;
  final DateTime? createdAt;

  /// When the request reached the Expert (the order the Expert sees).
  final DateTime? queuedAt;

  /// The invited Diver can accept or decline.
  final bool canRespond;

  /// The Expert can approve or decline.
  final bool canDecide;

  bool get wasInvited => source == 'invited';

  String get statusLabel => switch (status) {
        'invited' => 'Waiting for $candidateName to accept',
        'invite_declined' => '$candidateName declined the invitation',
        'waiting_expert' => 'Waiting for the Expert',
        'approved' => '$candidateName is the site partner',
        'declined' => 'Not approved by the Expert',
        'closed' => 'Closed: the place was already filled',
        _ => status,
      };

  /// Why this Diver is a candidate, for the Expert.
  String get reasonText => wasInvited
      ? 'invited by ${invitedByName ?? mainDiverName}, and accepted'
      : 'recorded COTS at this site';
}
