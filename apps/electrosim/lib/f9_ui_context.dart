enum F9UserRole { teacher, student }

extension F9UserRoleLabel on F9UserRole {
  String get label => switch (this) {
    F9UserRole.teacher => 'Professeur',
    F9UserRole.student => 'Élève',
  };
}
