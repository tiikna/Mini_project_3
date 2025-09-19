# 🚀 Application Deployment Assignment

## 📌 Problem Statement
Deploy the given React application to a **production-ready state**.

### Application:
- Clone the repo and deploy the app on port **80 (HTTP)**  
- Repo URL: [https://github.com/sriram-R-krishnan/devops-build](https://github.com/sriram-R-krishnan/devops-build)

---

## 🛠️ Prerequisites
Before starting, make sure you have:

- **GitHub account** (for version control)  
- **Docker & Docker Compose** installed (for containerization)  
- **Docker Hub account** (to store images)  
- **Jenkins server** installed (local or EC2)  
- **AWS account** (for EC2 deployment)  
- **Basic Linux knowledge**  

---

## 📂 Project Structure
These are the required files for the project:

```
.
├── Dockerfile
├── docker-compose.yml
├── build.sh
├── deploy.sh
├── Jenkinsfile
└── devops-build/
    └── nginx.conf
```

---

## 📜 Files and Code

### 1. Dockerfile
```dockerfile
# ---------- Stage 1: Build React app ----------
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run build

# ---------- Stage 2: Serve with Nginx ----------
FROM nginx:alpine
COPY devops-build/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget -qO- http://127.0.0.1/ || exit 1
CMD ["nginx","-g","daemon off;"]
```

---

### 2. devops-build/nginx.conf
```nginx
server {
  listen 80;
  server_name _;

  root /usr/share/nginx/html;
  index index.html;

  location / {
    try_files $uri /index.html;
  }

  location ~* \.(js|css|png|jpg|jpeg|gif|svg|ico)$ {
    add_header Cache-Control "public, max-age=31536000, immutable";
    try_files $uri =404;
  }
}
```

---

### 3. docker-compose.yml
```yaml
version: "3.9"
services:
  web:
    build: .
    image: ${DOCKERHUB_USER}/${APP_NAME}:${IMAGE_TAG:-latest}
    ports:
      - "80:80"
    restart: unless-stopped
```

---

### 4. build.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:-dev}"
TAG="${2:-$(date +%Y%m%d-%H%M%S)}"

: "${DOCKERHUB_USER:?set DOCKERHUB_USER}"
: "${APP_NAME:=devops-build}"

IMAGE="${DOCKERHUB_USER}/${APP_NAME}:${TAG}"

echo "[Build] Building image ${IMAGE} (branch=${BRANCH})"
docker build -t "${IMAGE}" .

if [[ -n "${DOCKERHUB_PASS:-}" ]]; then
  echo "${DOCKERHUB_PASS}" | docker login -u "${DOCKERHUB_USER}" --password-stdin
else
  docker login -u "${DOCKERHUB_USER}"
fi

echo "[Push] Pushing ${IMAGE}"
docker push "${IMAGE}"

CHANNEL_TAG="${BRANCH}-latest"
docker tag "${IMAGE}" "${DOCKERHUB_USER}/${APP_NAME}:${CHANNEL_TAG}"
docker push "${DOCKERHUB_USER}/${APP_NAME}:${CHANNEL_TAG}"

echo "[Done] Pushed ${IMAGE} and ${CHANNEL_TAG}"
```

---

### 5. deploy.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

HOST="${1:?host/ip required}"
BRANCH="${2:-dev}"
TAG="${3:-${BRANCH}-latest}"

: "${DOCKERHUB_USER:?set DOCKERHUB_USER}"
: "${APP_NAME:=devops-build}"

IMAGE="${DOCKERHUB_USER}/${APP_NAME}:${TAG}"

cat > /tmp/deploy_remote.sh <<'EOS'
set -euo pipefail
docker pull "${IMAGE}"
docker rm -f "${APP_NAME}" 2>/dev/null || true
docker run -d --name "${APP_NAME}" -p 80:80 --restart unless-stopped "${IMAGE}"
docker ps --filter "name=${APP_NAME}"
EOS

scp /tmp/deploy_remote.sh "ec2-user@${HOST}:/tmp/deploy_remote.sh"
ssh "ec2-user@${HOST}" "APP_NAME='${APP_NAME}' IMAGE='${IMAGE}' bash /tmp/deploy_remote.sh"
echo "[Deploy] Completed to ${HOST} with ${IMAGE}"
```

---

### 6. Jenkinsfile
```groovy
pipeline {
  agent any
  environment {
    APP_NAME = 'devops-build'
    DOCKERHUB_USER = credentials('dockerhub-username')
    DOCKERHUB_PASS = credentials('dockerhub-password')
  }
  triggers { githubPush() }
  options { timestamps() }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('Set Channel & Tag') {
      steps {
        script {
          BRANCH = env.BRANCH_NAME
          CHANNEL = (BRANCH == 'master' || BRANCH == 'main') ? 'prod' : 'dev'
          IMAGE_TAG = "${env.BUILD_NUMBER}"
          env.CHANNEL = CHANNEL
          env.IMAGE_TAG = IMAGE_TAG
        }
      }
    }
    stage('Build & Push') {
      steps {
        sh '''
          export DOCKERHUB_USER=${DOCKERHUB_USER}
          export DOCKERHUB_PASS=${DOCKERHUB_PASS}
          export APP_NAME=${APP_NAME}
          ./build.sh "${CHANNEL}" "${IMAGE_TAG}"
        '''
      }
    }
    stage('Deploy (EC2)') {
      when { anyOf { branch 'dev'; branch 'master'; branch 'main' } }
      environment {
        DEPLOY_HOST = credentials('ec2-host-ip')
      }
      steps {
        sh '''
          export DOCKERHUB_USER=${DOCKERHUB_USER}
          export APP_NAME=${APP_NAME}
          ./deploy.sh "${DEPLOY_HOST}" "${CHANNEL}" "${IMAGE_TAG}"
        '''
      }
    }
  }
}
```

---

## 🔑 Execution Steps

### Step 1: Clone the Repo
```bash
git clone https://github.com/sriram-R-krishnan/devops-build
cd devops-build
```

### Step 2: Build & Run Locally
```bash
docker build -t react-app:dev .
docker run -d -p 80:80 react-app:dev
```

### Step 3: Push to GitHub
```bash
git checkout -b dev
git add .
git commit -m "added deployment files"
git push origin dev
```

# 🔹 Step 4: Docker Hub Repositories

### Why?
We need **2 repositories** in Docker Hub:
- `devops-build-dev` → Public (for development images)
- `devops-build-prod` → Private (for production images)

### Steps:
1. Go to [https://hub.docker.com/](https://hub.docker.com/) and log in.
2. Click **Repositories → Create Repository**.
3. For Dev repo:
   - Name: `devops-build-dev`
   - Visibility: Public
   - Description: "Dev images for CI/CD pipeline"
   - Click **Create**
4. For Prod repo:
   - Name: `devops-build-prod`
   - Visibility: Private
   - Description: "Production images for CI/CD pipeline"
   - Click **Create**

👉 Now, images from **dev branch** will go to the dev repo, and images from **main/master branch** will go to the prod repo.

---

# 🔹 Step 5: Jenkins Setup (CI/CD)

### Why?
Jenkins automates build → push → deploy whenever we push code to GitHub.

### Part A: Install Plugins
1. Open Jenkins → **Manage Jenkins → Plugins**.
2. Install these plugins:
   - Docker Pipeline
   - GitHub Integration Plugin
   - Pipeline

### Part B: Add Credentials
1. Go to **Manage Jenkins → Credentials → Global Credentials**.
2. Add:
   - ID: `dockerhub-username` → Docker Hub username
   - ID: `dockerhub-password` → Docker Hub password/token
   - ID: `ec2-host-ip` → Secret text containing EC2 Public IP

### Part C: Connect GitHub Repo
1. Create a new Jenkins item → **Pipeline project**.
2. Under Pipeline definition → choose *Pipeline script from SCM*.
3. SCM: Git → enter your GitHub repo URL.
4. Branches: `*/dev` and `*/master`.

### Part D: GitHub Webhook
1. In GitHub repo → **Settings → Webhooks → Add webhook**.
2. Payload URL:
   ```
   http://<YOUR_JENKINS_PUBLIC_IP>:8080/github-webhook/
   ```
3. Content type: `application/json`
4. Trigger: Push events
5. Save ✅

👉 Now Jenkins will auto-trigger on each `git push`.

---

# 🔹 Step 6: AWS EC2 Deployment

### Why?
The React app must run live on a public server.

### Part A: Launch EC2
1. In AWS console → Launch instance.
2. Choose Ubuntu 22.04 or Amazon Linux 2.
3. Instance type: `t2.micro`
4. Security Group rules:
   - HTTP (80) → 0.0.0.0/0
   - SSH (22) → My IP only

### Part B: Install Docker
Connect via SSH:
```bash
ssh -i mykey.pem ubuntu@<EC2_PUBLIC_IP>
```
Install Docker:
```bash
sudo apt update
sudo apt install -y docker.io
sudo usermod -aG docker ubuntu
```
Logout & login again. Verify with:
```bash
docker ps
```

### Part C: Deploy the App
From Jenkins pipeline, `deploy.sh` will run automatically.  
Manually, you can run:
```bash
./deploy.sh <EC2_PUBLIC_IP> dev
```
Then open browser:
```
http://<EC2_PUBLIC_IP>
```
✅ Your app is live!


### Step 7: Monitoring (Optional but Recommended)
- Use **Uptime Kuma** or **Prometheus+Grafana**  
- Example (Uptime Kuma):
  ```bash
  docker run -d --restart=always -p 3001:3001 louislam/uptime-kuma
  ```

---

## 📤 Submission
- GitHub repo URL  
- Deployed site URL  
- Docker Hub repos with tags  
- Jenkins screenshots (login, config, build logs)  
- AWS console (EC2 + SG) screenshots  
- Monitoring screenshots  

---

## ✅ Checklist
- [ ] Repo cloned & dockerized  
- [ ] Images built & pushed (dev + prod)  
- [ ] Jenkins pipeline running  
- [ ] EC2 deployed  
- [ ] Monitoring added  
- [ ] Screenshots collected  

---

🎉 Congrats! You’ve successfully built a **CI/CD pipeline with Docker, Jenkins, AWS & Monitoring**.



---
