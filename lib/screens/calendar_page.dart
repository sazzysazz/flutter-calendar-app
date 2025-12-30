import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/holiday.dart';
import '../services/holiday_service.dart';
import '../services/event_database.dart';
import '../widgets/add_event_dialog.dart';

// No need to redefine the extension here — it's already in holiday.dart
// extension DateTimeExtension on DateTime { ... } ← REMOVED

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Holiday> _allEvents = [];
  List<Holiday> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchListener);
    loadHolidays();
  }

  void _onSearchListener() {
    _onSearchChanged(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchListener);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadHolidays() async {
    final publicHolidays = await HolidayService.fetchHolidays();
    final customEvents = EventDatabase.getAllEvents();

    final allEvents = <Holiday>[...publicHolidays, ...customEvents];

    if (mounted) {
      setState(() {
        _allEvents = allEvents;
      });
      _onSearchChanged(_searchController.text);
    }
  }

  // Returns all events that cover the given day (supports multi-day events)
  List<Holiday> getEventsForDay(DateTime day) {
    final d = day.stripTime(); // Uses extension from holiday.dart
    return _allEvents.where((event) => event.coversDay(d)).toList();
  }

  void _addEvent() async {
    final newEvent = await showDialog<Holiday>(
      context: context,
      builder: (_) => AddEventDialog(selectedDay: _selectedDay),
    );
    if (newEvent != null) {
      await EventDatabase.saveEvent(newEvent);
      await loadHolidays();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _searchResults = [];
      } else {
        _searchResults = _allEvents
            .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _editEvent(Holiday oldEvent) async {
    final updatedEvent = await showDialog<Holiday>(
      context: context,
      builder: (_) => AddEventDialog(
        selectedDay: oldEvent.startDate,
        existingEvent: oldEvent,
      ),
    );

    if (updatedEvent != null) {
      oldEvent.updateEvent(
        name: updatedEvent.name,
        description: updatedEvent.description,
        time: updatedEvent.time,
        colorCode: updatedEvent.colorCode,
        startDate: updatedEvent.startDate,
        endDate: updatedEvent.endDate,
      );
      await oldEvent.save();
      await loadHolidays();
    }
  }

  void _deleteEvent(Holiday event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event?'),
        content: Text('Are you sure you want to delete "${event.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await EventDatabase.deleteEvent(event);
              await loadHolidays();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = isDark ? Colors.grey[900]! : Colors.white;
    final scaffoldColor = isDark ? Colors.black : Colors.grey[50];

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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Text(
              'Calendar',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[500]),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),
            ),
          ),

          // Search Results Panel
          if (_searchResults.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
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
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final event = _searchResults[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              ),
            ),

          // Calendar
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: _searchResults.isNotEmpty ? 0 : 8,
              ),
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
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
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
                    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    todayDecoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                    todayTextStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                    selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                            final color = Color(holiday.colorCode);
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: holiday.endDate != null
                                    ? Border.all(color: Colors.white, width: 1.5)
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
          ),

          // Selected day header (only when not searching)
          if (_searchResults.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(_selectedDay),
                          style: TextStyle(fontSize: 14, color: primaryColor, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMMM d, yyyy').format(_selectedDay),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Events list or empty state (only when not searching)
          if (_searchResults.isEmpty)
            () {
              final eventsToday = getEventsForDay(_selectedDay);
              if (eventsToday.isNotEmpty) {
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = eventsToday[index];
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          index == 0 ? 0 : 8,
                          24,
                          index == eventsToday.length - 1 ? 24 : 8,
                        ),
                        child: _EventCard(
                          event: event,
                          onEdit: () => _editEvent(event),
                          onDelete: () => _deleteEvent(event),
                        ),
                      );
                    },
                    childCount: eventsToday.length,
                  ),
                );
              } else {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No events today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        SizedBox(height: 8),
                        Text('Tap + to add an event'),
                      ],
                    ),
                  ),
                );
              }
            }(),
        ],
      ),
    );
  }
}

// ==================== Event UI Widgets (Updated for Multi-Day) ====================

class _EventCard extends StatelessWidget {
  final Holiday event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({required this.event, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = Color(event.colorCode);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _EventDetailsSheet(event: event, onEdit: onEdit, onDelete: onDelete),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))
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
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(_getEventIcon(event.type), color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              event.time != null ? event.time!.format(context) : 'All day',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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

  const _EventDetailsSheet({required this.event, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = Color(event.colorCode);

    String dateDisplay;
    if (event.endDate == null) {
      dateDisplay = DateFormat('EEEE, MMMM d, yyyy').format(event.startDate);
    } else if (event.startDate.stripTime() == event.endDate!.stripTime()) {
      dateDisplay = DateFormat('EEEE, MMMM d, yyyy').format(event.startDate);
    } else {
      dateDisplay = '${DateFormat('MMM d').format(event.startDate)} – ${DateFormat('MMM d, yyyy').format(event.endDate!)}';
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                  child: Icon(_getEventIcon(event.type), color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(event.type, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
                _DetailRow(icon: Icons.calendar_today, title: 'Date', value: dateDisplay),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.access_time,
                  title: 'Time',
                  value: event.time != null ? event.time!.format(context) : 'All day',
                ),
                if (event.description != null) ...[
                  const SizedBox(height: 16),
                  _DetailRow(icon: Icons.description, title: 'Description', value: event.description!),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  const _DetailRow({required this.icon, required this.title, required this.value});

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
              Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}