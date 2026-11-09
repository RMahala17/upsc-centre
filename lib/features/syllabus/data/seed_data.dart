/// Subject structure only. No lecture counts, no progress, no fake data.
class SeedSubject {
  final String id;
  final String name;
  final String paper;
  const SeedSubject(this.id, this.name, this.paper);
}

const gsSeed = [
  SeedSubject('gs1_heritage', 'Indian Heritage and Culture', 'GS1'),
  SeedSubject('gs1_ancient', 'Ancient History', 'GS1'),
  SeedSubject('gs1_medieval', 'Medieval History', 'GS1'),
  SeedSubject('gs1_modern', 'Modern History', 'GS1'),
  SeedSubject('gs1_world', 'World History', 'GS1'),
  SeedSubject('gs1_postindep', 'Post-Independence India', 'GS1'),
  SeedSubject('gs1_society', 'Indian Society', 'GS1'),
  SeedSubject('gs1_geography', 'Geography', 'GS1'),
  SeedSubject('gs2_polity', 'Constitution and Polity', 'GS2'),
  SeedSubject('gs2_governance', 'Governance', 'GS2'),
  SeedSubject('gs2_socialjustice', 'Social Justice', 'GS2'),
  SeedSubject('gs2_ir', 'International Relations', 'GS2'),
  SeedSubject('gs3_economy', 'Indian Economy', 'GS3'),
  SeedSubject('gs3_agriculture', 'Agriculture', 'GS3'),
  SeedSubject('gs3_scitech', 'Science and Technology', 'GS3'),
  SeedSubject('gs3_environment', 'Environment', 'GS3'),
  SeedSubject('gs3_disaster', 'Disaster Management', 'GS3'),
  SeedSubject('gs3_internalsec', 'Internal Security', 'GS3'),
  SeedSubject('gs4_ethics', 'Ethics', 'GS4'),
  SeedSubject('gs4_integrity', 'Integrity', 'GS4'),
  SeedSubject('gs4_aptitude', 'Aptitude', 'GS4'),
  SeedSubject('gs4_casestudies', 'Case Studies', 'GS4'),
];

/// Previously reported counts. NOT guaranteed current: only loaded if the
/// user reviews and confirms them on the setup screen.
class HistoricalSeed {
  final String subjectId;
  final String label;
  final int completed;
  final int total;
  const HistoricalSeed(this.subjectId, this.label, this.completed, this.total);
}

const historicalSeed = [
  HistoricalSeed('gs1_heritage', 'Art & Culture', 8, 12),
  HistoricalSeed('gs1_world', 'World History', 2, 12),
  HistoricalSeed('gs1_postindep', 'Post-Independence', 0, 8),
  HistoricalSeed('gs3_scitech', 'Science & Technology', 0, 48),
  HistoricalSeed('gs3_internalsec', 'Internal Security', 0, 11),
];
