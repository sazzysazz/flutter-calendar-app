import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/holiday.dart';

class AddEventDialog extends StatefulWidget {
  final DateTime selectedDay;
  final Holiday? existingEvent; // null = add new, not null = edit

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

  final List<int> _colorPalette = [
    0xFFEF5350, 0xFFEC407A, 0xFFAB47BC, 0xFF7E57C2,
    0xFF5C6BC0, 0xFF42A5F5, 0xFF29B6F6, 0xFF26C6DA,
    0xFF26A69A, 0xFF66BB6A, 0xFF9CCC65, 0xFFD4E157,
    0xFFFFEE58, 0xFFFFCA28, 0xFFFF7043, 0xFF8D6E63,
  ];

  @override
  void initState() {
    super.initState();

    // Pre-fill fields when editing
    _nameController = TextEditingController(text: widget.existingEvent?.name ?? '');
    _descController = TextEditingController(text: widget.existingEvent?.description ?? '');
    _pickedTime = widget.existingEvent?.time;
    _selectedColor = widget.existingEvent?.colorCode ?? 0xFF2196F3;

    // If no time is set → treat as all-day
    _isAllDay = widget.existingEvent?.time == null;

    // Update button state when typing
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existingEvent != null;
    final DateTime displayDate = isEditing ? widget.existingEvent!.date : widget.selectedDay;
    final bool canSave = _nameController.text.trim().isNotEmpty;
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
                // Selected date display
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(displayDate),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 24),

                // Event Name (required)
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Event Name *',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty ?? true ? 'Event name is required' : null,
                ),
                const SizedBox(height: 16),

                // Description (optional)
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
                      if (value) _pickedTime = null;
                    });
                  },
                ),

                // Time picker — only shown when not all-day
                if (!_isAllDay) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _pickedTime == null
                            ? const Text('No time set', style: TextStyle(color: Colors.grey))
                            : Chip(
                                label: Text(_pickedTime!.format(context)),
                                deleteIcon: const Icon(Icons.clear, size: 18),
                                onDeleted: () => setState(() => _pickedTime = null),
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

                const SizedBox(height: 24),

                // Color picker
                const Text('Event Color', style: TextStyle(fontWeight: FontWeight.w600)),
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
                              ? const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 28)
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
          onPressed: canSave
              ? () {
                  if (_formKey.currentState!.validate()) {
                    final event = Holiday(
                      id: widget.existingEvent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _nameController.text.trim(),
                      date: displayDate,
                      type: widget.existingEvent?.type ?? 'Custom',
                      description: _descController.text.trim().isEmpty
                          ? null
                          : _descController.text.trim(),
                      time: _isAllDay ? null : _pickedTime,
                      colorCode: _selectedColor,
                    );
                    Navigator.pop(context, event); // Return created/updated event
                  }
                }
              : null,
          icon: Icon(isEditing ? Icons.save : Icons.add, size: 20),
          label: Text(isEditing ? 'Save Changes' : 'Add Event'),
          style: ElevatedButton.styleFrom(
            backgroundColor: canSave ? Color(_selectedColor) : null,
            foregroundColor: canSave ? Colors.white : null,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 6,
          ),
        ),
      ],
    );
  }
}