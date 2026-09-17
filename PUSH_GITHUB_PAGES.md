# 🚀 Pousser sur https://github.com/aydiarra-star/dakar-bus.git + GitHub Pages

Ton repo local est prêt (branch main, 4 commits). Le push auto a échoué car pas de token dans l'environnement sandbox (normal).

## Option 1: Push depuis ton PC (recommandé - 1 min)

### 1. Télécharge le ZIP
Dans ce workspace, télécharge `dakar-mobilite-github-pages.zip` (67KB) → dézip sur ton PC

OU clone ton repo existant puis copie les fichiers :

```bash
git clone https://github.com/aydiarra-star/dakar-bus.git
cd dakar-bus
# copie tous les fichiers du ZIP ici (écrase)
```

### 2. Push
```bash
cd dakar-bus
git add .
git commit -m "feat: 23 BRT réelles + 64 AFTU + dakarmobilite.sn + PWA GTFS-RT"
git branch -M main
git push -u origin main
```

GitHub va te demander username + token. Utilise :
- Username: `aydiarra-star`
- Password: **ton Personal Access Token** (pas ton mot de passe GitHub)

**Créer token:** GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate → coche `repo` → Generate → copie.

### 3. Active GitHub Pages
- Va sur https://github.com/aydiarra-star/dakar-bus/settings/pages
- **Source:** GitHub Actions
- Le workflow `.github/workflows/deploy.yml` se lance auto
- Attends 1 min → site live sur `https://aydiarra-star.github.io/dakar-bus/`

### 4. Domaine custom dakarmobilite.sn
- Toujours dans Settings → Pages → Custom domain → entre `dakarmobilite.sn` → Save
- Fichier `CNAME` déjà dans repo avec `dakarmobilite.sn`
- Configure DNS chez NIC.sn (voir DOMAINE_DAKARMOBILITE_SN.md) :
```
A @ 185.199.108.153
A @ 185.199.109.153
A @ 185.199.110.153
A @ 185.199.111.153
CNAME www → aydiarra-star.github.io
```
- Coche Enforce HTTPS après 1h

---

## Option 2: Upload via GitHub Web (sans git)

1. Va sur https://github.com/aydiarra-star/dakar-bus
2. Add file → Upload files → glisse tout le contenu du ZIP (index.html, data/, etc.)
3. Commit directly to main
4. Settings → Pages → Source GitHub Actions

---

## Option 3: Je pousse pour toi si tu donnes token

Si tu veux que je pousse depuis ici, donne-moi un **Personal Access Token temporaire** (je le supprime après).

Dans le chat, dis :
```
Mon token: ghp_xxxxxxxxxxxx
```

Je ferai :
```bash
git remote set-url origin https://ghp_xxx@github.com/aydiarra-star/dakar-bus.git
git push -u origin main
```

**Sécurité:** Crée un token qui expire dans 1 jour, avec scope `repo` uniquement, et révoque-le après push.

---

## Vérification après push

```bash
# Après push, teste:
curl https://aydiarra-star.github.io/dakar-bus/api/gtfs/static
# Sur GitHub Pages, /api n'existe pas → fallback mock local (normal, fonctionne)

curl https://aydiarra-star.github.io/dakar-bus/data/gtfs/stops.txt | wc -l
# doit afficher 43 lignes (42 arrêts + header)

# Site:
https://aydiarra-star.github.io/dakar-bus/#explorer
# → carte avec 23 BRT violettes + 64 AFTU
```

---

## www → apex redirect

Déjà configuré :
- JS dans index.html redirige `www.dakarmobilite.sn` → `dakarmobilite.sn`
- DNS CNAME www → aydiarra-star.github.io
- GitHub Pages redirige auto www → apex quand CNAME = apex

---

## Email contact@dakarmobilite.sn

Voir `EMAIL_SETUP_CONTACT.md` :

**Le plus simple (gratuit, 5 min):**
- Cloudflare → Email Routing → Forward `contact@dakarmobilite.sn` → ton Gmail

**Ou Zoho Mail gratuit :**
- MX mx.zoho.com etc. → boîte mail pro 5GB

Footer déjà avec `mailto:contact@dakarmobilite.sn` cliquable.

---

## Fichiers prêts

- `CNAME` → dakarmobilite.sn
- `index.html` → 23 BRT + 64 AFTU + footer contact + www redirect
- `data/gtfs/` → 42 stops, 76 routes
- `.github/workflows/deploy.yml` → deploy auto Pages
- `dakar-mobilite-github-pages.zip` → tout en un 67KB

Dis-moi quand c'est poussé, je vérifie le site live !
