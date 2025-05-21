#!/bin/bash
                            
clear

                                                
cat << "EOF"
                                                
██████╗  ██████╗ ██╗██╗     ██████╗ 
██╔══██╗██╔═══██╗██║██║     ██╔══██╗
██████╔╝██║   ██║██║██║     ██████╔╝
██╔══██╗██║   ██║██║██║     ██╔══██╗
██████╔╝╚██████╔╝██║███████╗██║  ██║
╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝
────────────────────────────────────────────
 __   ___              __     __   ___ 
|  \ |__  \  / | |\ | /__` | |  \ |__  
|__/ |___  \/  | | \| .__/ | |__/ |___         
                                                
────────────────────────────────────────────
📛 Nom       : boilr.sh
🧑 Auteur    : David Dufour
📅 Date      : 16 Mai 2025
🧽 Objet     : Generer une app fullstack 💡
🛠️ Usage     : ./boilr.sh --projectName
⚙️ Dépend    : bash, jq, node, docker, npm
🚀 Version   : 1.0.0
────────────────────────────────────────────


EOF


progress_bar() {
  local message="$1"
  local total_width=40       
  local bar_length=30       
  local i=0

  # Calcul du padding pour aligner le texte
  local padding=$(printf '%*s' $((total_width - ${#message})) '')

  # Affichage initial
  echo -ne "${message}${padding}: ["
  while [ $i -lt $bar_length ]; do
    echo -n "#"
    sleep 0.03
    ((i++))
  done
  echo "] ✅"
}

progress_bar_2 () {
  local cmd="$1"                 # commande à exécuter
  local message="$2"             # libellé à afficher

  local total_width=40           # largeur texte + padding
  local bar_length=30            # nombre de # à afficher
  local i=0

  # Calcule le padding pour que le ':' soit à la 41ᵉ colonne
  local padding=$(printf '%*s' $((total_width - ${#message})) '')

  # Affichage du début de ligne
  printf "%s%s: [" "$message" "$padding"

  # Lance la commande en arrière‑plan
  bash -c "$cmd" &>/dev/null &
  local pid=$!

  # Remplit la barre tant que le processus tourne
  while kill -0 "$pid" 2>/dev/null; do
    if (( i < bar_length )); then
      printf "#"
      ((i++))
    fi
    sleep 0.2
  done

  # Termine la barre si elle n’est pas pleine
  while (( i < bar_length )); do
    printf "#"
    ((i++))
  done

  printf "] "          # crochet fermant + espace
  wait "$pid"          # récupère le code retour
  if (( $? == 0 )); then
    printf "✅\n"
  else
    printf "❌\n"
    return 1
  fi
}

chmod +x boilr.sh
bash clear.sh

# Retourne le chemin absolu qui contient ce script 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Retourne le chemin absolu du fichier de config
CONFIG_FILE="$SCRIPT_DIR/config.json"

RAW_NAME="$1"
PROJECT_NAME="${RAW_NAME#--}"

# Vérification si le fichier de config existe bien
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Fichier de configuration $CONFIG_FILE introuvable."
  exit 1
fi

# Vérifie qu'un nom de projet est fourni
if [ -z "$1" ]; then
  echo "❌ Utilisation : bash boilr.sh --YourProjectName"
  exit 1
fi

if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "❌ Nom de projet invalide : uniquement lettres, chiffres, tirets ou underscores"
  exit 1
fi

# ajout du nom de projet dans le fichier de param
jq --arg name "$PROJECT_NAME" '.projectName = $name' "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"

# Vérification des prérequis obligatoire
PREREQUIS=$(jq -r '.prerequis[]' "$CONFIG_FILE")

for cmd in $PREREQUIS; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ $cmd non installé"
    MISSING=true  
  fi
done

if [ "$MISSING" = true ]; then
  echo "⚠️ Des outils manquent. Veuillez installer les dépendances listées dans la section Prérequis."
  exit 1
else
  echo "✅ Environnement prêt"
fi

# Création des variables nécessaires à la création du projet
PROJECT_NAME=$(jq -r '.projectName' "$CONFIG_FILE")
STRUCTURE=$(jq -r '.structure[]' "$CONFIG_FILE")

BASEDIR=$(jq -r '.baseDir' "$CONFIG_FILE")

# Création du répertoire racine du projet
mkdir -p "$BASEDIR/$PROJECT_NAME"
cd "$BASEDIR/$PROJECT_NAME" || exit

# Création du fichier .gitignore à la racine du projet
cat <<EOL > .gitignore
**/node_modules/
**/dist/
**/.env
EOL

# Création des sous-dossiers du projet
for folder in $STRUCTURE; do
  mkdir -p "$folder"
done

progress_bar "Création de la structure"

# Si le dossier backend est présent
if echo "$STRUCTURE" | grep -q "backend"; then
  BACKEND_DEPS=$(jq -r '.backend.dependencies[]' "$CONFIG_FILE")
  BACKEND_DEPS_DEV=$(jq -r '.backend.devDependencies[]' "$CONFIG_FILE")
  PORT=$(jq -r '.backend.port' "$CONFIG_FILE")

  cd backend || exit
  npm init -y > /dev/null

  # Ajouter le type module dans package.json
  jq '. + {type: "module"}' package.json > tmp.json && mv tmp.json package.json

  npm install $BACKEND_DEPS > /dev/null

  progress_bar "Installation des dépendances"

  # Si Typescript est utilisé
  if jq -e '.backend.useTypescript' "$CONFIG_FILE" >/dev/null; then
    npm install -D typescript ts-node > /dev/null
    npx tsc --init > /dev/null

    # Modifier tsconfig.json
    sed -i 's/"target": "es2016"/"target": "ESNext"/' tsconfig.json
    sed -i 's/"module": "commonjs"/"module": "NodeNext"/' tsconfig.json
    sed -i 's@// *"outDir": *"./",@"outDir": "./dist",@' tsconfig.json

    # Script dev
    jq '.scripts = { dev: "tsc && concurrently \"tsc -w\" \"node --watch ./dist/server.js\"" }' package.json > tmp.json && mv tmp.json package.json
  fi

  npm install -D $BACKEND_DEPS_DEV > /dev/null
  progress_bar "Installation des devdépendances"

  # Création de la structure backend
  BACKEND_UNDER_FOLDER=$(jq -r '.backend.structure[]' "$CONFIG_FILE")

  for folder in $BACKEND_UNDER_FOLDER; do
    mkdir -p "$folder"
    cd "$folder"
    touch "$folder.ts"
    cd ..
  done

  progress_bar "Mise en place de la structure dossier"

  # Si route existe, créer route.ts
  if jq -r '.backend.structure[]' "$CONFIG_FILE" | grep -q "route"; then
    cat <<EOL > route/route.ts
import { Router } from "express";
import { client } from "../data/data.js";

const router = Router();

router.get("/user", async (req, res)=> { 
  const result = await client.query("SELECT * FROM users");
  res.json(result.rows);
})

export { router };
EOL
  fi #if Route dans backend

  # Création du fichier server.ts
  ENTRY_FILE=$(jq -r '.backend.entryPoint' "$CONFIG_FILE")

  cat <<EOL > "$ENTRY_FILE"
import express from "express";
import cookieParser from "cookie-parser";
import cors from "cors"
import { router } from "./route/route.js";

const app = express();
const PORT = $PORT;

const corsOptions = {			
		origin: "http://localhost:5173",
		methods: ['GET', 'POST', 'PATCH', 'DELETE'],
		allowedHeaders: ['Content-Type', 'Authorization'],
		credentials: true,
	}

app.use(cors(corsOptions));
app.use(cookieParser());
app.use(express.json());
app.use(router);

app.listen(PORT, () => {
  console.log(\`Server online http://localhost:\${PORT}\`);
});
EOL
 
  # Si data est dans la structure backend
  if jq -r '.backend.structure[]' "$CONFIG_FILE" | grep -q "data"; then
    cat <<EOL > data/data.ts
import pg from "pg";
const { Client } = pg;

const client = new Client("$(jq -r '.database.PG_URL' "$CONFIG_FILE")");

async function connectDB() {
  try {
    await client.connect();
    console.log("Connecté à la base de données");
  } catch (err) {
    console.error("Erreur de connexion à la base de données:", err);
  }
}

connectDB();

export { client };
EOL

    cat <<EOL > data/create.sql
BEGIN;

DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id_user INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    firstname TEXT NOT NULL,
    lastname TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE CHECK (
        email ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    ),
    password TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMIT;
EOL

    cat <<EOL > data/seed.sql
BEGIN;

INSERT INTO users (firstname, lastname, email, password)
VALUES 
('Alice', 'Martin', 'alice.martin@example.com', 'password123');

COMMIT;
EOL
  fi #if Data dans backend  
fi #if Backend

# Si le dossier frontend est présent
if echo "$STRUCTURE" | grep -q "frontend"; then
  cd ..
  cd frontend
   
  npm create vite@latest . -- --template $(jq -r '.frontend.framework' "$CONFIG_FILE")-ts > /dev/null
 
  cp "$BASEDIR/boilr/src/boilr.png" "$BASEDIR/$PROJECT_NAME/frontend/src/assets/"
  cp "$BASEDIR/boilr/src/boilr_fav.png" "$BASEDIR/$PROJECT_NAME/frontend/src/assets/"


  (
    seconds=0
    while true; do
      printf "\r⏳ Installation en cours... %ds écoulées" "$seconds"
      sleep 1
      ((seconds++))
    done
  ) &
  TIMER_PID=$!

  npm install tailwindcss @tailwindcss/vite --silent

  kill $TIMER_PID >/dev/null 2>&1
  wait $TIMER_PID 2>/dev/null

  # Fin propre
  echo -e "\n✅ Installation du frontend terminée !"  
  
  LOG_FILE="vite.log"

  # Nettoyer le fichier log avant usage
  : > "$LOG_FILE"

  #Nommage de l'onglet de la page & favicon
  sed -i 's|<title>.*</title>|<title>Boil'"'"'r</title>|' index.html
  sed -i 's|<link rel="icon[^>]*>|<link rel="icon" type="image/png" href="./src/assets/boilr_fav.png" />|' index.html



  # Changement de la page App
  cd src
  rm -rf App.tsx App.css ../vite.config.ts index.css

  cat <<EOL > ../vite.config.ts
import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
  ],
})
EOL

  cat <<EOL > App.css
@import "tailwindcss";
EOL

  cat <<EOL > index.css
@import "tailwindcss";
EOL


  cat <<EOL > App.tsx
import './App.css'
import { useState } from 'react'
import boilrLogo from './assets/boilr.png'

export default function App() {
const [data, setData] = useState(null)

const fetchUser = async () => {
    try {
      const response = await fetch("http://localhost:3000/user")
      const dataFetch = await response.json()
      setData(dataFetch)
    } catch (error) {
      console.error("Erreur lors de la récupération :", error)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100 px-4">
      <div className="bg-white shadow-xl rounded-2xl p-8 max-w-xl w-full text-center space-y-6">
        <h1 className="text-4xl font-bold text-red-500 flex items-center gap-2">
          <img src={boilrLogo} alt="Logo Boil'r" className="w-3xs" />
          BOIL'R
        </h1>
        <p className="text-gray-700 text-lg">
          L'outil ultime pour les <span className="font-semibold text-red-400">multi-projects lovers</span> 🚀
        </p>

        <button
          onClick={fetchUser}
          className="bg-red-500 hover:bg-red-600 text-white font-semibold py-2 px-6 rounded-lg transition duration-300 shadow"
        >
          Récupérer l'utilisateur
        </button>

        {data && (
		  <>
			<div className="text-left bg-gray-100 rounded-lg p-4 max-h-64 overflow-auto">
			  <pre className="text-sm text-gray-800 whitespace-pre-wrap break-words">
				{JSON.stringify(data, null, 2)}
			  </pre>
			</div>
			<button
			  onClick={() => setData(null)}
			  className="bg-red-500 hover:bg-red-600 text-white font-semibold py-2 px-6 rounded-lg transition duration-300 shadow"
			>
			  Clear
			</button>
		  </>
		)}       
      </div>
    </div>
  )
}

EOL

  # Si Docker est activé
  if jq -e '.backend.useDocker' "$CONFIG_FILE" >/dev/null; then
  cd ..

    cat <<EOL > Dockerfile
FROM node:22-alpine
RUN mkdir -p /frontend
WORKDIR /frontend
COPY package*.json .
RUN npm i
COPY . .
EXPOSE 5173
CMD ["npm", "run", "dev"]
EOL

  jq '.scripts.dev = "vite --host"' package.json > tmp.json && mv tmp.json package.json

  cd .. 
  cd backend
    cat <<EOL > Dockerfile
FROM node:22-alpine
RUN mkdir -p /backend
WORKDIR /backend
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD [ "npm", "run", "dev" ]
EOL

  # Création du fichier docker-compose
  DATABASE_NAME=$(jq -r '.database.name' "$CONFIG_FILE")

    cat <<EOL > ../docker-compose.yml
services:

  backend:
    container_name: backend
    build:
      context: ./backend
      dockerfile: Dockerfile
    volumes:
      - ./backend:/backend
      - /backend/node_modules
    ports:
      - "3000:3000"
    environment:
      - PG_URL=$(jq -r '.database.PG_URL' "$CONFIG_FILE")
    depends_on:
      - $DATABASE_NAME

  $DATABASE_NAME:
    image: postgres:17.2-alpine
    container_name: $DATABASE_NAME
    environment:
      - POSTGRES_USER=$(jq -r '.database.POSTGRES_USER' "$CONFIG_FILE")
      - POSTGRES_PASSWORD=$(jq -r '.database.POSTGRES_PASSWORD' "$CONFIG_FILE")
      - POSTGRES_DB=$(jq -r '.database.POSTGRES_DB' "$CONFIG_FILE")
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./backend/data/:/docker-entrypoint-initdb.d
    
  frontend:
    container_name: frontend
    build:
      context: ./frontend
      dockerfile: Dockerfile
    volumes:
      - ./frontend:/frontend
      - /frontend/node_modules
    ports:
      - "5173:5173"
    depends_on:
      - backend

volumes:
  pgdata:

EOL

  fi #if Docker

  # Lancer Vite en arrière-plan, logs capturés
  if jq -e '.frontend.useDocker' "$CONFIG_FILE" >/dev/null; then
    #je ne fais rien à faire avec le compose final
    #npm run dev > "$LOG_FILE" 2>&1 &
    echo " "
  else
    npm run dev > "$LOG_FILE" 2>&1 &

    VITE_PID=$!

    # Attente active que le port s'affiche
    until grep -qE "http://localhost:[0-9]+" "$LOG_FILE"; do
      sleep 0.2
    done

    # Extraction de l'URL des log
    FRONTEND_URL=$(grep -oE "http://localhost:[0-9]+" "$LOG_FILE" | head -n1)
    
    # Suppression du fichier provisoir de log
    rm "$LOG_FILE"
  fi

fi #if Frontend

# Lancer le serveur
if jq -e '.backend.useDocker' "$CONFIG_FILE" > /dev/null; then
  cd ..
  progress_bar_2 "docker compose up -d &> /dev/null" "Démarrage des conteneurs"
else 
  npm run dev > /dev/null &
  sleep 2    
fi
  
progress_bar "Application en cours de lancement"

echo " " 

# echo "🌐 Backend lancé sur : http://localhost:$PORT"
# echo "🌐 Frontend lancé sur : $FRONTEND_URL"

cat << "EOF"

────────────────────────────────────────────                                                
              ___        
              |__  | |\ | 
              |    | | \| 

────────────────────────────────────────────
            
EOF