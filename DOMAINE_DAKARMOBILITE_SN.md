# 🌍 Domaine custom dakarmobilite.sn - Configuration GitHub Pages + Vercel

## Achat du domaine

1. **Acheteur recommandé Sénégal :**
   - https://www.nic.sn (officiel .sn)
   - https://www.hostinger.sn
   - https://www.lws.fr (.sn disponible)
   - Ou Namecheap, GoDaddy, OVH

2. **Prix :** ~15 000 - 25 000 FCFA / an pour .sn

3. **Achète :** `dakarmobilite.sn` + `www.dakarmobilite.sn`

---

## Option 1: GitHub Pages (gratuit, recommandé pour début)

### Étape 1: Fichier CNAME déjà créé
Dans le repo, fichier `CNAME` contient `dakarmobilite.sn` → GitHub Pages le détecte auto.

### Étape 2: DNS chez ton registrar (NIC.sn)

Va dans ton panel DNS et ajoute :

**Pour apex `dakarmobilite.sn` :**
```
Type: A
Name: @
Value: 185.199.108.153
TTL: 3600

Type: A
Name: @
Value: 185.199.109.153

Type: A
Name: @
Value: 185.199.110.153

Type: A
Name: @
Value: 185.199.111.153
```

**Pour `www.dakarmobilite.sn` :**
```
Type: CNAME
Name: www
Value: TONUSER.github.io
TTL: 3600
```

Remplace `TONUSER` par ton username GitHub.

**Alternative plus simple (si ton registrar supporte ALIAS/ANAME) :**
```
Type: ALIAS ou ANAME
Name: @
Value: TONUSER.github.io
```

### Étape 3: Active sur GitHub
- Repo → Settings → Pages
- Custom domain : `dakarmobilite.sn` → Save
- Coche **Enforce HTTPS** (après 1h, certificat Let's Encrypt auto)

### Étape 4: Attends propagation
- 1h à 24h max
- Teste : https://dnschecker.org → tape dakarmobilite.sn → doit afficher IPs GitHub

**Résultat :**
- https://dakarmobilite.sn → ton site PWA
- https://www.dakarmobilite.sn → redirige vers apex

---

## Option 2: Vercel (plus puissant, API GTFS-RT live)

Vercel gère mieux le proxy Express GTFS-RT protobuf.

### Étape 1: Déploie sur Vercel
```bash
vercel --prod
```

### Étape 2: Ajoute domaine dans Vercel
- Vercel Dashboard → ton projet → Settings → Domains
- Add : `dakarmobilite.sn`
- Add : `www.dakarmobilite.sn`

Vercel te donne des instructions DNS :

**Pour Vercel, DNS recommandé :**
```
Type: A
Name: @
Value: 76.76.21.21

Type: CNAME
Name: www
Value: cname.vercel-dns.com
```

Ou si tu veux garder GitHub Pages + Vercel API :
- `dakarmobilite.sn` → GitHub Pages (frontend)
- `api.dakarmobilite.sn` → Vercel (proxy GTFS-RT)

Dans ce cas :
```
Type: A (pour frontend GitHub Pages)
@ → 185.199.108.153 etc.

Type: CNAME (pour API Vercel)
api → cname.vercel-dns.com
```

Et dans frontend, change `GTFS_CONFIG.endpoint` → `https://api.dakarmobilite.sn/api/gtfs-rt/vehiclePositions`

### Étape 3: HTTPS auto
Vercel génère certificat auto en 1 min.

---

## Option 3: Les deux (recommandé pro)

- **Frontend PWA** sur GitHub Pages : `dakarmobilite.sn` (gratuit, CDN rapide)
- **API GTFS-RT Proxy** sur Vercel : `api.dakarmobilite.sn` (Node.js, protobuf)

Avantages :
- Frontend ultra rapide (GitHub CDN)
- Backend scalable (Vercel serverless)
- Séparation des coûts

**DNS pour cette config hybride :**
```
@ → 185.199.108.153, 109, 110, 111 (GitHub)
www → TONUSER.github.io (CNAME)
api → cname.vercel-dns.com (CNAME)
```

---

## Vérification

Après config DNS :

```bash
# Teste DNS
dig dakarmobilite.sn +short
# doit retourner IPs GitHub ou Vercel

# Teste HTTPS
curl -I https://dakarmobilite.sn

# Teste PWA
curl https://dakarmobilite.sn/manifest.json
```

## Email pro (optionnel)

Avec domaine `dakarmobilite.sn`, crée :

- `contact@dakarmobilite.sn`
- `api@dakarmobilite.sn`

Via :
- Google Workspace (6€/mois)
- Zoho Mail (gratuit 5 users)
- Ou registrar email inclus

## Résumé fichiers déjà prêts

- `CNAME` → contient `dakarmobilite.sn` (pour GitHub Pages)
- `vercel.json` → gère domaine custom auto
- `data/gtfs/` → 42 arrêts dont 23 BRT + 76 routes (64 AFTU)
- Workflow GitHub Pages déjà configuré

Il te reste juste à acheter `dakarmobilite.sn` et mettre les DNS ci-dessus.
