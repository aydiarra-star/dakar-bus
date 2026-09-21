'use strict';
// Read-only inspection of a pinned deployment. No execution or rewriting of the
// compiled application, no guessing new coordinates from demo objects.
function auditPublished({network, compiled, index, files, shapes}) {
  const findings = [], counts = {};
  const add = (code, detail) => findings.push({severity:'ERROR',code,detail});
  if (index.includes('flutter') && !files.some(p => p.endsWith('pubspec.yaml')) && !files.some(p => p.endsWith('.dart'))) {
    add('FLUTTER_SOURCE_UNAVAILABLE', 'Application Flutter compilée ; aucun projet Dart trouvé dans cet arbre.');
  }
  const hasMerge = compiled.includes('aW7(){') && compiled.includes('B.b.D($.di(),new A.cg(');
  for (const [net, getter] of [['TER','aCz'],['BRT','aCq']]) {
    const routeStops = new Set(network.routes.filter(r => r.operator_id.toUpperCase() === net).flatMap(r => r.stops));
    const start = compiled.indexOf(`"${getter}",()=>`);
    const end = start < 0 ? -1 : compiled.indexOf('\ns($,',start);
    const block = start < 0 ? '' : compiled.slice(start,end < 0 ? undefined : end);
    const demoCount = (block.match(/A\.cP\(/g) || []).length;
    const extras = network.stops.filter(s => s.name.includes(net) && !routeStops.has(s.id)).map(s => ({id:s.id,name:s.name}));
    const shared = [...new Set(network.routes.filter(r => r.operator_id.toUpperCase() !== net).flatMap(r => r.stops))].filter(id => routeStops.has(id));
    counts[net] = {routeStops:routeStops.size, embeddedDemoEntries:demoCount, namedOutsideRoutes:extras, sharedWithOtherNetworks:shared};
    if (hasMerge && demoCount) add('DEMO_AND_REFERENCE_MERGED', `${net}: ${demoCount} entrées de démonstration puis ${routeStops.size} identifiants du JSON ; pas un compte de gares physiques.`);
    if (extras.length) add('NETWORK_NAMES_OUTSIDE_REFERENCE', `${net}: ${extras.length} entrées nommées hors des lignes de ce réseau (à examiner, ne pas supprimer aveuglément).`);
    if (shared.length) add('GUIDED_STOP_SHARED_WITH_OTHER_NETWORKS', `${net}: ${shared.length} identifiants également utilisés par des routes d'autres réseaux.`);
    const shape = shapes[net];
    if (!shape || shape.source_kind !== 'gtfs-officiel') add('PUBLISHED_GEOMETRY_UNVERIFIED', `${net}: ${shape?.source_kind || 'UNKNOWN'}`);
    else add('PUBLISHED_GEOMETRY_REQUIRES_SOURCE_REVIEW', `${net}: l'étiquette gtfs-officiel n'est pas une preuve de provenance.`);
  }
  if (!hasMerge || !compiled.includes('"aCz",()=>') || !compiled.includes('"aCq",()=>')) {
    add('COMPILED_AUDIT_SIGNATURE_CHANGED', 'Version non reconnue : revue des sources requise, aucun résultat silencieusement validé.');
  }
  if (network.stops.some(s => !s.network)) add('EXPLICIT_NETWORK_MISSING', 'Le JSON publié ne définit pas un champ network pour chaque arrêt.');
  if (network.stops.some(s => !s.source)) add('STOP_PROVENANCE_MISSING', 'data_trust=OFFICIAL seul ne justifie pas les coordonnées.');
  if (compiled.includes('A.b([a,a0],t.q_)')) add('STRAIGHT_LINE_ROUTING_FALLBACK', 'Repli routage sur les deux extrémités détecté dans le programme compilé.');
  return {counts,findings,releaseReady:findings.length===0};
}
module.exports = {auditPublished};
