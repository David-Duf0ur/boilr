# 🚀 Boil'r

L'outil ultime pour les multi projects lovers !!

![meme](src/meme.webp)



> Zero-to-working fullstack app generator – in one command.

**Boilr** est un générateur de projet automatisé qui vous permet de lancer un projet **fullstack** complet (Node.js + TypeScript + PostgreSQL + React + Tailwind) en une seule commande à partir d’un simple fichier de configuration `config.json`.

---

## 🧠 Philosophie

Boilr part d’un principe simple : *"Why waste time setting up your stack when you could be building?"*

* ✅ Structure projet cohérente
* ⚙️ Backend Express avec PostgreSQL
* 💨 Frontend React + Tailwind
* 🐳 Docker ready
* 🧪 TypeScript en standard
* 🔧 Configurable à 100% via JSON

---

## 🗂️ Exemple de configuration (`config.json`)

```json
{
  "baseDir": "/home/david/DEV",
  "projectName": "Alpha",
  "structure": ["backend", "frontend"],
  "backend": {
    "structure": ["controller", "data", "mapper", "route"],
    "dependencies": ["express", "cookie-parser", "pg"],
    "devDependencies": ["concurrently", "@types/cookie-parser", "@types/express", "ts-node", "typescript", "@types/pg"],
    "useTypescript": true,
    "entryPoint": "server.ts",
    "useDocker": true
  },
  "frontend": {
    "framework": "react",
    "frameworkCSS": "tailwind"
  },
  "database": {
    "type": "pg",
    "name": "database",
    "PG_URL": "postgres://root:root@database:5432/mydb",
    "POSTGRES_USER": "root",
    "POSTGRES_PASSWORD": "root",
    "POSTGRES_DB": "mydb"
  }
}
```
### 🚧 Prérequis

Avant d’utiliser **Boilr**, assurez-vous d’avoir les éléments suivants installés sur votre machine :

- [x] **jq** — pour lire le fichier `config.json`
  ```bash
  sudo apt install jq
  ```

### Cloner le repo et lancer le script

```bash
git clone https://github.com/David-Duf0ur/boilr

cd boilr

./boilr.sh
```


