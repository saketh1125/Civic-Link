/// Civic-Link Design System — Match & Commute Status Tokens
///
/// Single source of truth that replaces the 3 mismatched `_getStatusColor`
/// copies previously scattered across match_card, commute_card and
/// match_detail_screen.

import 'package:flutter/material.dart';

import 'app_colors.dart';

// =============================================================================
// STATUS ENUM
// =============================================================================

/// Canonical set of match / commute lifecycle states.
enum CivicStatus {
  pending,
  confirmed,
  inProgress,
  completed,
  cancelled,
  rejected,
}

// =============================================================================
// MAPPING TABLES
// =============================================================================

/// Colour for each status (theme-aware: uses accent for positive states,
/// semantic warning/error elsewhere).
Color statusColor(CivicStatus status, ColorScheme scheme,
    {required bool isDark}) {
  switch (status) {
    case CivicStatus.pending:
      return kScoreWarning; // tactical amber/yellow
    case CivicStatus.confirmed:
      return isDark ? kBrandGreen : kBrandGreenCivic;
    case CivicStatus.inProgress:
      return isDark ? Colors.cyanAccent : Colors.blue.shade700;
    case CivicStatus.completed:
      return isDark ? Colors.lightBlueAccent : Colors.blue;
    case CivicStatus.cancelled:
      return scheme.outline;
    case CivicStatus.rejected:
      return scheme.error;
  }
}

/// Human-readable label for a status.
String statusLabel(CivicStatus status) => switch (status) {
      CivicStatus.pending => 'Pending',
      CivicStatus.confirmed => 'Confirmed',
      CivicStatus.inProgress => 'In Progress',
      CivicStatus.completed => 'Completed',
      CivicStatus.cancelled => 'Cancelled',
      CivicStatus.rejected => 'Rejected',
    };

/// Icon for each status.
IconData statusIcon(CivicStatus status) => switch (status) {
      CivicStatus.pending => Icons.schedule_rounded,
      CivicStatus.confirmed => Icons.check_circle_outline,
      CivicStatus.inProgress => Icons.route_rounded,
      CivicStatus.completed => Icons.verified_rounded,
      CivicStatus.cancelled => Icons.cancel_outlined,
      CivicStatus.rejected => Icons.block_rounded,
    };

// =============================================================================
// STRING → STATUS PARSER
// =============================================================================

/// Maps arbitrary backend status strings (case-insensitive) onto the
/// canonical enum. Unknown values fall back to [CivicStatus.pending].
CivicStatus civicStatusFromString(String raw) {
  switch (raw.toLowerCase().trim()) {
    case 'confirmed':
    case 'accepted':
    case 'active':
      return CivicStatus.confirmed;
    case 'in_progress':
    case 'inprogress':
    case 'ongoing':
      return CivicStatus.inProgress;
    case 'completed':
    case 'done':
    case 'finished':
      return CivicStatus.completed;
    case 'cancelled':
    case 'canceled':
    case 'withdrawn':
      return CivicStatus.cancelled;
    case 'rejected':
    case 'declined':
      return CivicStatus.rejected;
    case 'pending':
    default:
      return CivicStatus.pending;
  }
}
