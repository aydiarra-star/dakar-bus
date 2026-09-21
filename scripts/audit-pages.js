#!/usr/bin/env node
'use strict';
const {execFileSync} = require('node:child_process');
const fs = require('node:fs');
const {auditPublished} = require('./lib/pages-audit');
// gh uses the sandbox's existing authentication; never read/write credentials.
const repo = 'aydiarra-star/dakar-bus';
const api = path => JSON.parse(execFileSync('gh',['api',`repos/${repo}/${path}`],{encoding:'utf8',maxBuffer:20*1024*1024}));
try {
  const pages = api('pages');
  const branch = pages.source?.branch;
  if (!branch) throw new Error('Déploiement Pages sans branche source : inspecter le workflow avant de continuer.');
  const ref = api(`commits/${encodeURIComponent(branch)}`).sha;
  const tree = api(`git/trees/${ref}?recursive=1`);
  if (tree.truncated) throw new Error('Arbre Git tronqué, audit incomplet.');
  const files = tree.tree.map(f => f.path);
  function read(path) {
    const file = tree.tree.find(f => f.path === path);
    if (!file) throw new Error(`Fichier absent : ${path}`);
    return Buffer.from(api(`git/blobs/${file.sha}`).content,'base64').toString('utf8');
  }
  const result = auditPublished({network:JSON.parse(read('assets/assets/data/dakar_network.json')),
    compiled:read('main.dart.js'),index:read('index.html'),files,
    shapes:{TER:JSON.parse(read('assets/assets/data/ter_rail_shapes.json')),BRT:JSON.parse(read('assets/assets/data/brt_dedicated_shapes.json'))}});
  const report = {auditDate:'2026-09-21',repository:repo,branch,commit:ref,url:pages.html_url,...result};
  const output = process.argv[2];
  if (output) fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
  process.exitCode = result.releaseReady ? 0 : 1;
} catch (error) {
  console.error('AUDIT_INCOMPLETE:',error.message);
  process.exitCode = 2;
}
