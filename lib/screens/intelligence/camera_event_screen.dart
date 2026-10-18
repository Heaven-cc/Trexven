import 'package:flutter/material.dart';
import '../../models/camera.dart';
import 'events_screen.dart';

class CameraEventsScreen extends StatelessWidget {
  const CameraEventsScreen({super.key, required this.camera});
  final Camera camera;
  @override
  Widget build(BuildContext context) =>
      EventsScreen(cameraId: camera.id, cameraName: camera.name);
}
