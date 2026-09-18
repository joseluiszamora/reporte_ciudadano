import 'data/local_submission_repository.dart';
import 'domain/device_adapters.dart';
import 'domain/session_repository.dart';
import 'domain/submission_repository.dart';
import '../community/domain/community_repository.dart';
import '../follow_up/domain/follow_up_repository.dart';

class PrototypeServices {
  PrototypeServices({
    required this.session,
    required this.submissions,
    required this.location,
    required this.photos,
    CommunityRepository? community,
    FollowUpRepository? followUp,
  }) : community = community ?? submissions as CommunityRepository,
       followUp = followUp ?? submissions as FollowUpRepository;
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
  final CommunityRepository community;
  final FollowUpRepository followUp;
  void dispose() {
    if (!identical(followUp, submissions) && !identical(followUp, community)) {
      followUp.dispose();
    }
    if (!identical(community, submissions)) community.dispose();
    submissions.dispose();
    session.dispose();
  }
}
