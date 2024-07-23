import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DashAdmin extends StatefulWidget {
  const DashAdmin({Key? key}) : super(key: key);

  @override
  _DashAdminState createState() => _DashAdminState();
}

class _DashAdminState extends State<DashAdmin> {
  Map<DateTime, List<dynamic>> _acceptedBookings = {};
  String? selectedRoom;
  List<String> roomNames = [];
  DateTime _focusedDay = DateTime.now();
  String _viewMode = 'Daily';

  Future<void> fetchRooms() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('rooms').get();

      List<String> rooms = [];
      for (var doc in querySnapshot.docs) {
        String roomName = doc['room_name'];
        rooms.add(roomName);
      }

      setState(() {
        roomNames = rooms;
        selectedRoom = roomNames.isNotEmpty ? roomNames.first : null;
        if (selectedRoom != null) {
          _fetchReservationsStream(selectedRoom!).listen((event) {
            setState(() {
              _acceptedBookings = event;
            });
          });
        }
      });
    } catch (e) {
      print('Error fetching rooms: $e');
    }
  }

  Stream<Map<DateTime, List<dynamic>>> _fetchReservationsStream(String room) {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('room_name', isEqualTo: room)
        .snapshots()
        .map((snapshot) {
      Map<DateTime, List<dynamic>> acceptedBookings = {};
      for (var doc in snapshot.docs) {
        DateTime date = (doc['booking_date'] as Timestamp).toDate();
        DateTime dateOnly = DateTime(date.year, date.month, date.day);
        if (acceptedBookings.containsKey(dateOnly)) {
          acceptedBookings[dateOnly]!.add(doc.data());
        } else {
          acceptedBookings[dateOnly] = [doc.data()];
        }
      }
      return acceptedBookings;
    });
  }

  List<double> calculateOccupanciesForMonth(int year, int month) {
    List<double> occupancies =
        List<double>.filled(DateTime(year, month + 1, 0).day, 0.0);

    _acceptedBookings.forEach((date, bookings) {
      if (date.year == year && date.month == month) {
        int day = date.day;
        double occupancy = calculateOccupancy(date);
        occupancies[day - 1] = occupancy;
      }
    });

    return occupancies;
  }

  List<double> calculateOccupanciesForYear(int year) {
    List<double> occupancies = List<double>.filled(12, 0.0);

    for (int month = 1; month <= 12; month++) {
      double totalOccupancy = 0;
      int daysInMonth = DateTime(year, month + 1, 0).day;

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime date = DateTime(year, month, day);
        totalOccupancy += calculateOccupancy(date);
      }

      occupancies[month - 1] = totalOccupancy / daysInMonth;
    }

    return occupancies;
  }

  double calculateOccupancy(DateTime date) {
    DateTime dateOnly = DateTime(date.year, date.month, date.day);
    List<dynamic>? bookings = _acceptedBookings[dateOnly];

    if (bookings != null && bookings.isNotEmpty) {
      bool sesi1Accepted = false;
      bool sesi2Accepted = false;

      for (var booking in bookings) {
        String? status = booking['status'] as String?;
        if (status != null && status == 'Accepted') {
          String? session = booking['session'] as String?;
          if (session != null) {
            if (session.contains('Sesi 1 (08.00 - 12.00)')) {
              sesi1Accepted = true;
            } else if (session.contains('Sesi 2 (12.30 - 16.00)')) {
              sesi2Accepted = true;
            } else if (session.contains('Full day (08.00 - 16.00)')) {
              sesi1Accepted = true;
              sesi2Accepted = true;
            }
          }
        }
      }

      if (sesi1Accepted && sesi2Accepted) {
        return 1.0; // 100% occupancy if both sessions are accepted
      } else if (sesi1Accepted || sesi2Accepted) {
        return 0.5; // 50% occupancy if only one session is accepted
      }
    }

    return 0.0; // Default to 0% occupancy
  }

  @override
  void initState() {
    super.initState();
    fetchRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  if (_viewMode == 'Daily') {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, _focusedDay.day);
                  } else if (_viewMode == 'Monthly') {
                    _focusedDay = DateTime(_focusedDay.year - 1, _focusedDay.month, _focusedDay.day);
                  }
                });
              },
            ),
            Text(
              _viewMode == 'Daily'
                  ? '${DateFormat.MMMM().format(_focusedDay)} ${_focusedDay.year}'
                  : '${_focusedDay.year}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed: () {
                setState(() {
                  if (_viewMode == 'Daily') {
                    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, _focusedDay.day);
                  } else if (_viewMode == 'Monthly') {
                    _focusedDay = DateTime(_focusedDay.year + 1, _focusedDay.month, _focusedDay.day);
                  }
                });
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedRoom,
                  items: roomNames.map((String room) {
                    return DropdownMenuItem<String>(
                      value: room,
                      child: Text(room),
                    );
                  }).toList(),
                  hint: Text('Pilih ruang'),
                  onChanged: (String? value) {
                    setState(() {
                      selectedRoom = value;
                      _acceptedBookings = {};
                      _fetchReservationsStream(selectedRoom!).listen((event) {
                        setState(() {
                          _acceptedBookings = event;
                        });
                      });
                    });
                  },
                ),
                SizedBox(height: 10),
                DropdownButton<String>(
                  value: _viewMode,
                  items: ['Daily', 'Monthly', 'Yearly'].map((String mode) {
                    return DropdownMenuItem<String>(
                      value: mode,
                      child: Text(mode),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                      _viewMode = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Grafik Okupansi Ruang',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  height: 300,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: LineChart(
                    LineChartData(
                      minX: 1,
                      maxX: _viewMode == 'Daily'
                          ? DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day.toDouble()
                          : _viewMode == 'Monthly'
                              ? 12
                              : 1,
                      minY: 0,
                      maxY: 1.1,
                      titlesData: FlTitlesData(
                        leftTitles: SideTitles(
                          showTitles: true,
                          getTitles: (value) {
                            return '${(value * 100).toInt()}%';
                          },
                        ),
                        bottomTitles: SideTitles(
                          showTitles: true,
                          getTitles: (value) {
                            if (_viewMode == 'Daily') {
                              return value.toInt().toString();
                            } else if (_viewMode == 'Monthly') {
                              return DateFormat.MMM().format(DateTime(0, value.toInt()));
                            } else {
                              return _focusedDay.year.toString();
                            }
                          },
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _viewMode == 'Daily'
                              ? List.generate(
                                  DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day,
                                  (index) {
                                    double day = index + 1.0;
                                    double occupancy = calculateOccupanciesForMonth(
                                      _focusedDay.year,
                                      _focusedDay.month,
                                    )[index];
                                    return FlSpot(day, occupancy);
                                  },
                                )
                              : _viewMode == 'Monthly'
                                  ? List.generate(12, (index) {
                                      double month = index + 1.0;
                                      double occupancy = calculateOccupanciesForYear(
                                        _focusedDay.year,
                                      )[index];
                                      return FlSpot(month, occupancy);
                                    })
                                  : [
                                      FlSpot(1, calculateOccupanciesForYear(_focusedDay.year).reduce((a, b) => a + b) / 12),
                                    ],
                          isCurved: true,
                          colors: [Colors.blue],
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            colors: [Colors.blue.withOpacity(0.3)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: DashAdmin(),
  ));
}
