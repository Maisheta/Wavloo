import 'package:flutter/material.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  final List<Map<String, dynamic>> calls = const [
    {
      'name': 'Jerome Bell',
      'image': 'https://randomuser.me/api/portraits/women/10.jpg',
      'time': 'Today,12:14AM',
      'type': 'voice',
      'status': 'in',
    },
    {
      'name': 'Cody Fisher',
      'image': 'https://randomuser.me/api/portraits/men/11.jpg',
      'time': 'Yesterday,1:52PM',
      'type': 'voice',
      'status': 'missed',
    },
    {
      'name': 'Arlene McCoy',
      'image': 'https://randomuser.me/api/portraits/women/12.jpg',
      'time': 'Yesterday,8:01AM',
      'type': 'video',
      'status': 'in',
    },
    {
      'name': 'Jenny Wilson',
      'image': 'https://randomuser.me/api/portraits/men/13.jpg',
      'time': 'February17,1:02PM',
      'type': 'voice',
      'status': 'in',
    },
    {
      'name': 'Bessie Cooper',
      'image': 'https://randomuser.me/api/portraits/women/14.jpg',
      'time': 'February16,12:37PM',
      'type': 'voice',
      'status': 'missed',
    },
    {
      'name': 'Cameron Williamson',
      'image': 'https://randomuser.me/api/portraits/men/15.jpg',
      'time': 'February14,4:07PM',
      'type': 'video',
      'status': 'missed',
    },
    {
      'name': 'Leslie Alexander',
      'image': 'https://randomuser.me/api/portraits/women/16.jpg',
      'time': 'February3,10:24PM',
      'type': 'voice',
      'status': 'in',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: calls.length,
          itemBuilder: (context, index) {
            final call = calls[index];
            final isMissed = call['status'] == 'missed';
            final isIn = call['status'] == 'in';
            final isVideo = call['type'] == 'video';

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(call['image']),
                radius: 25,
              ),
              title: Text(call['name']),
              subtitle: Row(
                children: [
                  Icon(
                    isMissed ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isMissed ? Colors.red : Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(call['time'], style: const TextStyle(fontSize: 13)),
                ],
              ),
              trailing: Icon(
                isVideo ? Icons.videocam : Icons.call,
                color: Colors.black54,
              ),
            );
          },
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            backgroundColor: Color(0xffF37C50),
            onPressed: () {},
            child: const Icon(Icons.add_ic_call, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
