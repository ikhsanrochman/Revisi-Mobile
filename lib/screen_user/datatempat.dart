import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class DataTempat extends StatefulWidget {
  @override
  _DataTempatState createState() => _DataTempatState();
}

class _DataTempatState extends State<DataTempat> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  DateTime? selectedDate;
  String searchQuery = '';
  List<Map<String, dynamic>> sessions = [];
  String selectedSessionCode = '';

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    QuerySnapshot sessionSnapshot = await firestore.collection('sessions').get();
    List<Map<String, dynamic>> sessionData = sessionSnapshot.docs.map((doc) {
      return {
        'code': doc['code'],
        'name': doc['name'],
        'start_time': doc['start_time'].toDate(),
        'end_time': doc['end_time'].toDate(),
      };
    }).toList();

    sessionData.sort((a, b) => a['start_time'].compareTo(b['start_time']));

    setState(() {
      sessions = sessionData.map((session) {
        return {
          'code': session['code'],
          'display':
              '${session['name']} (${session['start_time'].hour}:${session['start_time'].minute.toString().padLeft(2, '0')} - ${session['end_time'].hour}:${session['end_time'].minute.toString().padLeft(2, '0')})'
        };
      }).toList();

      if (sessions.isNotEmpty) {
        selectedSessionCode = sessions[0]['code'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Ruangan'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Cari Ruangan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore.collection('rooms').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var rooms = snapshot.data!.docs.where((room) {
                  var roomName = (room['room_name'] ?? '').toString().toLowerCase();
                  return roomName.contains(searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    var room = rooms[index];

                    List<dynamic> images = (room.data() as Map<String, dynamic>?)?['images'] ?? [];
                    List<dynamic> facilities = (room.data() as Map<String, dynamic>?)?['facilities'] ?? [];

                    PageController pageController = PageController();

                    return Card(
                      elevation: 3,
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (images.isNotEmpty)
                              Column(
                                children: [
                                  Container(
                                    height: 200,
                                    child: PageView.builder(
                                      controller: pageController,
                                      itemCount: images.length,
                                      itemBuilder: (context, imgIndex) {
                                        return Padding(
                                          padding: EdgeInsets.only(right: 8.0),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8.0),
                                            child: Image.network(
                                              images[imgIndex],
                                              width: double.infinity,
                                              height: 200,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  SmoothPageIndicator(
                                    controller: pageController,
                                    count: images.length,
                                    effect: WormEffect(
                                      dotHeight: 8,
                                      dotWidth: 8,
                                      activeDotColor: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            SizedBox(height: 16),
                            Text(
                              room['room_name'] ?? 'Nama Ruangan Tidak Tersedia',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('Kapasitas: ${room['capacity']}'),
                            Text('Luas: ${room['area']} m²'),
                            SizedBox(height: 8),
                            Text(
                              'Fasilitas:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            for (var facility in facilities)
                              Text('${facility['name']} (${facility['quantity']})'),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _showBookingDialog(context, room),
                                  child: Text(
                                    'Pesan',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingDialog(BuildContext context, DocumentSnapshot room) async {
    final _formKey = GlobalKey<FormState>();
    String reason = '';
    String errorMessage = '';

    User? user = auth.currentUser;
    if (user == null) {
      return;
    }

    DocumentSnapshot userDoc = await firestore.collection('users').doc(user.uid).get();
    String userField = userDoc['bidang'];
    String userPhone = userDoc['phone'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Pesan Ruangan'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      TextFormField(
                        decoration: InputDecoration(labelText: 'Alasan Meminjam'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Alasan tidak boleh kosong';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          reason = value;
                        },
                      ),
                      SizedBox(height: 16),
                      Text('Tanggal Pemesanan'),
                      TextFormField(
                        readOnly: true,
                        controller: TextEditingController(
                          text: selectedDate != null
                              ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                              : "",
                        ),
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(DateTime.now().year + 1),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                      ),
                      SizedBox(height: 16),
                      Text('Pilih Sesi'),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'Pilih Sesi'),
                        value: selectedSessionCode.isNotEmpty ? selectedSessionCode : null,
                        items: sessions.map((session) {
                          return DropdownMenuItem<String>(
                            child: Text(session['display']),
                            value: session['code'],
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedSessionCode = value!;
                            errorMessage = '';
                          });
                        },
                      ),
                      if (errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            errorMessage,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Batal'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Pesan'),
                  onPressed: () async {
                    if (selectedDate == null) {
                      setState(() {
                        errorMessage = 'Silakan pilih tanggal pemesanan';
                      });
                      return;
                    }

                    bool isBookingAvailable = await _checkBookingAvailabilityForDateAndSession(
                        room['room_name'], selectedSessionCode, selectedDate!);

                    if (!isBookingAvailable) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Pemesanan Gagal'),
                            content: Text('Ruangan ini sudah dipesan pada sesi yang dipilih atau sedang dalam status Maintenance.'),
                            actions: <Widget>[
                              TextButton(
                                child: Text('OK'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                      return;
                    }

                    if (_formKey.currentState!.validate()) {
                      QuerySnapshot namaSesi = await firestore.collection('sessions').where('code', isEqualTo: selectedSessionCode).get();
                      String selectedSessionName = namaSesi.docs.first['name'];

                      firestore.collection('bookings').add({
                        'room_name': room['room_name'],
                        'name': user.displayName,
                        'bidang': userField,
                        'phone': userPhone,
                        'session': selectedSessionCode,
                        'session_name': selectedSessionName,
                        'reason': reason,
                        'booking_date': Timestamp.fromDate(selectedDate!),
                        'status': 'Request',
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      Navigator.of(context).pop();

                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Pemesanan Berhasil'),
                            content: Text('Ruangan telah berhasil dipesan.'),
                            actions: <Widget>[
                              TextButton(
                                child: Text('OK'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      setState(() {
                        errorMessage = 'Silakan lengkapi semua data';
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _checkBookingAvailabilityForDateAndSession(
    String roomName, String sessionCode, DateTime selectedDate) async {
  Timestamp selectedTimestamp = Timestamp.fromDate(selectedDate);

  QuerySnapshot maintenanceBookingsSnapshot = await firestore
      .collection('bookings')
      .where('room_name', isEqualTo: roomName)
      .where('booking_date', isEqualTo: selectedTimestamp)
      .where('status', isEqualTo: 'Maintenance')
      .get();

  if (maintenanceBookingsSnapshot.docs.isNotEmpty) {
    return false;
  }

  // Cek apakah sesi Pagi atau Sore sudah diterima
  QuerySnapshot acceptedMorningBookings = await firestore
      .collection('bookings')
      .where('room_name', isEqualTo: roomName)
      .where('session', isEqualTo: 'PAGI')
      .where('booking_date', isEqualTo: selectedTimestamp)
      .where('status', isEqualTo: 'Accepted')
      .get();

  QuerySnapshot acceptedAfternoonBookings = await firestore
      .collection('bookings')
      .where('room_name', isEqualTo: roomName)
      .where('session', isEqualTo: 'SORE')
      .where('booking_date', isEqualTo: selectedTimestamp)
      .where('status', isEqualTo: 'Accepted')
      .get();

  if (acceptedMorningBookings.docs.isNotEmpty || acceptedAfternoonBookings.docs.isNotEmpty) {
    // Jika sesi Pagi atau Sore sudah diterima, tidak bisa memesan sesi Full Day
    if (sessionCode == 'FULL') {
      return false;
    }
  }

  // Cek pemesanan sesi sesuai dengan yang dipilih
  QuerySnapshot sessionBookingsSnapshot = await firestore
      .collection('bookings')
      .where('room_name', isEqualTo: roomName)
      .where('session', isEqualTo: sessionCode)
      .where('booking_date', isEqualTo: selectedTimestamp)
      .where('status', isEqualTo: 'Accepted')
      .get();

  return sessionBookingsSnapshot.docs.isEmpty;
}
}
