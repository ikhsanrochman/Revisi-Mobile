import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Dashboard extends StatelessWidget {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: TabBar(
                indicatorColor: Colors.blue,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  _buildTabWithCounter('Request', 'bookings', status: 'Request'),
                  _buildTabWithCounter('Approved', 'bookings', status: 'Accepted'),
                  _buildTabWithCounter('Rejected', 'bookings', status: 'Rejected'),
                  _buildTabWithCounter('Cancelled', 'bookings', status: 'Cancelled'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildBookingsTab(status: 'Request'),
                  _buildApprovedTab(),
                  _buildRejectedTab(),
                  _buildCancelledTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabWithCounter(String title, String collection, {String? status}) {
    return StreamBuilder<QuerySnapshot>(
      stream: status != null
          ? firestore.collection(collection).where('status', isEqualTo: status).snapshots()
          : firestore.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Tab(child: Text(title));
        }
        if (snapshot.hasError) {
          return Tab(child: Text('$title (Error)'));
        }

        int count = snapshot.data?.docs.length ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Stack(
            children: [
              Tab(
                child: Text(title),
              ),
              if (count > 0)
                Positioned(
                  right: 0,
                  top: 0, // Adjust this value to move the badge downwards
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Center(
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookingsTab({String? status}) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('bookings').where('status', isEqualTo: status).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No booking data available.'));
        }

        var bookings = snapshot.data!.docs;

        return SingleChildScrollView(
          child: Column(
            children: bookings.map((booking) {
              String status = booking['status'];
              DateTime bookingDate = (booking['booking_date'] as Timestamp).toDate();

              if (status != 'Accepted' && status != 'Rejected' && status != 'Cancelled') {
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text('Ruangan: ${booking['room_name']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bidang: ${booking['bidang']}'),
                        Text('Phone: ${booking['phone']}'),
                        Text('Date: ${bookingDate.day}/${bookingDate.month}/${bookingDate.year}'),
                        Text('Sesi: ${booking['session']}'),
                        Text('Keperluan: ${booking['reason']}'),
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 12,
                      children: [
                        ElevatedButton(
                          onPressed: () => _showConfirmationDialog(context, booking, true),
                          child: Text('Accept'),
                        ),
                        ElevatedButton(
                          onPressed: () => _showConfirmationDialog(context, booking, false),
                          child: Text('Reject'),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return SizedBox.shrink();
              }
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildApprovedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('bookings').where('status', isEqualTo: 'Accepted').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No approved bookings available.'));
        }

        var bookings = snapshot.data!.docs;

        return SingleChildScrollView(
          child: Column(
            children: bookings.map((booking) {
              DateTime bookingDate = (booking['booking_date'] as Timestamp).toDate();

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Room: ${booking['room_name']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bidang: ${booking['bidang']}'),
                      Text('Phone: ${booking['phone']}'),
                      Text('Date: ${bookingDate.day}/${bookingDate.month}/${bookingDate.year}'),
                      Text('Sesi: ${booking['session']}'),
                      Text('Keperluan: ${booking['reason']}'),
                    ],
                  ),
                  trailing: Icon(Icons.check_circle, color: Colors.green),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildRejectedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('bookings').where('status', isEqualTo: 'Rejected').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No rejected bookings available.'));
        }

        var bookings = snapshot.data!.docs;

        return SingleChildScrollView(
          child: Column(
            children: bookings.map((booking) {
              DateTime bookingDate = (booking['booking_date'] as Timestamp).toDate();
              String rejectionReason = booking['rejection_reason'] ?? '';

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Room: ${booking['room_name']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bidang: ${booking['bidang']}'),
                      Text('Phone: ${booking['phone']}'),
                      Text('Date: ${bookingDate.day}/${bookingDate.month}/${bookingDate.year}'),
                      Text('Sesi: ${booking['session']}'),
                      Text('Keperluan: ${booking['reason']}'),
                      Text('Rejection Reason: $rejectionReason'),
                    ],
                  ),
                  trailing: Icon(Icons.cancel, color: Colors.red),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCancelledTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('bookings').where('status', isEqualTo: 'Cancelled').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No cancelled bookings available.'));
        }

        var bookings = snapshot.data!.docs;

        return SingleChildScrollView(
          child: Column(
            children: bookings.map((booking) {
              DateTime bookingDate = (booking['booking_date'] as Timestamp).toDate();
              String cancellationReason = booking['cancel_reason'] ?? '';

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Room: ${booking['room_name']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bidang: ${booking['bidang']}'),
                      Text('Phone: ${booking['phone']}'),
                      Text('Date: ${bookingDate.day}/${bookingDate.month}/${bookingDate.year}'),
                      Text('Sesi: ${booking['session']}'),
                      Text('Keperluan: ${booking['reason']}'),
                      Text('Cancellation Reason: $cancellationReason'),
                    ],
                  ),
                  trailing: Icon(Icons.cancel, color: Colors.red),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showConfirmationDialog(BuildContext context, DocumentSnapshot booking, bool accept) {
    String status = accept ? 'Accepted' : 'Rejected';
    String action = accept ? 'Accept' : 'Reject';

    String roomName = booking['room_name'];
    String session = booking['session'];
    DateTime bookingDate = (booking['booking_date'] as Timestamp).toDate();

    Future<bool> _checkConflict() async {
      // Check if there is a maintenance booking for the same date and room
      QuerySnapshot maintenanceSnapshot = await firestore
          .collection('maintenance')
          .where('room_name', isEqualTo: roomName)
          .where('date', isEqualTo: bookingDate)
          .get();

      return maintenanceSnapshot.docs.isNotEmpty;
    }

    _checkConflict().then((isConflict) {
      if (isConflict) {
        // Show conflict dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            String rejectionReason = '';

            return AlertDialog(
              title: Text('Confirmation Failed'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ruangan pada hari dan sesi tersebut sudah dipesan untuk maintenance!'),
                ],
              ),
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
        // No conflicting maintenance booking, show accept/reject confirmation
        showDialog(
          context: context,
          builder: (BuildContext context) {
            String rejectionReason = '';

            return AlertDialog(
              title: Text('$action Booking'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: accept
                    ? [Text('Are you sure you want to $action this booking?')]
                    : [
                        Text('Are you sure you want to $action this booking?'),
                        SizedBox(height: 8),
                        Text('Alasan penolakan:'),
                        TextFormField(
                          onChanged: (value) {
                            rejectionReason = value;
                          },
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Masukkan alasan penolakan',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(action),
                  onPressed: () {
                    if (accept) {
                      firestore.collection('bookings').doc(booking.id).update({
                        'status': status,
                      });
                    } else {
                      firestore.collection('bookings').doc(booking.id).update({
                        'status': status,
                        'rejection_reason': rejectionReason,
                      });
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }).catchError((error) {
      print('Error: $error');
    });
  }
}

void main() {
  runApp(MaterialApp(
    home: Dashboard(),
  ));
}
