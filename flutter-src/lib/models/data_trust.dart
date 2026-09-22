/// Dakar Bus - Groupe 11
/// DataTrust : décrit la confiance / nature de la donnée
/// Ne pas confondre avec DataStatus
/// DataTrust = confiance / provenance
/// DataStatus = disponibilité temporelle

enum DataTrust {
  verified,
  official,
  community,
  unknown,
}
