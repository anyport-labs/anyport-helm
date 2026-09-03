#!/usr/bin/env bash
# Generates the source-build verification corpus: one minimal repository per stack Anyport
# claims to build. See docs/buildpacks/PHASE-5-verification-and-flip.md.
#
# Generated rather than a list of public repositories, deliberately. A third-party repo drifts,
# and the cases that matter here are defined by what a repo *lacks* — 02 has no start script and
# no Dockerfile, which is the exact shape that crash-looped a real app and got buildpacks
# switched off. Writing them keeps that guaranteed instead of hoping upstream never adds one.
#
# Usage: scripts/build-corpus.sh [target-dir]   (default: ./build-corpus)
set -euo pipefail

target="${1:-build-corpus}"
mkdir -p "$target"

# --- 01-node-express ---
mkdir -p "$target/01-node-express"
cat > "$target/01-node-express/package.json" <<'CORPUS_EOF'
{
  "name": "node-express",
  "version": "1.0.0",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.19.2" }
}
CORPUS_EOF
mkdir -p "$target/01-node-express"
cat > "$target/01-node-express/server.js" <<'CORPUS_EOF'
const express = require("express");
const app = express();
app.get("/", (_, res) => res.send("node-express ok"));
app.listen(process.env.PORT || 3000);
CORPUS_EOF

# --- 02-vite-spa ---
mkdir -p "$target/02-vite-spa"
cat > "$target/02-vite-spa/index.html" <<'CORPUS_EOF'
<!doctype html><html><head><title>vite-spa</title></head>
<body><div id="app">vite-spa ok</div><script type="module" src="/src/main.js"></script></body></html>
CORPUS_EOF
mkdir -p "$target/02-vite-spa"
cat > "$target/02-vite-spa/package.json" <<'CORPUS_EOF'
{
  "name": "vite-spa",
  "version": "1.0.0",
  "scripts": { "build": "vite build", "dev": "vite" },
  "devDependencies": { "vite": "^5.4.0" }
}
CORPUS_EOF
mkdir -p "$target/02-vite-spa/src"
cat > "$target/02-vite-spa/src/main.js" <<'CORPUS_EOF'
document.getElementById("app").textContent = "vite-spa ok";
CORPUS_EOF
mkdir -p "$target/02-vite-spa"
cat > "$target/02-vite-spa/vite.config.js" <<'CORPUS_EOF'
export default { build: { outDir: "dist" } };
CORPUS_EOF

# --- 03-nextjs-ssr ---
mkdir -p "$target/03-nextjs-ssr"
cat > "$target/03-nextjs-ssr/package.json" <<'CORPUS_EOF'
{
  "name": "nextjs-ssr",
  "version": "1.0.0",
  "scripts": { "build": "next build", "start": "next start" },
  "dependencies": { "next": "^14.2.5", "react": "^18.3.1", "react-dom": "^18.3.1" }
}
CORPUS_EOF
mkdir -p "$target/03-nextjs-ssr/pages"
cat > "$target/03-nextjs-ssr/pages/index.js" <<'CORPUS_EOF'
export default function Home() { return <p>nextjs-ssr ok</p>; }
CORPUS_EOF

# --- 04-astro-static ---
mkdir -p "$target/04-astro-static"
cat > "$target/04-astro-static/package.json" <<'CORPUS_EOF'
{
  "name": "astro-static",
  "version": "1.0.0",
  "scripts": { "build": "astro build" },
  "dependencies": { "astro": "^4.15.0" }
}
CORPUS_EOF
mkdir -p "$target/04-astro-static/src/pages"
cat > "$target/04-astro-static/src/pages/index.astro" <<'CORPUS_EOF'
<html><body><p>astro-static ok</p></body></html>
CORPUS_EOF

# --- 05-python-fastapi ---
mkdir -p "$target/05-python-fastapi"
cat > "$target/05-python-fastapi/Procfile" <<'CORPUS_EOF'
web: uvicorn main:app --host 0.0.0.0 --port $PORT
CORPUS_EOF
mkdir -p "$target/05-python-fastapi"
cat > "$target/05-python-fastapi/main.py" <<'CORPUS_EOF'
from fastapi import FastAPI
app = FastAPI()

@app.get("/")
def root():
    return {"status": "python-fastapi ok"}
CORPUS_EOF
mkdir -p "$target/05-python-fastapi"
cat > "$target/05-python-fastapi/requirements.txt" <<'CORPUS_EOF'
fastapi==0.115.0
uvicorn==0.30.6
CORPUS_EOF

# --- 06-python-pyproject ---
mkdir -p "$target/06-python-pyproject"
cat > "$target/06-python-pyproject/Procfile" <<'CORPUS_EOF'
web: python app.py
CORPUS_EOF
mkdir -p "$target/06-python-pyproject"
cat > "$target/06-python-pyproject/app.py" <<'CORPUS_EOF'
import os
from flask import Flask
app = Flask(__name__)

@app.get("/")
def root():
    return "python-pyproject ok"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
CORPUS_EOF
mkdir -p "$target/06-python-pyproject"
cat > "$target/06-python-pyproject/pyproject.toml" <<'CORPUS_EOF'
[project]
name = "python-pyproject"
version = "1.0.0"
requires-python = ">=3.11"
dependencies = ["flask==3.0.3"]
CORPUS_EOF

# --- 07-go-module ---
mkdir -p "$target/07-go-module"
cat > "$target/07-go-module/go.mod" <<'CORPUS_EOF'
module corpus/goapp

go 1.23
CORPUS_EOF
mkdir -p "$target/07-go-module"
cat > "$target/07-go-module/main.go" <<'CORPUS_EOF'
package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	http.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, "go-module ok")
	})
	http.ListenAndServe(":"+port, nil)
}
CORPUS_EOF

# --- 08-java-maven ---
mkdir -p "$target/08-java-maven"
cat > "$target/08-java-maven/pom.xml" <<'CORPUS_EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>corpus</groupId>
  <artifactId>javaapp</artifactId>
  <version>1.0.0</version>
  <properties>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
  </properties>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.3</version>
  </parent>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
  </dependencies>
  <build><plugins><plugin>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-maven-plugin</artifactId>
  </plugin></plugins></build>
</project>
CORPUS_EOF
mkdir -p "$target/08-java-maven/src/main/java/corpus"
cat > "$target/08-java-maven/src/main/java/corpus/App.java" <<'CORPUS_EOF'
package corpus;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class App {
  public static void main(String[] args) { SpringApplication.run(App.class, args); }

  @GetMapping("/")
  public String root() { return "java-maven ok"; }
}
CORPUS_EOF

# --- 09-static-html ---
mkdir -p "$target/09-static-html"
cat > "$target/09-static-html/index.html" <<'CORPUS_EOF'
<!doctype html><html><body><p>static-html ok</p></body></html>
CORPUS_EOF

# --- 10-monorepo ---
mkdir -p "$target/10-monorepo"
cat > "$target/10-monorepo/README.md" <<'CORPUS_EOF'
The application is in apps/web. Set the build path to apps/web.
CORPUS_EOF
mkdir -p "$target/10-monorepo/apps/web"
cat > "$target/10-monorepo/apps/web/package.json" <<'CORPUS_EOF'
{
  "name": "node-express",
  "version": "1.0.0",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.19.2" }
}
CORPUS_EOF
mkdir -p "$target/10-monorepo/apps/web"
cat > "$target/10-monorepo/apps/web/server.js" <<'CORPUS_EOF'
const express = require("express");
const app = express();
app.get("/", (_, res) => res.send("node-express ok"));
app.listen(process.env.PORT || 3000);
CORPUS_EOF

# --- 11-with-dockerfile ---
mkdir -p "$target/11-with-dockerfile"
cat > "$target/11-with-dockerfile/Dockerfile" <<'CORPUS_EOF'
FROM node:22-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY . .
ENV PORT=8080
EXPOSE 8080
CMD ["node", "server.js"]
CORPUS_EOF
mkdir -p "$target/11-with-dockerfile"
cat > "$target/11-with-dockerfile/package.json" <<'CORPUS_EOF'
{
  "name": "node-express",
  "version": "1.0.0",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.19.2" }
}
CORPUS_EOF
mkdir -p "$target/11-with-dockerfile"
cat > "$target/11-with-dockerfile/server.js" <<'CORPUS_EOF'
const express = require("express");
const app = express();
app.get("/", (_, res) => res.send("node-express ok"));
app.listen(process.env.PORT || 3000);
CORPUS_EOF

# --- 12-unclassifiable ---
mkdir -p "$target/12-unclassifiable"
cat > "$target/12-unclassifiable/data.csv" <<'CORPUS_EOF'
a,b
1,2
CORPUS_EOF
mkdir -p "$target/12-unclassifiable"
cat > "$target/12-unclassifiable/notes.txt" <<'CORPUS_EOF'
This directory is not an application. Railpack must say so, legibly.
CORPUS_EOF

for d in "$target"/*/; do
  name=$(basename "$d")
  if [ ! -d "$d/.git" ]; then
    git -C "$d" init -q
    git -C "$d" add -A
    git -C "$d" -c user.email=corpus@anyport.dev -c user.name=corpus commit -qm "corpus: $name"
  fi
done

echo "corpus ready in $target:"
ls -1 "$target"
