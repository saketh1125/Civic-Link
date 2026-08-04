/// Commute Create Screen
///
/// Form for creating a new commute offer (driver).
/// Redesigned with FormTile, SectionHeader, and GlassCard grouping —
/// collapsing the 5x duplicated tile pattern.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';
import '../../providers/commute_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/error_banner.dart';
import '../widgets/form_tile.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/neon_button.dart';
import '../widgets/section_header.dart';

class CommuteCreateScreen extends ConsumerStatefulWidget {
  const CommuteCreateScreen({super.key});

  @override
  ConsumerState<CommuteCreateScreen> createState() =>
      _CommuteCreateScreenState();
}

class _CommuteCreateScreenState extends ConsumerState<CommuteCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _availableSeats = 1;
  bool _isWomenOnly = false;
  bool _isRecurring = false;

  // Resolved coordinates
  double? _originLat;
  double? _originLon;
  double? _destLat;
  double? _destLon;
  bool _isGeocodingOrigin = false;
  bool _isGeocodingDest = false;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _geocodeOrigin() async {
    final address = _originController.text.trim();
    if (address.isEmpty) return;
    setState(() => _isGeocodingOrigin = true);
    final coords =
        await ref.read(commuteProvider.notifier).geocodeAddress(address);
    if (mounted) {
      setState(() {
        _isGeocodingOrigin = false;
        if (coords != null) {
          _originLat = coords[0];
          _originLon = coords[1];
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find origin location')),
          );
        }
      });
    }
  }

  Future<void> _geocodeDest() async {
    final address = _destinationController.text.trim();
    if (address.isEmpty) return;
    setState(() => _isGeocodingDest = true);
    final coords =
        await ref.read(commuteProvider.notifier).geocodeAddress(address);
    if (mounted) {
      setState(() {
        _isGeocodingDest = false;
        if (coords != null) {
          _destLat = coords[0];
          _destLon = coords[1];
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not find destination location')),
          );
        }
      });
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_originLat == null) await _geocodeOrigin();
    if (_destLat == null) await _geocodeDest();

    if (_originLat == null || _destLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not resolve locations. Check addresses.')),
      );
      return;
    }

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00';

    final success = await ref.read(commuteProvider.notifier).createCommute(
          originAddress: _originController.text.trim(),
          destinationAddress: _destinationController.text.trim(),
          originLat: _originLat!,
          originLon: _originLon!,
          destLat: _destLat!,
          destLon: _destLon!,
          departureDate: dateStr,
          departureTime: timeStr,
          availableSeats: _availableSeats,
          totalSeats: 4,
          isWomenOnly: _isWomenOnly,
          commuteType: _isRecurring ? 'recurring' : 'one_time',
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Commute created successfully!'),
          backgroundColor: context.colors.primary,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final commuteState = ref.watch(commuteProvider);
    final scheme = context.colors;

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: commuteState.isLoading,
        message: 'Creating commute...',
        child: Scaffold(
          appBar: AppBar(
            title: const Text('OFFER A RIDE'),
            leading: const BackButton(),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- Locations ------------------------------------------------
                  const SectionHeader('Route', padding: EdgeInsets.only(top: 0, bottom: 12)),

                  // Origin
                  TextFormField(
                    controller: _originController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Origin',
                      prefixIcon:
                          const Icon(Icons.trip_origin_rounded),
                      hintText: 'e.g. KPHB Phase 3, Hyderabad',
                      suffixIcon: _isGeocodingOrigin
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              ),
                            )
                          : _originLat != null
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: scheme.primary,
                                )
                              : IconButton(
                                  icon: Icon(
                                    Icons.travel_explore_rounded,
                                    color: scheme.primary,
                                  ),
                                  onPressed: _geocodeOrigin,
                                  tooltip: 'Locate',
                                ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Origin is required'
                        : null,
                  ),
                  if (_originLat != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 12),
                      child: Text(
                        '${_originLat!.toStringAsFixed(4)}, ${_originLon!.toStringAsFixed(4)}',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: scheme.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  const Gap(AppSpacing.l),

                  // Destination
                  TextFormField(
                    controller: _destinationController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Destination',
                      prefixIcon:
                          const Icon(Icons.location_on_rounded),
                      hintText: 'e.g. Mindspace, HITEC City',
                      suffixIcon: _isGeocodingDest
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              ),
                            )
                          : _destLat != null
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: scheme.primary,
                                )
                              : IconButton(
                                  icon: Icon(
                                    Icons.travel_explore_rounded,
                                    color: scheme.primary,
                                  ),
                                  onPressed: _geocodeDest,
                                  tooltip: 'Locate',
                                ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Destination is required'
                        : null,
                  ),
                  if (_destLat != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 12),
                      child: Text(
                        '${_destLat!.toStringAsFixed(4)}, ${_destLon!.toStringAsFixed(4)}',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: scheme.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),

                  const Gap(AppSpacing.xxl),

                  // ---- Schedule ------------------------------------------------
                  const SectionHeader('Schedule', padding: EdgeInsets.only(bottom: 12)),
                  Row(
                    children: [
                      Expanded(
                        child: FormTile(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date',
                          value:
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          accentValue: true,
                          onTap: _pickDate,
                        ),
                      ),
                      const Gap(AppSpacing.m),
                      Expanded(
                        child: FormTile(
                          icon: Icons.access_time_rounded,
                          label: 'Time',
                          value: _selectedTime.format(context),
                          accentValue: true,
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),

                  const Gap(AppSpacing.xxl),

                  // ---- Preferences ----------------------------------------------
                  const SectionHeader('Ride options', padding: EdgeInsets.only(bottom: 12)),

                  // Seats stepper — custom tile with trailing stepper buttons
                  FormTile(
                    icon: Icons.airline_seat_recline_normal_rounded,
                    label: 'Available Seats',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StepperButton(
                          icon: Icons.remove_rounded,
                          enabled: _availableSeats > 1,
                          onPressed: () =>
                              setState(() => _availableSeats--),
                        ),
                        Gap(AppSpacing.s),
                        Text(
                          '$_availableSeats',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Gap(AppSpacing.s),
                        _StepperButton(
                          icon: Icons.add_rounded,
                          enabled: _availableSeats < 6,
                          onPressed: () =>
                              setState(() => _availableSeats++),
                        ),
                      ],
                    ),
                  ),
                  const Gap(AppSpacing.m),

                  // Women-only toggle
                  FormTile(
                    icon: Icons.shield_rounded,
                    label: 'Women Only',
                    trailing: Switch(
                      value: _isWomenOnly,
                      onChanged: (v) =>
                          setState(() => _isWomenOnly = v),
                      activeThumbColor: kSafetyPink,
                    ),
                  ),
                  const Gap(AppSpacing.m),

                  // Recurring toggle
                  FormTile(
                    icon: Icons.repeat_rounded,
                    label: 'Recurring',
                    trailing: Switch(
                      value: _isRecurring,
                      onChanged: (v) =>
                          setState(() => _isRecurring = v),
                    ),
                  ),

                  const Gap(AppSpacing.xxl),

                  // ---- Notes ---------------------------------------------------
                  const SectionHeader('Extras', padding: EdgeInsets.only(bottom: 12)),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                      hintText: 'Any additional info for passengers...',
                    ),
                  ),

                  // ---- Error ------------------------------------------------
                  if (commuteState.error != null) ...[
                    const Gap(AppSpacing.l),
                    ErrorBanner(message: commuteState.error!),
                  ],

                  const Gap(AppSpacing.xxl),

                  // ---- Submit --------------------------------------------------
                  NeonButton(
                    label: 'CREATE COMMUTE',
                    icon: Icons.add_road_rounded,
                    isLoading: commuteState.isLoading,
                    onPressed: _onSubmit,
                  ),
                  const Gap(AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// STEPPER BUTTON
// =============================================================================

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Material(
      color: enabled
          ? scheme.primary.withValues(alpha: 0.12)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color:
                enabled ? scheme.primary : scheme.onSurfaceVariant
                    .withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
