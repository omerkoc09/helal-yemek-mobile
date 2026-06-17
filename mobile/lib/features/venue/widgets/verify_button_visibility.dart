bool shouldShowVerifyButton(
  String? currentUserId,
  String addedBy,
  String status, {
  DateTime? verificationDueAt,
}) {
  if (currentUserId == null) return false;
  if (currentUserId != addedBy) return false;
  if (status == 'suspended') return true;
  if (status == 'approved' && verificationDueAt != null) {
    return verificationDueAt.difference(DateTime.now()).inDays <= 14;
  }
  return false;
}
