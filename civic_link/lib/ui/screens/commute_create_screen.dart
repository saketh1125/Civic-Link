/// Commute Create Screen
///
/// Form for creating a new commute offer (driver).
/// Fields: origin, destination, date, time, seats, recurring, notes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../providers/commute_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_overlay.dart';

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
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: kAccentGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: kAccentGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00';

    final success = await ref.read(commuteProvider.notifier).createCommute(
          originAddress: _originController.text.trim(),
          destinationAddress: _destinationController.text.trim(),
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
        const SnackBar(
          content: Text('Commute created successfully!'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final commuteState = ref.watch(commuteProvider);

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: commuteState.isLoading,
        message: 'Creating commute...',
        child: Scaffold(
          backgroundColor: kPrimaryBlack,
          appBar: AppBar(
            backgroundColor: kPrimaryBlack,
            elevation: 0,
            title: const Text(
              'OFFER A RIDE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Origin
                  TextFormField(
                    controller: _originController,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Origin',
                      prefixIcon:
                          const Icon(Icons.location_on, color: kHintGrey),
                      hintText: 'e.g. KPHB Phase 3, Hyderabad',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Origin is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Destination
                  TextFormField(
                    controller: _destinationController,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Destination',
                      prefixIcon:
                          const Icon(Icons.location_on, color: kAccentGreen),
                      hintText: 'e.g. Mindspace, HITEC City',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Destination is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Date & Time row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kInputFill,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    color: kHintGrey, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kInputFill,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time,
                                    color: kHintGrey, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedTime.format(context),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Seats stepper
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kInputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.airline_seat_recline_normal,
                                color: kHintGrey, size: 20),
                            const SizedBox(width: 12),
                            const Text(
                              'Available Seats',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 15),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _availableSeats > 1
                                  ? () =>
                                      setState(() => _availableSeats--)
                                  : null,
                              icon: Icon(Icons.remove_circle_outline,
                                  color: _availableSeats > 1
                                      ? kAccentGreen
                                      : kHintGrey),
                            ),
                            Text(
                              '$_availableSeats',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              onPressed: _availableSeats < 6
                                  ? () =>
                                      setState(() => _availableSeats++)
                                  : null,
                              icon: Icon(Icons.add_circle_outline,
                                  color: _availableSeats < 6
                                      ? kAccentGreen
                                      : kHintGrey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Women only toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kInputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield,
                                color: Colors.pinkAccent, size: 20),
                            const SizedBox(width: 12),
                            const Text(
                              'Women Only',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 15),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isWomenOnly,
                          onChanged: (v) =>
                              setState(() => _isWomenOnly = v),
                          activeColor: Colors.pinkAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recurring toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kInputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.repeat,
                                color: kAccentGreen, size: 20),
                            const SizedBox(width: 12),
                            const Text(
                              'Recurring',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 15),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isRecurring,
                          onChanged: (v) =>
                              setState(() => _isRecurring = v),
                          activeColor: kAccentGreen,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      prefixIcon:
                          const Icon(Icons.note, color: kHintGrey),
                      hintText: 'Any additional info for passengers...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error
                  if (commuteState.error != null) ...[
                    ErrorBanner(message: commuteState.error!),
                    const SizedBox(height: 16),
                  ],

                  // Submit
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: commuteState.isLoading ? null : _onSubmit,
                      child: const Text('CREATE COMMUTE'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
