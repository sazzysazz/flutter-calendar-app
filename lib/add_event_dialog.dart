import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/holiday.dart';

class AddEventDialog extends StatefulWidget {
  final DateTime selectedDay;
  final Holiday? existingEvent;

  const AddEventDialog({
    super.key,
    required this.selectedDay,
    this.existingEvent,
  });

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;

  TimeOfDay? _pickedTime;
  bool _isAllDay = false;
  late int _selectedColor;
  late DateTime _startDate;
  late DateTime? _endDate;

  // ✅ NEW: reminder option
  late int _reminderOption; // 0 none, 1 tenMin, 2 oneHour, 3 oneDay

  final List<int> _colorPalette = [
    0xFFEF5350,
    0xFFEC407A,
    0xFFAB47BC,
    0xFF7E57C2,
    0xFF5C6BC0,
    0xFF42A5F5,
    0xFF29B6F6,
    0xFF26C6DA,
    0xFF26A69A,
    0xFF66BB6A,
    0xFF9CCC65,
    0xFFD4E157,
    0xFFFFEE58,
    0xFFFFCA28,
    0xFFFF7043,
    0xFF8D6E63,
  ];

  @override
  void initState() {
    super.initState();

    final existing = widget.existingEvent;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descController = TextEditingController(text: existing?.description ?? '');
    _pickedTime = existing?.time;
    _selectedColor = existing?.colorCode ?? 0xFF2196F3;

    // If existing event has no time → treat as all-day
    _isAllDay = existing?.time == null;

    _startDate = existing?.startDate ?? widget.selectedDay;
    _endDate = existing?.endDate;

    // ✅ NEW: load reminder when editing
    _reminderOption = existing?.reminderOption ?? 0;

    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existingEvent != null;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      elevation: 12,
      title: Text(
        isEditing ? 'Edit Event' : 'Add New Event',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Start Date
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text(
                    'Start Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_startDate),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                        if (_endDate != null && _endDate!.isBefore(picked)) {
                          _endDate = picked;
                        }
                      });
                    }
                  },
                ),

                // Multi-day toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Multi-day event'),
                  subtitle: const Text('Event spans multiple days'),
                  value: _endDate != null,
                  onChanged: (value) {
                    setState(() {
                      _endDate = value ? _startDate : null;
                    });
                  },
                ),

                // End Date (if multi-day)
                if (_endDate != null) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text(
                      'End Date',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_endDate!),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate!,
                        firstDate: _startDate,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                  ),
                ],

                const Divider(height: 32),

                // Event Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Event Name *',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.trim().isEmpty ?? true
                      ? 'Event name is required'
                      : null,
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // All-day toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All-day event'),
                  value: _isAllDay,
                  onChanged: (value) {
                    setState(() {
                      _isAllDay = value;
                      if (value) {
                        _pickedTime = null; // Clear time when all-day
                      }
                    });
                  },
                ),

                // Time picker — only visible if NOT all-day
                if (!_isAllDay) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _pickedTime == null
                            ? const Text(
                                'No time set',
                                style: TextStyle(color: Colors.grey),
                              )
                            : Chip(
                                label: Text(_pickedTime!.format(context)),
                                deleteIcon: const Icon(Icons.clear, size: 18),
                                onDeleted: () =>
                                    setState(() => _pickedTime = null),
                              ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _pickedTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() => _pickedTime = time);
                          }
                        },
                        icon: const Icon(Icons.schedule),
                        label: const Text('Pick Time'),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // ✅ NEW: Reminder dropdown (uses 8:00 AM for all-day reminders)
                DropdownButtonFormField<int>(
                  value: _reminderOption,
                  decoration: const InputDecoration(
                    labelText: 'Reminder',
                    prefixIcon: Icon(Icons.notifications),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('None')),
                    DropdownMenuItem(value: 1, child: Text('10 minutes before')),
                    DropdownMenuItem(value: 2, child: Text('1 hour before')),
                    DropdownMenuItem(value: 3, child: Text('1 day before')),
                  ],
                  onChanged: (v) => setState(() => _reminderOption = v ?? 0),
                ),

                const SizedBox(height: 24),

                // Color picker
                const Text(
                  'Event Color',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: _colorPalette.map((color) {
                    final isSelected = color == _selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.transparent,
                            width: isSelected ? 4 : 0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 28,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _canSave
              ? () {
                  if (_formKey.currentState!.validate()) {
                    final event = Holiday(
                      name: _nameController.text.trim(),
                      startDate: _startDate,
                      endDate: _endDate,
                      type: widget.existingEvent?.type ?? 'Custom',
                      description: _descController.text.trim().isEmpty
                          ? null
                          : _descController.text.trim(),
                      time: _isAllDay ? null : _pickedTime,
                      colorCode: _selectedColor,

                      // ✅ NEW
                      reminderOption: _reminderOption,

                      // ✅ keep existing notification id (for edit reschedule)
                      notificationId: widget.existingEvent?.notificationId,
                    );

                    Navigator.pop(context, event);
                  }
                }
              : null,
          icon: Icon(isEditing ? Icons.save : Icons.add, size: 20),
          label: Text(isEditing ? 'Save Changes' : 'Add Event'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _canSave ? Color(_selectedColor) : null,
            foregroundColor: _canSave ? Colors.white : null,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
          ),
        ),
      ],
    );
  }
}
