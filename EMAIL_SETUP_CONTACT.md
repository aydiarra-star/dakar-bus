# ✉️ Email pro contact@dakarmobilite.sn - Configuration

## Option 1: Zoho Mail (Gratuit, recommandé pour début - 5 users gratuits)

### Étapes:
1. Va sur https://www.zoho.com/mail/ → Sign up gratuit
2. Choisis "Add your domain" → entre `dakarmobilite.sn`
3. Zoho te donne des enregistrements DNS à ajouter chez NIC.sn :

```
Type: TXT
Name: @
Value: zoho-verification=zbxxxxxxxx (code fourni par Zoho)

Type: MX
Name: @
Value: mx.zoho.com
Priority: 10

Type: MX
Name: @
Value: mx2.zoho.com
Priority: 20

Type: MX
Name: @
Value: mx3.zoho.com
Priority: 50

Type: TXT
Name: @
Value: v=spf1 include:zoho.com ~all

Type: TXT
Name: @
Value: zoho-verification...
```

4. Dans Zoho, crée :
- `contact@dakarmobilite.sn`
- `support@dakarmobilite.sn`
- `api@dakarmobilite.sn`
- `admin@dakarmobilite.sn`

5. Attends 1h propagation → teste envoi

**Avantages:** Gratuit, 5GB/user, webmail pro

---

## Option 2: Google Workspace (6€/mois, plus pro)

1. https://workspace.google.com → Commencer
2. Domaine: `dakarmobilite.sn`
3. Google te donne MX:

```
@ MX 1 aspmx.l.google.com
@ MX 5 alt1.aspmx.l.google.com
@ MX 5 alt2.aspmx.l.google.com
@ MX 10 alt3.aspmx.l.google.com
@ MX 10 alt4.aspmx.l.google.com
```

4. Crée `contact@dakarmobilite.sn` → Gmail pro

**Avantages:** Gmail interface, Drive, Meet

---

## Option 3: Forward gratuit via registrar (NIC.sn / Cloudflare)

Si tu utilises Cloudflare pour DNS (recommandé) :

1. Cloudflare → ton domaine → Email → Email Routing
2. Active Email Routing → crée forward:
```
contact@dakarmobilite.sn → tonemailperso@gmail.com
support@dakarmobilite.sn → tonemailperso@gmail.com
```

Gratuit, pas de boîte mail, juste forward.

---

## DNS complet pour dakarmobilite.sn (GitHub Pages + Email Zoho + www redirect)

**Configuration finale recommandée (avec Zoho) :**

```
# GitHub Pages (frontend PWA)
Type A @ 185.199.108.153
Type A @ 185.199.109.153
Type A @ 185.199.110.153
Type A @ 185.199.111.153

Type CNAME www → aydiarra-star.github.io
# GitHub redirigera www.dakarmobilite.sn → dakarmobilite.sn auto

# Email Zoho
Type MX @ mx.zoho.com 10
Type MX @ mx2.zoho.com 20
Type MX @ mx3.zoho.com 50
Type TXT @ v=spf1 include:zoho.com ~all
Type TXT @ zoho-verification=...

# Optionnel: API Vercel pour GTFS-RT live
Type CNAME api → cname.vercel-dns.com
```

---

## Test email

Après config (1-2h) :

```bash
dig MX dakarmobilite.sn +short
# doit retourner mx.zoho.com

# Envoi test
echo "Test Dakar Mobilité" | mail -s "Test" contact@dakarmobilite.sn
```

Dans le site, footer a déjà `mailto:contact@dakarmobilite.sn` + `support@`.

---

## Formulaire de contact (sans backend)

Dans `index.html`, tu peux ajouter un formulaire qui envoie via Formspree (gratuit) vers contact@dakarmobilite.sn :

```html
<form action="https://formspree.io/f/TON_ID" method="POST">
  <input name="email" type="email" placeholder="Ton email">
  <textarea name="message"></textarea>
  <button>Envoyer à contact@dakarmobilite.sn</button>
</form>
```

Crée compte sur https://formspree.io → colle ton email → récupère ID.

---

## Résumé

- www → apex redirect : fait via DNS CNAME + JS dans index.html
- Email pro : Zoho gratuit 5 users → MX + TXT
- Footer déjà avec contact@dakarmobilite.sn cliquable
- Tout prêt dans repo

Besoin que je configure Cloudflare pour toi ?
