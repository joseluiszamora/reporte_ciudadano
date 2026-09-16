import 'data/local_submission_repository.dart';
import 'domain/device_adapters.dart';
import 'domain/session_repository.dart';
import 'domain/submission_repository.dart';

class PrototypeServices {
  PrototypeServices({
    required this.session,
    required this.submissions,
    required this.location,
    required this.photos,
  });
  factory PrototypeServices.memory() {
    final session = DemoSessionRepository();
    return PrototypeServices(
      session: session,
      submissions: LocalSubmissionRepository(
        session: session,
        storage: MemoryDraftStorage(),
      ),
      location: DemoLocationAdapter(),
      photos: DemoPhotoAdapter(),
    );
  }
  final SessionRepository session;
  final SubmissionRepository submissions;
  final LocationAdapter location;
  final PhotoAdapter photos;
  void dispose() {
    submissions.dispose();
    session.dispose();
  }
}
