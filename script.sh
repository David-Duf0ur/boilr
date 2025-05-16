#!/bin/bash

clear

cat <<'EOF'

__/\\\\\\\\\\\\\________________________/\\\\\\_____/\\\\_______________        
 _\/\\\/////////\\\_____________________\////\\\____\///\\_______________       
  _\/\\\_______\/\\\________________/\\\____\/\\\_____/\\/________________      
   _\/\\\\\\\\\\\\\\______/\\\\\____\///_____\/\\\____\//_____/\\/\\\\\\\__     
    _\/\\\/////////\\\___/\\\///\\\___/\\\____\/\\\___________\/\\\/////\\\_    
     _\/\\\_______\/\\\__/\\\__\//\\\_\/\\\____\/\\\___________\/\\\___\///__   
      _\/\\\_______\/\\\_\//\\\__/\\\__\/\\\____\/\\\___________\/\\\_________  
       _\/\\\\\\\\\\\\\/___\///\\\\\/___\/\\\__/\\\\\\\\\________\/\\\_________ 
        _\/////////////_______\/////_____\///__\/////////_________\///__________ 

*********************************************************************************
 _           ___  _____   _____ _  _ ___ ___ ___  ___         ___ __ ___ ___ 
| |__ _  _  |   \| __\ \ / /_ _| \| / __|_ _|   \| __|  ___  |_  )  \_  ) __|
| '_ \ || | | |) | _| \ V / | || .` \__ \| || |) | _|  |___|  / / () / /|__ \
|_.__/\_, | |___/|___| \_/ |___|_|\_|___/___|___/|___|       /___\__/___|___/
      |__/                                                                   

*********************************************************************************

EOF                                 

progress_bar() {
  local message=$1
  local i=0
  local max=30
  echo -n "$message : ["
  while [ $i -le $max ]; do
    echo -n "#"
    sleep 0.05
    ((i++))
  done
  echo "] ✅"
}
                                                                 

CONFIG_FILE="config.json"

# Vérification si le fichier de config existe bien
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Fichier de configuration $CONFIG_FILE introuvable."
  exit 1
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
  BACKEND_DEPS=$(jq -r '.backend.dependencies[]' "$BASEDIR/Boilr/$CONFIG_FILE")
  BACKEND_DEPS_DEV=$(jq -r '.backend.devDependencies[]' "$BASEDIR/Boilr/$CONFIG_FILE")

  cd backend || exit
  npm init -y > /dev/null

  # Ajouter le type module dans package.json
  jq '. + {type: "module"}' package.json > tmp.json && mv tmp.json package.json

  npm install $BACKEND_DEPS > /dev/null

  progress_bar "Installation des dépendances"

  # Si Typescript est utilisé
  if jq -e '.backend.useTypescript' "$BASEDIR/Boilr/$CONFIG_FILE" >/dev/null; then
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
  progress_bar "Installation des dépendances de développement"

  # Création de la structure backend
  BACKEND_UNDER_FOLDER=$(jq -r '.backend.structure[]' "$BASEDIR/Boilr/$CONFIG_FILE")

  for folder in $BACKEND_UNDER_FOLDER; do
    mkdir -p "$folder"
    cd "$folder"
    touch "$folder.ts"
    cd ..
  done

  progress_bar "Mise en place de la structure dossier"

  # Si route existe, créer route.ts
  if jq -r '.backend.structure[]' "$BASEDIR/Boilr/$CONFIG_FILE" | grep -q "route"; then
    cat <<EOL > route/route.ts
import { Router } from "express";
import { client } from "../data/data.js";

const router = Router();

router.get("/", async (req, res)=> { 
  const result = await client.query("SELECT * FROM users");
  res.json(result.rows);
})

export { router };
EOL
  fi

  # Création du fichier server.ts
  ENTRY_FILE=$(jq -r '.backend.entryPoint' "$BASEDIR/Boilr/$CONFIG_FILE")

  cat <<EOL > "$ENTRY_FILE"
import express from "express";
import cookieParser from "cookie-parser";
import { router } from "./route/route.js";

const app = express();
const PORT = 3000;

app.use(cookieParser());
app.use(express.json());
app.use(router);

app.listen(PORT, () => {
  console.log(\`Server online http://localhost:\${PORT}\`);
});
EOL
 
  # Si data est dans la structure backend
  if jq -r '.backend.structure[]' "$BASEDIR/Boilr/$CONFIG_FILE" | grep -q "data"; then
    cat <<EOL > data/data.ts
import pg from "pg";
const { Client } = pg;

const client = new Client("$(jq -r '.database.PG_URL' "$BASEDIR/Boilr/$CONFIG_FILE")");

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
  fi

  # Si Docker est activé
  if jq -e '.backend.useDocker' "$BASEDIR/Boilr/$CONFIG_FILE" >/dev/null; then
  
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

  # Création du fichier server.ts
  DATABASE_NAME=$(jq -r '.database.name' "$BASEDIR/Boilr/$CONFIG_FILE")

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
      - PG_URL=$(jq -r '.database.PG_URL' "$BASEDIR/Boilr/$CONFIG_FILE")
    depends_on:
      - $DATABASE_NAME

  $DATABASE_NAME:
    image: postgres:17.2-alpine
    container_name: $DATABASE_NAME
    environment:
      - POSTGRES_USER=$(jq -r '.database.POSTGRES_USER' "$BASEDIR/Boilr/$CONFIG_FILE")
      - POSTGRES_PASSWORD=$(jq -r '.database.POSTGRES_PASSWORD' "$BASEDIR/Boilr/$CONFIG_FILE")
      - POSTGRES_DB=$(jq -r '.database.POSTGRES_DB' "$BASEDIR/Boilr/$CONFIG_FILE")
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./backend/data/:/docker-entrypoint-initdb.d

volumes:
  pgdata:

EOL

  fi

# Si le dossier frontend est présent
if echo "$STRUCTURE" | grep -q "frontend"; then
  cd ..
  cd frontend

  #npm create vite@latest . -- --template $(jq -r '.frontend.framework' "$BASEDIR/Boilr/$CONFIG_FILE")-ts > /dev/null
  pnpm create vite . --template $(jq -r '.frontend.framework' "$BASEDIR/Boilr/$CONFIG_FILE")-ts > /dev/null
  
  pnpm install > /dev/null || { echo "Échec de npm install"; exit 1; }
  
  pnpm run dev > /dev/null &
  sleep 2

fi

progress_bar "Installation du frontend"

  # Lancer le serveur
  cd ..
  sudo docker compose up -d > /dev/null

  progress_bar "Application en cours de lancement"
 
fi

cat <<'EOF'

 (      (         )  
 )\ )   )\ )   ( /(  
(()/(  (()/(   )\()) 
 /(_))  /(_)) ((_)\  
(_))_| (_))    _((_) 
| |_   |_ _|  | \| | 
| __|   | |   | .` | 
|_|    |___|  |_|\_| 

                        
EOF
