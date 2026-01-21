import 'package:calendar_app/add_event_dialog.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../models/holiday.dart';
import '../services/holiday_service.dart';
import '../services/event_database.dart';
import '../services/notification_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<Holiday> _publicHolidays = [];
  List<Holiday> _allEvents = [];
  List<Holiday> _searchResults = [];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(); // ✅ NEW
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchListener);
    loadHolidays(refreshPublic: true);
  }

  void _onSearchListener() => _onSearchChanged(_searchController.text);

  @override
  void dispose() {
    _searchController.removeListener(_onSearchListener);
    _searchController.dispose();
    _searchFocusNode.dispose(); // ✅ NEW
    super.dispose();
  }

  ReminderOption _mapReminder(int v) {
    switch (v) {
      case 1:
        return ReminderOption.tenMinutes;
      case 2:
        return ReminderOption.oneHour;
      case 3:
        return ReminderOption.oneDay;
      default:
        return ReminderOption.none;
    }
  }

  Future<void> loadHolidays({bool refreshPublic = false}) async {
    try {
      if (refreshPublic || _publicHolidays.isEmpty) {
        _publicHolidays = await HolidayService.fetchHolidays();
      }
    } catch (_) {
      // API fail -> still load Hive events
    }

    final customEvents = EventDatabase.getAllEvents();
    final allEvents = <Holiday>[..._publicHolidays, ...customEvents];

    if (!mounted) return;
    setState(() {
      _allEvents = allEvents;
      _loading = false;
    });

    _onSearchChanged(_searchController.text);
  }

  List<Holiday> getEventsForDay(DateTime day) {
    final d = day.stripTime();
    return _allEvents.where((event) => event.coversDay(d)).toList();
  }

  Future<void> _scheduleReminderForEvent(Holiday e) async {
    final notifId = await NotificationService.instance.scheduleEventReminder(
      title: e.name,
      body: e.description,
      startDate: e.startDate,
      endDate: e.endDate,
      hour: e.hour,
      minute: e.minute,
      reminder: _mapReminder(e.safeReminderOption),
      existingNotificationId: e.notificationId,
      allDayHour: 8,
      allDayMinute: 0,
    );

    e.notificationId = notifId;
    await e.save();
  }

  void _addEvent() async {
    final newEvent = await showDialog<Holiday>(
      context: context,
      builder: (_) => AddEventDialog(selectedDay: _selectedDay),
    );

    if (newEvent == null) return;

    await EventDatabase.saveEvent(newEvent);

    if (!mounted) return;
    setState(() {
      _selectedDay = newEvent.startDate.stripTime();
      _focusedDay = _selectedDay;
    });

    await loadHolidays(refreshPublic: false);

    try {
      await _scheduleReminderForEvent(newEvent);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder failed: $e')),
      );
    }
  }

  void _editEvent(Holiday oldEvent) async {
    final updatedEvent = await showDialog<Holiday>(
      context: context,
      builder: (_) => AddEventDialog(
        selectedDay: oldEvent.startDate,
        existingEvent: oldEvent,
      ),
    );

    if (updatedEvent == null) return;

    final oldNotifId = oldEvent.notificationId;

    oldEvent.updateEvent(
      name: updatedEvent.name,
      description: updatedEvent.description,
      time: updatedEvent.time,
      colorCode: updatedEvent.safeColorCode,
      startDate: updatedEvent.startDate,
      endDate: updatedEvent.endDate,
      reminderOption: updatedEvent.safeReminderOption,
    );

    oldEvent.notificationId = oldNotifId;
    await oldEvent.save();

    if (!mounted) return;
    setState(() {
      _selectedDay = oldEvent.startDate.stripTime();
      _focusedDay = _selectedDay;
    });

    await loadHolidays(refreshPublic: false);

    try {
      await _scheduleReminderForEvent(oldEvent);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder update failed: $e')),
      );
    }
  }

  void _deleteEvent(Holiday event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event?'),
        content: Text(
          'Are you sure you want to delete "${event.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              if (event.notificationId != null) {
                await NotificationService.instance.cancel(event.notificationId!);
              }

              await EventDatabase.deleteEvent(event);
              await loadHolidays(refreshPublic: false);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Event deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        _searchResults = [];
      } else {
        _searchResults =
            _allEvents.where((e) => e.name.toLowerCase().contains(q)).toList();
      }
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _onSearchChanged('');

    // ✅ remove cursor + hide keyboard
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ✅ FULL-SCREEN Search Results overlay
  Widget _searchOverlay({
    required Color surfaceColor,
    required Color primaryColor,
    required Color scaffoldColor,
  }) {
    return Material(
      color: scaffoldColor, // full background
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _closeSearch,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _searchResults.isEmpty
                ? const Center(
                    child: Text(
                      'No results',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final event = _searchResults[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _EventCard(
                          event: event,
                          onEdit: () => _editEvent(event),
                          onDelete: () => _deleteEvent(event),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = isDark ? Colors.grey[900]! : Colors.white;
    final scaffoldColor = isDark ? Colors.black : Colors.grey[50]!;

    if (_loading) {
      return Scaffold(
        backgroundColor: scaffoldColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final eventsToday = getEventsForDay(_selectedDay);

    // ✅ show panel when typing (full screen), not only when results exist
    final showSearchPanel = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: scaffoldColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _addEvent,
        elevation: 12,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // ✅ tap anywhere to remove cursor
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: SafeArea(
          child: Column(
            children: [
              // ---------- Title ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Calendar',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // ---------- Search Bar (Fixed) ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode, // ✅ NEW
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[500]),
                              onPressed: _closeSearch,
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),

              // ✅ Area under search bar
              Expanded(
                child: Stack(
                  children: [
                    // ----- Main content under overlay -----
                    Column(
                      children: [
                        // ---------- Calendar ----------
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: Container(
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: TableCalendar(
                              key: ValueKey(_allEvents.length),
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2030, 12, 31),
                              focusedDay: _focusedDay,
                              selectedDayPredicate: (day) =>
                                  isSameDay(day, _selectedDay),
                              onDaySelected: (selected, focused) {
                                setState(() {
                                  _selectedDay = selected;
                                  _focusedDay = focused;
                                });
                              },
                              eventLoader: getEventsForDay,
                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                                titleTextStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              calendarStyle: CalendarStyle(
                                outsideDaysVisible: false,
                                todayDecoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                selectedDecoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                todayTextStyle: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                selectedTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (context, date, events) {
                                  if (events.isEmpty) return null;
                                  return Positioned(
                                    bottom: 6,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: events.take(4).map((e) {
                                        final Holiday holiday = e as Holiday;
                                        final color =
                                            Color(holiday.safeColorCode);
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 1.5),
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: holiday.endDate != null
                                                ? Border.all(
                                                    color: Colors.white,
                                                    width: 1.5)
                                                : null,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // ---------- Date header ----------
                        if (!showSearchPanel)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('EEEE').format(_selectedDay),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('MMMM d, yyyy')
                                          .format(_selectedDay),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                        // ---------- Events list ----------
                        Expanded(
                          child: showSearchPanel
                              ? const SizedBox()
                              : (eventsToday.isEmpty
                                  ? ListView(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 16),
                                      children: const [
                                        SizedBox(height: 40),
                                        Center(
                                          child: Column(
                                            children: [
                                              Icon(
                                                Icons.event_note_outlined,
                                                size: 64,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(height: 16),
                                              Text(
                                                'No events today',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text('Tap + to add an event'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 16),
                                      itemCount: eventsToday.length,
                                      itemBuilder: (context, index) {
                                        final event = eventsToday[index];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: _EventCard(
                                            event: event,
                                            onEdit: () => _editEvent(event),
                                            onDelete: () => _deleteEvent(event),
                                          ),
                                        );
                                      },
                                    )),
                        ),
                      ],
                    ),

                    // ✅ ONE overlay only (full screen)
                    if (showSearchPanel)
                      Positioned.fill(
                        child: _searchOverlay(
                          surfaceColor: surfaceColor,
                          primaryColor: primaryColor,
                          scaffoldColor: scaffoldColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Event UI Widgets ====================

class _EventCard extends StatelessWidget {
  final Holiday event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = Color(event.safeColorCode);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _EventDetailsSheet(
            event: event,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getEventIcon(event.type),
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.time != null
                                  ? event.time!.format(context)
                                  : 'All day',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'public':
      case 'holiday':
        return Icons.beach_access;
      case 'birthday':
        return Icons.cake;
      case 'meeting':
        return Icons.groups;
      case 'personal':
        return Icons.person;
      default:
        return Icons.event;
    }
  }
}

class _EventDetailsSheet extends StatelessWidget {
  final Holiday event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventDetailsSheet({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Color(event.safeColorCode);

    String dateDisplay;
    if (event.endDate == null) {
      dateDisplay = DateFormat('EEEE, MMMM d, yyyy').format(event.startDate);
    } else if (event.startDate.stripTime() == event.endDate!.stripTime()) {
      dateDisplay = DateFormat('EEEE, MMMM d, yyyy').format(event.startDate);
    } else {
      dateDisplay =
          '${DateFormat('MMM d').format(event.startDate)} – ${DateFormat('MMM d, yyyy').format(event.endDate!)}';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getEventIcon(event.type),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.type,
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.calendar_today,
                  title: 'Date',
                  value: dateDisplay,
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.access_time,
                  title: 'Time',
                  value: event.time != null
                      ? event.time!.format(context)
                      : 'All day',
                ),
                if (event.description != null) ...[
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.description,
                    title: 'Description',
                    value: event.description!,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'public':
      case 'holiday':
        return Icons.beach_access;
      case 'birthday':
        return Icons.cake;
      case 'meeting':
        return Icons.groups;
      case 'personal':
        return Icons.person;
      default:
        return Icons.event;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[500], size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
