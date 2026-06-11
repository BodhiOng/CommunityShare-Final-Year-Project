enum UserRole { donor, recipient, hub, admin }

extension UserRoleX on UserRole {
  String get key => switch (this) {
        UserRole.donor => 'donor',
        UserRole.recipient => 'recipient',
        UserRole.hub => 'hub',
        UserRole.admin => 'admin',
      };

  String get label => switch (this) {
        UserRole.donor => 'Donor',
        UserRole.recipient => 'Recipient',
        UserRole.hub => 'Community Hub',
        UserRole.admin => 'Administrator',
      };

  String get description => switch (this) {
        UserRole.donor => 'Create listings, review requests, and track handovers.',
        UserRole.recipient => 'Browse items, request support, and track collection.',
        UserRole.hub => 'Coordinate handovers and monitor local activity.',
        UserRole.admin => 'Manage users, categories, listings, and reports.',
      };

  static UserRole fromStorage(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'donor':
      case 'seller':
        return UserRole.donor;
      case 'hub':
      case 'community_hub':
      case 'community hub':
        return UserRole.hub;
      case 'admin':
      case 'administrator':
        return UserRole.admin;
      case 'recipient':
      case 'buyer':
      default:
        return UserRole.recipient;
    }
  }
}
